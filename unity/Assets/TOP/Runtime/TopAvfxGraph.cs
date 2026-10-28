// SPDX-License-Identifier: MIT
// Deterministic source-preview graph; host clip state and original renderer equivalence remain unimplemented.
using System;
using System.Collections.Generic;
using System.Globalization;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Top.UnityReplay
{
    public sealed class TopAvfxGraph
    {
        public sealed class Particle
        {
            public string Key;
            public int Index, Kind, Binder;
            public double Age;
            public Matrix4x4 TransformRH;
            public Color Color;
        }

        private sealed class Inf
        {
            public JObject V = new JObject();
            public bool Emission;
            public int Model, Number, Method;
        }

        private sealed class Link
        {
            public string Group;
            public int Index;
            public double Birth;
            public Inf Influence;
            public string Key;
        }

        private sealed class Trig
        {
            public int Slot;
            public double Frame;
        }

        private const double MAX_FRAME = 1800;
        private const int MAX_WORK = 16000;
        private const int MAX_PARTICLES = 2048;
        private const int MAX_DEPTH = 16;
        private const int MAX_TIMELINE_CYCLES = 256;
        private static readonly int[] SupportedKinds = { 1, 2, 5, 6, 8, 10, 12, 13 };
        // Source Euler orders XYZ,YZX,ZXY,XZY,YXZ,ZYX as axis sequences (matrix = R(a0) * R(a1) * R(a2)).
        private static readonly int[][] EulerOrders = { new[] { 0, 1, 2 }, new[] { 1, 2, 0 }, new[] { 2, 0, 1 }, new[] { 0, 2, 1 }, new[] { 1, 0, 2 }, new[] { 2, 1, 0 } };

        public readonly HashSet<string> Diagnostics = new HashSet<string>();
        public int Work { get; private set; }

        private readonly JObject groups;
        private readonly JArray models;
        private readonly uint seed;
        private readonly int slotCount;
        private readonly List<Trig> triggers = new List<Trig>();
        private int activeBinder = -1;

        private readonly bool valid;
        public TopAvfxGraph(JObject pack,uint seed)
        {
            this.seed=seed;groups=pack?["groups"] as JObject??new JObject();models=pack?["models"] as JArray??new JArray();slotCount=12;
            valid=pack!=null&&Int(pack["schema"],-1)==1&&pack["groups"] is JObject;
            if(!valid){Diagnostics.Add("invalid_document");return;}
            Diagnostics.Add("experimental_preview_not_game_equivalence");
            foreach(var item in Arr(pack["unsupported"]))Diagnostics.Add("source_unsupported/"+(string)item["reason"]);
            if(groups["Efct"] is JArray effects&&effects.Count>0)Diagnostics.Add("unsupported_group/Efct");
        }

        public bool Trigger(int slot, double atFrame)
        {
            if (slot < 0 || slot >= slotCount || double.IsNaN(atFrame) || double.IsInfinity(atFrame) || atFrame < 0 || atFrame > MAX_FRAME) return false;
            triggers.Add(new Trig { Slot = slot, Frame = atFrame });
            return true;
        }

        public List<Particle> Sample(double atFrame)
        {
            Diagnostics.Remove("invalid_frame");
            Diagnostics.Remove("budget_exceeded");
            Work = 0;
            var result = new List<Particle>();
            if(!valid)return result;
            if (double.IsNaN(atFrame) || double.IsInfinity(atFrame) || atFrame < 0 || atFrame > MAX_FRAME)
            {
                Diagnostics.Add("invalid_frame");
                return result;
            }
            var keys = new HashSet<string>();
            foreach (JToken scheduler in Arr("Schd"))
            {
                int slot = 0;
                foreach (JToken item in Arr(Get(scheduler, "items")))
                {
                    JObject values = Obj(item["values"]);
                    if ((string)item["role"] == "trigger_timeline")
                    {
                        foreach (Trig ev in triggers)
                            if (ev.Slot == slot)
                                Schedule(values, ev.Frame, atFrame, "s" + Str(scheduler["index"]) + "/t" + slot + "/" + TopAvfxMath.FmtFloat(ev.Frame), result, keys);
                        slot++;
                    }
                    else Schedule(values, 0, atFrame, "s" + Str(scheduler["index"]) + "/" + Str(item["source_index"]), result, keys);
                }
            }
            if (Diagnostics.Contains("budget_exceeded")) result.Clear();
            return result;
        }

        // ------------------------------------------------------------ generic helpers
        private static JObject Obj(JToken t) { return t as JObject ?? new JObject(); }

        private static JToken Get(JToken t, string k)
        {
            JToken r = (t as JObject)?[k];
            return r == null || r.Type == JTokenType.Null ? new JObject() : r;
        }

        private IEnumerable<JToken> Arr(string group) { return Arr(groups[group]); }

        private static IEnumerable<JToken> Arr(JToken t)
        {
            JArray a = t as JArray;
            return a != null ? (IEnumerable<JToken>)a : new JToken[0];
        }

        private static double Num(JToken t, double d = 0)
        {
            if (t == null || (t.Type != JTokenType.Integer && t.Type != JTokenType.Float)) return d;
            double v = (double)t;
            return double.IsNaN(v) || double.IsInfinity(v) ? d : v;
        }

        private static int Int(JToken t, int d = 0)
        {
            double v = Num(t, double.NaN);
            if (double.IsNaN(v)) return d;
            return (int)Math.Max(int.MinValue, Math.Min(int.MaxValue, Math.Truncate(v)));
        }

        private static bool Truthy(JToken t)
        {
            if (t == null) return false;
            if (t.Type == JTokenType.Boolean) return (bool)t;
            if (t.Type == JTokenType.Integer || t.Type == JTokenType.Float) return (double)t != 0;
            if (t.Type == JTokenType.String) return ((string)t).Length > 0;
            return false;
        }

        private static bool Enabled(JObject v,string name){var t=v[name];if(t is JObject wrapped)t=wrapped["value"];if(t==null)return false;if(t.Type==JTokenType.Boolean)return (bool)t;return (t.Type==JTokenType.Integer||t.Type==JTokenType.Float)&&(double)t==1;}

        private static string Str(JToken t)
        {
            if (t == null) return "undefined";
            if (t.Type == JTokenType.Integer) return ((long)t).ToString(CultureInfo.InvariantCulture);
            if (t.Type == JTokenType.Float) return TopAvfxMath.FmtFloat((double)t);
            return t.ToString();
        }

        private static double FPosMod(double a, double b) { return ((a % b) + b) % b; }

        private JObject Node(string group, int index)
        {
            JArray nodes = groups[group] as JArray;
            JObject node = nodes != null && index >= 0 && index < nodes.Count ? nodes[index] as JObject : null;
            if (node == null) Diagnostics.Add("invalid_reference/" + group);
            return node;
        }

        private bool Tick()
        {
            Work++;
            if (Work > MAX_WORK) { Diagnostics.Add("budget_exceeded"); return false; }
            return true;
        }

        private static double Local(JObject node, double age)
        {
            JObject v = Obj(node["values"]);
            double start = Num(v["LpSt"]), end = Num(v["LpEd"]);
            return end > start && age >= end ? start + FPosMod(age - start, end - start) : age;
        }

        // ------------------------------------------------------------ schedule / emit
        private void Schedule(JObject values, double start, double now, string key, List<Particle> result, HashSet<string> keys)
        {
            if (!Enabled(values, "bEna") || Int(values["TlNo"], -1) < 0) return;
            double birth = start + Num(values["StTm"]);
            if (now < birth) return;
            JObject node = Node("TmLn", Int(values["TlNo"]));
            if (node == null) return;
            JObject nv = Obj(node["values"]);
            foreach (JToken item in Arr(node["items"]))
            {
                JObject v = Obj(item["values"]);
                if (!Enabled(v, "bEna")) continue;
                int clipIndex = Int(v["ClNo"], -1);
                if (clipIndex >= 0) { Clip(node, clipIndex, birth + Num(v["StTm"]), now); continue; }
                int emitter = Int(v["EmNo"], -1);
                if (emitter < 0) continue;
                activeBinder = Num(v["BdNo"], -1) >= 0 ? Int(v["BdNo"]) : Int(nv["BnNo"], -1);
                double itemStart = Num(v["StTm"]);
                double itemEnd = Num(v["EdTm"], -1);
                string baseKey = key + "/i" + Str(item["source_index"]);
                ScheduleItem(emitter, birth, itemStart, itemEnd, now, baseKey, result, keys);
                double loopStart = Num(nv["LpSt"]), loopEnd = Num(nv["LpEd"]);
                if (loopEnd <= loopStart || itemStart < loopStart || itemStart >= loopEnd) continue;
                double period = loopEnd - loopStart;
                int cycle = 1;
                while (cycle <= MAX_TIMELINE_CYCLES)
                {
                    double shifted = itemStart + period * cycle;
                    if (birth + shifted > now) break;
                    if (!Tick()) return;
                    ScheduleItem(emitter, birth, shifted, itemEnd >= 0 ? itemEnd + period * cycle : -1, now, baseKey + "/c" + cycle, result, keys);
                    cycle++;
                }
                if (cycle > MAX_TIMELINE_CYCLES && birth + itemStart + period * cycle <= now) Diagnostics.Add("timeline_cycle_limit");
            }
        }

        private void ScheduleItem(int emitter, double timelineBirth, double itemStart, double itemEnd, double now, string key, List<Particle> result, HashSet<string> keys)
        {
            double emitterBirth = timelineBirth + itemStart;
            if (now < emitterBirth) return;
            double stop = itemEnd >= 0 ? timelineBirth + itemEnd : double.PositiveInfinity;
            Emit(emitter, emitterBirth, now, new List<Link>(), key, result, keys, 0, stop, new Inf());
        }

        // Clips need runtime state this stateless sampler does not model: diagnose, never emulate.
        private void Clip(JObject timeline, int index, double at, double now)
        {
            JArray clips = timeline["clips"] as JArray;
            if (clips == null || index < 0 || index >= clips.Count) { Diagnostics.Add("invalid_timeline_clip_reference"); return; }
            if (now < at) return;
            int kind=Int(Get(clips[index],"type"));switch(kind){case 1280067915:case 541347397:Diagnostics.Add("timeline_clip_stop_requires_runtime_state");break;case 1414743378:Diagnostics.Add("timeline_clip_reset_requires_runtime_state");break;case 1347177557:Diagnostics.Add("timeline_clip_unlock_requires_runtime_state");break;case 1229209926:Diagnostics.Add("timeline_clip_fade_requires_runtime_state");break;case 541545044:case 1196577874:Diagnostics.Add("timeline_clip_trigger_requires_runtime_state");break;default:Diagnostics.Add("timeline_clip_unknown/"+kind);break;}
        }

        private void Emit(int index, double birth, double now, List<Link> ancestors, string key, List<Particle> result, HashSet<string> keys, int depth, double stop, Inf influence)
        {
            if (depth >= MAX_DEPTH || !Tick()) { Diagnostics.Add("budget_exceeded"); return; }
            JObject node = Node("Emit", index);
            if (node == null) return;
            double? lifeValue = TopAvfxMath.Life(Get(node, "life"), seed, key);
            if (!lifeValue.HasValue) { Diagnostics.Add("life"); return; }
            if (now - birth < 0) return;
            JObject nv = Obj(node["values"]);
            bool looped = Num(nv["LpEd"]) > Num(nv["LpSt"]);
            double end = Math.Min(now, stop);
            if (lifeValue.Value >= 0 && !looped) end = Math.Min(end, birth + lifeValue.Value);
            var chain = new List<Link>(ancestors);
            chain.Add(new Link { Group = "Emit", Index = index, Birth = birth, Influence = influence, Key = key });
            int emitterType = Int(nv["EVT"], -1);
            if (emitterType != 0 && emitterType != 5) { Diagnostics.Add("emitter_type/" + emitterType); return; }
            JToken curves = Get(node, "curves");
            JObject data = Obj(node["data"]);
            foreach (JToken item in Arr(node["items"]))
            {
                JObject v = Obj(item["values"]);
                if (!Enabled(v, "bEnb")) continue;
                double generation = Math.Max(0, Num(v["CrTm"], 1) - 1);
                int eventIndex = 0;
                while (birth + generation <= end)
                {
                    if (!Tick()) return;
                    double clock = Local(node, generation);
                    double? interval = TopAvfxMath.Scalar(Get(curves, "CrI"), Get(curves, "CrIR"), clock, seed, key + "/interval", 1);
                    double? count = TopAvfxMath.Scalar(Get(curves, "CrC"), Get(curves, "CrCR"), clock, seed, key + "/count", 1);
                    if (!interval.HasValue || !count.HasValue || interval.Value <= 0 || count.Value < 0) { Diagnostics.Add("emission_curve"); break; }
                    double chance = Num(v["CrPr"], 100);
                    if (Int(v["CrCn"], 1) < 0 || chance < 0 || chance > 100) { Diagnostics.Add("invalid_emission_item"); return; }
                    double amountD = Math.Floor(count.Value) * Int(v["CrCn"], 1);
                    if (amountD > MAX_PARTICLES) { Diagnostics.Add("budget_exceeded"); return; }
                    int amount = (int)amountD;
                    for (int number = 0; number < amount; number++)
                    {
                        if (!Tick()) return;
                        string childKey = key + "/" + Int(item["source_index"]) + "/" + eventIndex + "/" + number;
                        if (TopAvfxMath.Unit(seed, childKey + "/chance") * 100 >= chance) continue;
                        double childBirth = birth + generation + Num(v["GenD"]) * (Enabled(v, "bGD") ? number : 1);
                        if (childBirth > now) continue;
                        int childIndex = Int(v["TgtB"], -1);
                        if (childIndex < 0) continue;
                        var childInfluence = new Inf { V = v };
                        if (emitterType == 5)
                        {
                            childInfluence.Emission = true;
                            childInfluence.Model = Int(data["MdNo"], -1);
                            childInfluence.Number = number;
                            childInfluence.Method = Int(data["GeMT"], -1);
                        }
                        string role = (string)item["role"];
                        if (role == "child_emitter") Emit(childIndex, childBirth, now, chain, childKey, result, keys, depth + 1, stop, childInfluence);
                        else if (role == "child_particle") AddParticle(childIndex, childBirth, now, chain, childKey, result, keys, childInfluence);
                    }
                    eventIndex++;
                    generation += Math.Max(0.01, interval.Value);
                }
            }
        }

        private void AddParticle(int index, double birth, double now, List<Link> ancestors, string key, List<Particle> result, HashSet<string> keys, Inf influence)
        {
            if (!Tick()) return;
            JObject node = Node("Ptcl", index);
            if (node == null) return;
            double age = now - birth + Num(influence.V["StFr"]);
            double? lifeValue = TopAvfxMath.Life(Get(node, "life"), seed, key);
            if (Enabled(influence.V, "bOvr"))
                lifeValue = Num(influence.V["OvrV"]) + TopAvfxMath.Unit(seed, key + "/override") * Num(influence.V["OvrR"]);
            if (!lifeValue.HasValue) { Diagnostics.Add("life"); return; }
            JObject nv = Obj(node["values"]);
            bool looped = Num(nv["LpEd"]) > Num(nv["LpSt"]);
            if (age < 0 || (!looped && lifeValue.Value >= 0 && age >= lifeValue.Value)) return;
            int kind = Int(nv["PrVT"], -1);
            if (Array.IndexOf(SupportedKinds, kind) < 0) { Diagnostics.Add("particle_type/" + kind); return; }
            var chain = new List<Link>(ancestors);
            chain.Add(new Link { Group = "Ptcl", Index = index, Birth = birth, Influence = influence, Key = key });
            Matrix4x4? pose = ChainTransform(chain, chain.Count, now);
            Color? tint = ChainColor(chain, chain.Count, now);
            if (!pose.HasValue || !tint.HasValue) return;
            if (result.Count >= MAX_PARTICLES) { Diagnostics.Add("budget_exceeded"); return; }
            if (keys.Contains(key)) { Diagnostics.Add("duplicate_particle_key"); return; }
            keys.Add(key);
            result.Add(new Particle { Key = key, Index = index, Kind = kind, Age = Local(node, age), TransformRH = pose.Value, Color = tint.Value, Binder = activeBinder });
        }

        // ------------------------------------------------------------ transforms / colour
        private Matrix4x4? ChainTransform(List<Link> chain, int n, double atFrame)
        {
            if (n == 0) return Matrix4x4.identity;
            Link link = chain[n - 1];
            JObject node = Node(link.Group, link.Index);
            if (node == null) return null;
            Inf influence = link.Influence;
            double age = Local(node, Math.Max(0, atFrame - link.Birth));
            JObject ax = Obj(node["axes"]);
            Vector3? position = TopAvfxMath.Axes(Get(ax, "Pos"), age, seed, link.Key + "/Pos", 0);
            Vector3? rotation = TopAvfxMath.Axes(Get(ax, "Rot"), age, seed, link.Key + "/Rot", 0);
            Vector3? scaleValue = TopAvfxMath.Axes(Get(ax, "Scl"), age, seed, link.Key + "/Scl", 1);
            if (!position.HasValue || !rotation.HasValue || !scaleValue.HasValue) { Diagnostics.Add("transform_curve"); return null; }
            JObject nv = Obj(node["values"]);
            int rotationOrder = Int(nv[link.Group == "Emit" ? "ROT" : "RoOT"], 0);
            if (rotationOrder < 0 || rotationOrder > 5) { Diagnostics.Add("rotation_order"); return null; }
            int[] o = EulerOrders[rotationOrder];
            float[] angles = { rotation.Value.x, rotation.Value.y, rotation.Value.z };
            Matrix4x4 R = RotAxis(o[0], angles[o[0]]) * RotAxis(o[1], angles[o[1]]) * RotAxis(o[2], angles[o[2]]);
            Matrix4x4 S = Matrix4x4.identity;
            S.m00 = scaleValue.Value.x; S.m11 = scaleValue.Value.y; S.m22 = scaleValue.Value.z;
            Matrix4x4 T = Matrix4x4.identity;
            T.m03 = position.Value.x; T.m13 = position.Value.y; T.m23 = position.Value.z;
            Matrix4x4 local;
            switch (Int(nv["CCOT"], 0))
            {
                case 0: local = T * R * S; break;
                case 1: local = R * S * T; break;
                case 2: local = S * T * R; break;
                case 3: local = S * R * T; break;
                case 4: local = R * T * S; break;
                case 5: local = T * S * R; break;
                default: Diagnostics.Add("coordinate_order"); return null;
            }
            if (n == 1) return local;
            int mode = Int(influence.V["PICd"], 2);
            double parentTime = mode == 0 || mode == 1 || mode == 3 || mode == 5 ? link.Birth : atFrame;
            Matrix4x4? parent = ChainTransform(chain, n - 1, parentTime);
            if (!parent.HasValue) return null;
            Matrix4x4 inherited = parent.Value;
            if (mode == 6) inherited = Matrix4x4.identity;
            else if (mode == 4 || mode == 5 || mode == 7) inherited = ClearOrigin(inherited);
            else if (!(mode >= 0 && mode <= 3)) { Diagnostics.Add("parent_influence"); return null; }
            if (mode == 1 || mode == 7)
            {
                Vector3 s = Enabled(influence.V, "ICbS") ? BasisScale(inherited) : Vector3.one;
                Vector3[] r = Enabled(influence.V, "ICbR") ? OrthonormalColumns(inherited) : new[] { Vector3.right, Vector3.up, Vector3.forward };
                // Godot Basis.scaled(): rows multiplied by scale, i.e. diag(s) * R.
                var scaled = new Vector3[3];
                for (int j = 0; j < 3; j++) scaled[j] = new Vector3(r[j].x * s.x, r[j].y * s.y, r[j].z * s.z);
                inherited = SetBasis(inherited, scaled);
                if (!Enabled(influence.V, "ICbP")) inherited = ClearOrigin(inherited);
            }
            if (influence.Emission)
            {
                if (influence.Model < 0 || influence.Model >= models.Count) { Diagnostics.Add("emission_model"); return null; }
                JToken model = models[influence.Model];
                JArray vertices = Get(model, "emission_vertices") as JArray ?? new JArray();
                JArray ordering = Get(model, "emission_order") as JArray ?? new JArray();
                if (influence.Method != 3 || vertices.Count == 0) { Diagnostics.Add("model_emission_method/" + influence.Method); return null; }
                int vertexIndex = influence.Number % vertices.Count;
                if (ordering.Count > 0) vertexIndex = Int(ordering[vertexIndex % ordering.Count]);
                if (vertexIndex < 0 || vertexIndex >= vertices.Count) { Diagnostics.Add("emission_order"); return null; }
                JArray p = Get(vertices[vertexIndex], "position") as JArray;
                if (p == null || p.Count < 3) { Diagnostics.Add("emission_order"); return null; }
                local.m03 += (float)Num(p[0]); local.m13 += (float)Num(p[1]); local.m23 += (float)Num(p[2]);
            }
            return inherited * local;
        }

        private Color? ChainColor(List<Link> chain, int n, double atFrame)
        {
            if (n == 0) return Color.white;
            Link link = chain[n - 1];
            JObject node = Node(link.Group, link.Index);
            if (node == null) return null;
            Color? tint = TopAvfxMath.Colour(Get(node, "color"), Local(node, Math.Max(0, atFrame - link.Birth)), seed, link.Key + "/color");
            if (!tint.HasValue) { Diagnostics.Add("color_curve"); return null; }
            int mode = Int(link.Influence.V["PICo"], 0);
            Color result = tint.Value;
            if (n > 1 && mode != 0)
            {
                Color? parent = ChainColor(chain, n - 1, mode == 1 ? link.Birth : atFrame);
                if (!parent.HasValue) return null;
                result = new Color(result.r * parent.Value.r, result.g * parent.Value.g, result.b * parent.Value.b, result.a * parent.Value.a);
            }
            return result;
        }

        // ------------------------------------------------------------ matrix utilities
        private static Matrix4x4 RotAxis(int axis, float a)
        {
            float c = (float)Math.Cos(a), s = (float)Math.Sin(a);
            Matrix4x4 m = Matrix4x4.identity;
            if (axis == 0) { m.m11 = c; m.m12 = -s; m.m21 = s; m.m22 = c; }
            else if (axis == 1) { m.m00 = c; m.m02 = s; m.m20 = -s; m.m22 = c; }
            else { m.m00 = c; m.m01 = -s; m.m10 = s; m.m11 = c; }
            return m;
        }

        private static Vector3[] Columns(Matrix4x4 m)
        {
            return new[] { new Vector3(m.m00, m.m10, m.m20), new Vector3(m.m01, m.m11, m.m21), new Vector3(m.m02, m.m12, m.m22) };
        }

        private static float Det3(Matrix4x4 m)
        {
            return m.m00 * (m.m11 * m.m22 - m.m12 * m.m21) - m.m01 * (m.m10 * m.m22 - m.m12 * m.m20) + m.m02 * (m.m10 * m.m21 - m.m11 * m.m20);
        }

        private static Vector3 Norm(Vector3 v)
        {
            float l = v.magnitude;
            return v / (l == 0f ? 1f : l);
        }

        private static Vector3 BasisScale(Matrix4x4 m)
        {
            Vector3[] c = Columns(m);
            float sign = Det3(m) < 0f ? -1f : 1f;
            return new Vector3(c[0].magnitude, c[1].magnitude, c[2].magnitude) * sign;
        }

        // Gram-Schmidt on columns, as Basis.orthonormalized().
        private static Vector3[] OrthonormalColumns(Matrix4x4 m)
        {
            Vector3[] c = Columns(m);
            Vector3 x = Norm(c[0]);
            Vector3 y = Norm(c[1] - x * Vector3.Dot(x, c[1]));
            Vector3 z = Norm(c[2] - x * Vector3.Dot(x, c[2]) - y * Vector3.Dot(y, c[2]));
            return new[] { x, y, z };
        }

        private static Matrix4x4 SetBasis(Matrix4x4 m, Vector3[] c)
        {
            m.m00 = c[0].x; m.m10 = c[0].y; m.m20 = c[0].z;
            m.m01 = c[1].x; m.m11 = c[1].y; m.m21 = c[1].z;
            m.m02 = c[2].x; m.m12 = c[2].y; m.m22 = c[2].z;
            return m;
        }

        private static Matrix4x4 ClearOrigin(Matrix4x4 m)
        {
            m.m03 = 0f; m.m13 = 0f; m.m23 = 0f;
            return m;
        }
    }
}
