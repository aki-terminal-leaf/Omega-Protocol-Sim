// SPDX-License-Identifier: MIT
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Text;
using System.Security.Cryptography;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;
using Top.UnityReplay;
public static class TopGraphGate {
 public static void Run(){try{Check();EditorApplication.Exit(0);}catch(Exception e){Debug.LogException(e);EditorApplication.Exit(1);}}
 static string Hash(string text){using var h=SHA256.Create();return BitConverter.ToString(h.ComputeHash(Encoding.UTF8.GetBytes(text))).Replace("-","").ToLowerInvariant();}
 static bool Near(double a,double b)=>double.IsFinite(a)&&Math.Abs(a-b)<=1e-4*Math.Max(1,Math.Abs(b));
 public static void Check(){
  var vectors=JObject.Parse(File.ReadAllText(TopReplay.Arg("graph-vectors")));var graphs=new Dictionary<string,TopAvfxGraph>();var fails=new JArray();int cases=0,compared=0,total=0;
  foreach(var row in vectors["records"]){cases++;string file=(string)row["file"];if(!graphs.TryGetValue(file,out var graph)){var pack=JObject.Parse(File.ReadAllText(Path.Combine(TopReplay.Arg("graph-data"),file)));graph=new TopAvfxGraph(pack,(uint)row["seed"]);graphs.Add(file,graph);}
   var particles=graph.Sample((double)row["frame"]);total+=particles.Count;var errors=new JArray();
   var text=string.Join("\n",particles.Select(p=>p.Key+"|"+p.Index+"|"+p.Kind+"|"+p.Binder));
   if(particles.Count!=(int)row["count"])errors.Add("count "+particles.Count+" != "+row["count"]);
   if(graph.Work!=(int)row["work"])errors.Add("work "+graph.Work+" != "+row["work"]);
   if(Hash(text)!=(string)row["keys_sha256"])errors.Add("full particle identity/order hash mismatch");
   if(graph.Diagnostics.Contains("budget_exceeded")!=(bool)row["budget"])errors.Add("budget mismatch");
   foreach(var selected in row["selected"]){int index=(int)selected["ordinal"];if(index>=particles.Count)continue;compared++;var p=particles[index];
    if(p.Key!=(string)selected["key"]||!Near(p.Age,(double)selected["age"]))errors.Add("identity/age "+index);
    for(int i=0;i<16;i++)if(!Near(p.TransformRH[i],(double)selected["transform"][i])){errors.Add("matrix "+index+"/"+i+" actual="+p.TransformRH[i]+" expected="+selected["transform"][i]);break;}
    for(int i=0;i<4;i++)if(!Near(p.Color[i],(double)selected["color"][i])){errors.Add("color "+index+"/"+i);break;}
   }
   if(errors.Count>0)fails.Add(new JObject{{"file",file},{"frame",row["frame"]},{"errors",errors},{"diagnostics",new JArray(graph.Diagnostics)}});
  }
  var receipt=new JObject{{"status",fails.Count==0?"PASS":"FAIL"},{"documents",graphs.Count},{"cases",cases},{"particles",total},{"selected_transform_color_particles",compared},{"source_sha256",vectors["source_sha256"]},{"failures",fails},{"scope","Source-preview CPU graph differential only; unsupported game host state/effectors and rendered fidelity remain OPEN"}};
  File.WriteAllText(TopReplay.Arg("graph-out"),receipt.ToString());Debug.Log("TOP_GRAPH_GATE "+(string)receipt["status"]+" cases="+cases+" failures="+fails.Count);if(fails.Count>0)throw new Exception(fails.Count+" graph differential cases failed");
 }
}
