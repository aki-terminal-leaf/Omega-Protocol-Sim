// SPDX-License-Identifier: MIT
using System;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;
using Top.UnityReplay;
public static class TopMathGate {
 public static void Run(){try{Check();EditorApplication.Exit(0);}catch(Exception e){Debug.LogException(e);EditorApplication.Exit(1);}}
 public static void Check(){
  var data=JObject.Parse(File.ReadAllText(TopReplay.Arg("math-data")));var fails=new JArray();int count=0;
  foreach(var row in data["rows"]){count++;JToken result=null;string method=(string)row["method"];var input=row["input"];double time=(double)row["time"];uint seed=(uint)row["seed"];string channel=(string)row["channel"];
   switch(method){
    case "curve":result=TopAvfxMath.CurveValue(input,time);break;
    case "axes":var a=TopAvfxMath.Axes(input,time,seed,channel,1);if(a.HasValue)result=new JArray(a.Value.x,a.Value.y,a.Value.z);break;
    case "colour":var c=TopAvfxMath.Colour(input,time,seed,channel);if(c.HasValue)result=new JArray(c.Value.r,c.Value.g,c.Value.b,c.Value.a);break;
    case "life":var l=TopAvfxMath.Life(input,seed,channel);if(l.HasValue)result=new JValue(l.Value);break;
    case "unit":result=new JValue(TopAvfxMath.Unit(seed,channel,time));break;
    default:throw new Exception("Unknown oracle method "+method);
   }
   if(!Equal(result,row["expected"]))fails.Add(new JObject{{"case",count},{"method",method},{"actual",result},{"oracle",row["expected"]}});
  }
  var receipt=new JObject{{"status",fails.Count==0?"PASS":"FAIL"},{"cases",count},{"oracle_source_sha256",data["source_sha256"]},{"failures",fails},{"scope","math differential only; no original-game equivalence or native visual acceptance"}};
  File.WriteAllText(TopReplay.Arg("math-out"),receipt.ToString());Debug.Log("TOP_MATH_GATE "+receipt);if(fails.Count>0)throw new Exception(fails.Count+" math oracle failures");
 }
 static bool Equal(JToken actual,JToken expected){if(expected==null||expected.Type==JTokenType.Null)return actual==null||actual.Type==JTokenType.Null;if(actual==null||actual.Type==JTokenType.Null)return false;if(expected is JArray a){if(actual is not JArray b||a.Count!=b.Count)return false;for(int i=0;i<a.Count;i++)if(!Equal(b[i],a[i]))return false;return true;}double x=(double)actual,y=(double)expected;return Math.Abs(x-y)<=5e-6*Math.Max(1,Math.Abs(y));}
}
