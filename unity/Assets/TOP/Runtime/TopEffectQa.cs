// SPDX-License-Identifier: MIT
using System;
using System.IO;
using System.Linq;
using System.Collections;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Top.UnityReplay {
public sealed partial class TopReplay {
 int FxPixelDiff(string before,string after){var a=new Texture2D(2,2);var b=new Texture2D(2,2);try{a.LoadImage(File.ReadAllBytes(before));b.LoadImage(File.ReadAllBytes(after));var av=a.GetPixels32();var bv=b.GetPixels32();int n=0;for(int i=0;i<av.Length;i++)if(Math.Abs(av[i].r-bv[i].r)+Math.Abs(av[i].g-bv[i].g)+Math.Abs(av[i].b-bv[i].b)>16)n++;return n;}finally{Destroy(a);Destroy(b);}}
 string FxStableState(){var r=EffectsReport();return new JArray(((JArray)r["instances"]).OrderBy(x=>S(x["key"])).Select(x=>new JObject{{"key",x["key"]},{"frame",x["frame"]},{"particles",x["particles"]},{"draws",x["draws"]},{"bindings",x["bindings"]}})).ToString(Newtonsoft.Json.Formatting.None);}
 IEnumerator FxQa(string output){
  Directory.CreateDirectory(output);Playing=false;var rows=new JArray();
  double[] times={15998,26500,80000,140000,158593,159700,200000,208000,210000,260000,270000,315900,477000,560000,650727,670500,673000,725900,884000,1039000,1068500,1109404};
  foreach(double t in times){
   EffectsEnabled=false;Seek(t);yield return null;
   string label=((int)t).ToString();string baseline=Path.Combine(output,label+"-base.png"),effect=Path.Combine(output,label+".png");Capture(baseline);
   EffectsEnabled=true;Seek(t);yield return null;Capture(effect);var state=EffectsReport();var row=new JObject{{"time",Clock},{"phase",Phase},{"changed_pixels",FxPixelDiff(baseline,effect)},{"effects",state},{"scene",Snapshot()}};
   rows.Add(row);File.WriteAllText(Path.Combine(output,"states.json"),rows.ToString());Debug.Log("TOP_EVENT_FX "+label+" phase "+Phase+" instances "+dirInstances.Count+" pixels "+row["changed_pixels"]);
  }
  // Absolute source sampling must not depend on whether a seek was forwards or backwards.
  Seek(208000);Capture(Path.Combine(output,"reverse-before.png"));string before=FxStableState();Seek(884000);Seek(208000);Capture(Path.Combine(output,"reverse-after.png"));string after=FxStableState();File.WriteAllText(Path.Combine(output,"reverse-before.json"),before);File.WriteAllText(Path.Combine(output,"reverse-after.json"),after);
  if(before!=after||FxPixelDiff(Path.Combine(output,"reverse-before.png"),Path.Combine(output,"reverse-after.png"))!=0)throw new Exception("Effect reverse seek was not deterministic");
  double paused=Clock;yield return null;yield return null;if(paused!=Clock)throw new Exception("Paused effect clock advanced");
  EffectsEnabled=false;Seek(208000);yield return null;if(dirInstances.Count!=0)throw new Exception("Effects disabled but instances survived");
  File.WriteAllText(Path.Combine(output,"result.json"),new JObject{{"status","CAPTURED_NOT_VISUALLY_ACCEPTED"},{"cases",rows.Count},{"gpu",SystemInfo.graphicsDeviceName},{"reverse_seek_exact",true},{"pause",true},{"disable_disposes_instances",true},{"complete",false}}.ToString());Application.Quit(0);
 }
}
}
