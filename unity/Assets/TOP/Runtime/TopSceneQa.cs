// SPDX-License-Identifier: MIT
// Diagnostic isolation only: no production layer/material policy is inferred here.
using System;
using System.IO;
using System.Linq;
using System.Collections;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;
namespace Top.UnityReplay {
public sealed partial class TopReplay {
 IEnumerator SceneQa(string output){
  Directory.CreateDirectory(output);Playing=false;EffectsEnabled=false;AudioEnabled=false;var rows=new JArray();Seek(140000);foreach(var a in actors.Values)a.Root.SetActive(false);
  Capture(Path.Combine(output,"production.png"));var root=floors[Phase];var children=root.transform.Cast<Transform>().ToArray();var lights=GameObject.Find("Scene light").GetComponents<Light>();var lightIntensities=lights.Select(x=>x.intensity).ToArray();var mode=RenderSettings.ambientMode;var sky=RenderSettings.ambientSkyColor;var equator=RenderSettings.ambientEquatorColor;var ground=RenderSettings.ambientGroundColor;
  var materials=children.SelectMany(c=>c.GetComponentsInChildren<Renderer>(true)).SelectMany(r=>r.sharedMaterials).Where(m=>m&&m.HasProperty("emissiveFactor")).Distinct().ToArray();var colors=materials.Select(m=>m.GetColor("emissiveFactor")).ToArray();
  foreach(string test in new[]{"all","p1-only","p2-only","all-emission-only","p2-emission-only","all-no-emission"}){
   for(int i=0;i<materials.Length;i++)materials[i].SetColor("emissiveFactor",test=="all-no-emission"?Color.black:colors[i]);
   bool noLight=test.Contains("emission-only");for(int i=0;i<lights.Length;i++)lights[i].intensity=noLight?0:lightIntensities[i];RenderSettings.ambientMode=noLight?AmbientMode.Flat:mode;RenderSettings.ambientSkyColor=noLight?Color.black:sky;RenderSettings.ambientEquatorColor=noLight?Color.black:equator;RenderSettings.ambientGroundColor=noLight?Color.black:ground;
   foreach(var child in children){bool p1=child.name.Contains(":p1_boss/");child.gameObject.SetActive(test=="p1-only"?p1:test.StartsWith("p2-")?!p1:true);}
   yield return null;Capture(Path.Combine(output,test+".png"));rows.Add(new JObject{{"case",test},{"diagnostic_only",true},{"objects",new JArray(children.Where(c=>c.gameObject.activeSelf).Select(c=>new JObject{{"key",c.name},{"renderers",c.GetComponentsInChildren<Renderer>(true).Length}}))}});
  }
  foreach(var c in children)c.gameObject.SetActive(true);for(int i=0;i<materials.Length;i++)materials[i].SetColor("emissiveFactor",colors[i]);for(int i=0;i<lights.Length;i++)lights[i].intensity=lightIntensities[i];RenderSettings.ambientMode=mode;RenderSettings.ambientSkyColor=sky;RenderSettings.ambientEquatorColor=equator;RenderSettings.ambientGroundColor=ground;
  File.WriteAllText(Path.Combine(output,"states.json"),rows.ToString());File.WriteAllText(Path.Combine(output,"result.json"),new JObject{{"status","DIAGNOSTIC_LAYER_MATERIAL_ISOLATION_NOT_FIDELITY_ACCEPTANCE"},{"cases",rows.Count},{"complete",false}}.ToString());Application.Quit(0);
 }
}
}
