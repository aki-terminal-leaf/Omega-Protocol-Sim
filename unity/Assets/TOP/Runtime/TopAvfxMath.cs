// SPDX-License-Identifier: MIT
// Unity 6 port of the AVFX curve/random math helpers (avfx_animation.gd / avfx_player.gd).
// Bounded source-graph preview math. Not game-equivalence certification.
using System;
using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Top.UnityReplay
{
    public static class TopAvfxMath
    {
        static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
        static readonly string[] AxisNames = { "X", "Y", "Z" };
        // Per link index: source axis index for output X, Y, Z.
        static readonly int[][] AxisLinks =
        {
            new[] { 0, 1, 2 }, new[] { 0, 0, 0 }, new[] { 0, 0, 2 }, new[] { 0, 1, 0 }, new[] { 1, 1, 1 },
            new[] { 1, 1, 2 }, new[] { 0, 1, 1 }, new[] { 2, 2, 2 }, new[] { 2, 1, 2 }, new[] { 0, 2, 2 }
        };
        static readonly ConditionalWeakTable<JToken, object> ValidCurves = new ConditionalWeakTable<JToken, object>();

        // ---- small helpers (JS/GDScript semantics where it matters) ----
        static bool Nul(JToken t) => t == null || t.Type == JTokenType.Null;

        static bool IsEmpty(JToken t)
        {
            if (t == null) return true;
            if (t is JObject o) return !o.HasValues;
            if (t is JArray a) return a.Count == 0;
            return !(t.Type == JTokenType.String && ((string)t).Length > 0);
        }

        static JToken Dget(JToken o, string k, JToken d) => o is JObject jo && jo.TryGetValue(k, out JToken v) ? v : d;

        // JS Number(x); null reference means undefined (NaN).
        static double ToNumber(JToken t)
        {
            if (t == null) return double.NaN;
            switch (t.Type)
            {
                case JTokenType.Integer:
                case JTokenType.Float: return (double)t;
                case JTokenType.Boolean: return (bool)t ? 1 : 0;
                case JTokenType.Null: return 0;
                case JTokenType.String:
                    string s = ((string)t).Trim();
                    if (s.Length == 0) return 0;
                    return double.TryParse(s, NumberStyles.Float, Inv, out double r) ? r : double.NaN;
                case JTokenType.Array:
                    var a = (JArray)t;
                    return a.Count == 0 ? 0 : a.Count == 1 ? ToNumber(a[0]) : double.NaN;
                default: return double.NaN;
            }
        }

        static bool Truthy(JToken t)
        {
            if (Nul(t)) return false;
            switch (t.Type)
            {
                case JTokenType.Boolean: return (bool)t;
                case JTokenType.Integer:
                case JTokenType.Float: double n = (double)t; return n != 0 && !double.IsNaN(n);
                case JTokenType.String: return ((string)t).Length > 0;
                default: return true;
            }
        }

        static double Num(JToken v, double d = 0)
        {
            if (Nul(v)) return d;
            double n = ToNumber(v);
            return double.IsNaN(n) ? d : n;
        }

        static double Int(JToken v, double d = 0) => Math.Truncate(Num(v, d));

        static double FPosMod(double x, double y)
        {
            double v = x % y;
            if ((v < 0 && y > 0) || (v > 0 && y < 0)) v += y;
            return v;
        }

        // JS Number.prototype.toString for doubles (shortest round-trip digits).
        public static string JsNumber(double x)
        {
            if (double.IsNaN(x)) return "NaN";
            if (double.IsInfinity(x)) return x > 0 ? "Infinity" : "-Infinity";
            if (x == 0) return "0";
            string r = Math.Abs(x).ToString("R", Inv);
            int e = 0, ei = r.IndexOfAny(new[] { 'E', 'e' });
            if (ei >= 0) { e = int.Parse(r.Substring(ei + 1), Inv); r = r.Substring(0, ei); }
            int dot = r.IndexOf('.');
            string digits = r.Replace(".", "");
            int n = (dot < 0 ? r.Length : dot) + e;
            while (digits.Length > 1 && digits[0] == '0') { digits = digits.Substring(1); n--; }
            digits = digits.TrimEnd('0');
            int k = digits.Length;
            string body;
            if (k <= n && n <= 21) body = digits + new string('0', n - k);
            else if (0 < n && n <= 21) body = digits.Substring(0, n) + "." + digits.Substring(n);
            else if (-6 < n && n <= 0) body = "0." + new string('0', -n) + digits;
            else
            {
                int ex = n - 1;
                body = digits.Substring(0, 1) + (k > 1 ? "." + digits.Substring(1) : "") + "e" + (ex < 0 ? "-" : "+") + Math.Abs(ex);
            }
            return (x < 0 ? "-" : "") + body;
        }

        // GDScript str(float): integral values keep ".0".
        public static string FmtFloat(double x)
        {
            if (Math.Floor(x) == x && !double.IsInfinity(x))
                return Math.Abs(x) < 1e21 ? JsNumber(x) + ".0" : JsNumber(x);
            return JsNumber(x);
        }

        public static double SrgbToLinear(double c)
        {
            double v = Math.Max(0, c);
            return v <= 0.04045 ? v / 12.92 : Math.Pow((v + 0.055) / 1.055, 2.4);
        }

        // ---- curve runtime. null === unsupported / malformed ----
        static bool CurveIsValid(JObject curve)
        {
            var keys = Dget(curve, "keys", null) as JArray;
            if (keys == null || keys.Count == 0) return false;
            for (int i = 0; i < keys.Count; i++)
            {
                var k = keys[i] as JObject;
                if (k == null) return false;
                double type = Int(Dget(k, "type", null), -1);
                if (type != 0 && type != 1 && type != 2) return false;
                if (i > 0 && ToNumber(Dget(k, "time", null)) <= ToNumber(Dget(keys[i - 1], "time", null))) return false;
                var data = Dget(k, "data", null) as JArray;
                if (data == null || data.Count < 3) return false;
                foreach (JToken n in data)
                    if (!double.IsFinite(ToNumber(n))) return false;
            }
            return IsEmpty(Dget(curve, "unknown_fields", null));
        }

        static double[] KeyValue(JToken key, bool rgb)
        {
            var d = (JArray)key["data"];
            return rgb ? new[] { ToNumber(d[0]), ToNumber(d[1]), ToNumber(d[2]) } : new[] { ToNumber(d[2]) };
        }

        // Returns scalar JValue, RGB JArray, or null.
        public static JToken CurveValue(JToken curve, double time)
        {
            if (!double.IsFinite(time) || !(curve is JObject)) return null;
            object cached;
            if (!ValidCurves.TryGetValue(curve, out cached))
            {
                cached = CurveIsValid((JObject)curve);
                ValidCurves.Add(curve, cached);
            }
            if (!(bool)cached) return null;
            var keys = (JArray)curve["keys"];
            JToken kind = Dget(curve, "kind", null);
            bool rgb = kind != null && kind.Type == JTokenType.String && (string)kind == "rgb";
            double start = ToNumber(keys[0]["time"]);
            double end = ToNumber(keys[keys.Count - 1]["time"]);
            double t = time, cycles = 0;
            if (t < start || t > end)
            {
                JToken behavior = Dget(curve, t < start ? "BvPr" : "BvPo", null);
                if (Nul(behavior)) return null;
                double b = Int(behavior);
                if (b == 0) t = Math.Min(Math.Max(t, start), end);
                else if ((b == 1 || b == 2) && end > start)
                {
                    cycles = Math.Floor((t - start) / (end - start));
                    t = start + FPosMod(t - start, end - start);
                    if (b == 1) cycles = 0;
                }
                else return null;
            }
            double[] result = null;
            for (int i = 0; i < keys.Count; i++)
            {
                double ti = ToNumber(keys[i]["time"]);
                if (t == ti) { result = KeyValue(keys[i], rgb); break; }
                if (i == 0 || t > ti) continue;
                JToken left = keys[i - 1], right = keys[i];
                double x0 = ToNumber(left["time"]), x3 = ToNumber(right["time"]);
                double u = (t - x0) / (x3 - x0);
                double leftType = Int(left["type"]);
                if (leftType == 2) u = 0;
                else if (leftType == 0)
                {
                    if (rgb) return null;
                    double half = (x3 - x0) / 2;
                    double x1 = x0 + ToNumber(left["data"][0]) * half;
                    double x2 = x3 - ToNumber(left["data"][1]) * half;
                    double a = x1 - x0, bb = x2 - x1, c = x3 - x2;
                    double qa = a - 2 * bb + c, qb = 2 * (bb - a);
                    double minimum = Math.Min(a, c);
                    if (qa > 0)
                    {
                        double critical = -qb / (2 * qa);
                        if (critical > 0 && critical < 1) minimum = Math.Min(minimum, (qa * critical + qb) * critical + a);
                    }
                    if (minimum < 0) return null;
                    double low = 0, high = 1;
                    for (int n = 0; n < 48; n++)
                    {
                        double q = (low + high) / 2, v = 1 - q;
                        double x = v * v * v * x0 + 3 * v * v * q * x1 + 3 * v * q * q * x2 + q * q * q * x3;
                        if (x < t) low = q; else high = q;
                    }
                    u = (low + high) / 2;
                    u = u * u * (3 - 2 * u);
                }
                double[] l = KeyValue(left, rgb), r = KeyValue(right, rgb);
                result = new double[l.Length];
                for (int j = 0; j < l.Length; j++) result[j] = l[j] + (r[j] - l[j]) * u;
                break;
            }
            if (result == null) return null;
            if (cycles != 0)
            {
                double[] first = KeyValue(keys[0], rgb), last = KeyValue(keys[keys.Count - 1], rgb);
                for (int j = 0; j < result.Length; j++) result[j] += (last[j] - first[j]) * cycles;
            }
            return rgb ? (JToken)new JArray(result[0], result[1], result[2]) : new JValue(result[0]);
        }

        // Scalar-only view of CurveValue (RGB result -> null).
        static double? Sc(JToken curve, double time) => CurveValue(curve, time) is JValue v ? (double?)(double)v : null;

        // Portable preview PRNG (FNV-1a + integer mix); not the game's RNG.
        public static double Unit(uint seed, string channel, double tick = 0)
        {
            uint bits = 2166136261u;
            unchecked
            {
                foreach (byte b in Encoding.UTF8.GetBytes(seed.ToString(Inv) + ":" + channel + ":" + JsNumber(tick)))
                    bits = (bits ^ b) * 16777619u;
                bits = (bits ^ (bits >> 16)) * 0x45d9f3bu;
                bits = (bits ^ (bits >> 16)) * 0x45d9f3bu;
                bits ^= bits >> 16;
            }
            return bits / 4294967296.0;
        }

        static double? RandomValue(double mode, uint seed, string channel, double time)
        {
            if (mode < 0 || mode > 5) return null;
            double n = Unit(seed, channel, mode >= 3 ? Math.Floor(time) : 0);
            switch ((int)mode % 3)
            {
                case 0: return n * 2 - 1;
                case 1: return n;
                default: return -n;
            }
        }

        public static double? Scalar(JToken curve, JToken randomCurve, double time, uint seed, string channel, double defaultValue)
        {
            double? result = IsEmpty(curve) ? defaultValue : Sc(curve, time);
            if (result == null) return null;
            if (!IsEmpty(randomCurve))
            {
                double? amplitude = Sc(randomCurve, time);
                if (amplitude == null) return null;
                if (amplitude.Value != 0)
                {
                    JToken mode = Dget(curve, "RanT", Dget(randomCurve, "RanT", null));
                    if (Nul(mode)) return null;
                    double? n = RandomValue(Int(mode), seed, channel, time);
                    if (n == null) return null;
                    result = result.Value + amplitude.Value * n.Value;
                }
            }
            return result;
        }

        public static Vector3? Axes(JToken data, double time, uint seed, string channel, double defaultValue)
        {
            JToken curves = Dget(data, "axes", new JObject());
            var raw = new double[3];
            var amp = new double[3];
            for (int i = 0; i < 3; i++)
            {
                JToken main = Dget(curves, AxisNames[i], new JObject());
                JToken random = Dget(curves, AxisNames[i] + "R", new JObject());
                double? bv = IsEmpty(main) ? defaultValue : Sc(main, time);
                double? av = IsEmpty(random) ? 0 : Sc(random, time);
                if (bv == null || av == null) return null;
                raw[i] = bv.Value;
                amp[i] = av.Value;
            }
            JToken link = Dget(data, "ACT", new JValue(0));
            JToken randomLink = Dget(data, "ACTR", new JValue(0));
            if (Nul(link) || Nul(randomLink)) return null;
            double li = Int(link), ri = Int(randomLink);
            if (li < 0 || li >= AxisLinks.Length || ri < 0 || ri >= AxisLinks.Length) return null;
            var o = new float[3];
            for (int i = 0; i < 3; i++)
            {
                int m = AxisLinks[(int)li][i], r = AxisLinks[(int)ri][i];
                JToken mainCurve = Dget(curves, AxisNames[m], new JObject());
                JToken mode = Dget(mainCurve, "RanT", Dget(Dget(curves, AxisNames[r] + "R", new JObject()), "RanT", null));
                double offset = 0;
                if (amp[r] != 0)
                {
                    if (Nul(mode)) return null;
                    double? draw = RandomValue(Int(mode), seed, channel + "/" + AxisNames[r], time);
                    if (draw == null) return null;
                    offset = amp[r] * draw.Value;
                }
                o[i] = (float)(raw[m] + offset);
            }
            return new Vector3(o[0], o[1], o[2]);
        }

        public static Color? Colour(JToken data, double time, uint seed, string channel)
        {
            JToken tok = data is JObject d && d.Property("RGB") != null ? CurveValue(d["RGB"], time) : new JArray(1.0, 1.0, 1.0);
            var rgb = tok as JArray;
            if (rgb == null) return null;
            double? alpha = Scalar(Dget(data, "A", new JObject()), Dget(data, "RanA", new JObject()), time, seed, channel + "/A", 1);
            double? bri = Scalar(Dget(data, "Bri", new JObject()), Dget(data, "RBri", new JObject()), time, seed, channel + "/Bri", 1);
            if (alpha == null || bri == null) return null;
            var o = new float[4];
            for (int i = 0; i < 4; i++)
            {
                string axis = "RGBA".Substring(i, 1);
                JToken ran = i < 3 ? Dget(data, "Ran" + axis, new JObject()) : new JObject();
                double? mul = Scalar(Dget(data, "Scl" + axis, new JObject()), ran, time, seed, channel + "/" + axis, 1);
                if (mul == null) return null;
                double basis = i < 3 ? SrgbToLinear((double)rgb[i]) * bri.Value : alpha.Value;
                o[i] = (float)(basis * mul.Value);
            }
            return new Color(o[0], o[1], o[2], o[3]);
        }

        // -1 means no life limit (disabled/empty); null means unsupported.
        public static double? Life(JToken data, uint seed, string channel)
        {
            if (IsEmpty(data) || !Truthy(Dget(data, "enabled", new JValue(true)))) return -1;
            JToken bv = Dget(data, "Val", null), av = Dget(data, "ValR", null);
            if (Nul(bv) || Nul(av)) return null;
            if (ToNumber(av) == 0) return ToNumber(bv);
            JToken mode = Dget(data, "Type", null);
            if (Nul(mode)) return null;
            double? draw = RandomValue(Int(mode), seed, channel, 0);
            return draw == null ? (double?)null : ToNumber(bv) + ToNumber(av) * draw.Value;
        }
    }
}
