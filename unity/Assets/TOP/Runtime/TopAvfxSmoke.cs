// SPDX-License-Identifier: MIT
using System;
using System.IO;
using System.Linq;
using System.Collections;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Top.UnityReplay {
public sealed partial class TopReplay {
 Texture2D SourceTexture(string path){string id=S(Full["textures"]?[path]??Weapons["textures"]?[path]);if(id=="")throw new Exception("Undeclared source texture "+path);if(textures.TryGetValue(id,out var prior))return prior;var asset=Manifest["native_assets"]?[id];if(S(asset?["kind"])!="png")throw new Exception("Not a PNG source texture "+id);var texture=new Texture2D(2,2,TextureFormat.RGBA32,true,false){name=path,wrapMode=TextureWrapMode.Repeat,filterMode=FilterMode.Trilinear};if(!texture.LoadImage(File.ReadAllBytes(Path.Combine(DataRoot,S(asset["file"]))),true))throw new Exception("PNG decode failed "+id);textures[id]=texture;return texture;}
 IEnumerator GuardFxSmoke(IEnumerator body,string output){while(true){Exception error=null;bool advanced=false;object next=null;try{advanced=body.MoveNext();if(advanced)next=body.Current;}catch(Exception e){error=e;}if(error!=null){Directory.CreateDirectory(output);File.WriteAllText(Path.Combine(output,"result.json"),new JObject{{"status","FAIL"},{"exception",error.ToString()}}.ToString());Debug.LogException(error);Application.Quit(1);yield break;}if(!advanced)yield break;yield return next;}}
 IEnumerator FxSmoke(string output){
  Directory.CreateDirectory(output);Playing=false;foreach(var a in actors.Values)a.Root.SetActive(false);foreach(var f in floors.Values)f.SetActive(false);var cases=JObject.Parse(File.ReadAllText(Arg("fx-cases")));var rows=new JArray();var shader=Shader.Find("TOP/SourceAVFX");if(!shader||!shader.isSupported)throw new Exception("Source AVFX shader unsupported");
  foreach(var c in cases["cases"]){string label=S(c["label"]);var pack=JObject.Parse(File.ReadAllText(Path.Combine(DataRoot,"assets",S(c["file"]))));using(var fx=new TopAvfxRenderer(pack,SourceTexture,(uint)c["seed"])){fx.DebugMaterialMode=(int?)c["debug_mode"]??(Arg("fx-debug-solid")=="1"?1:0);fx.RenderOnlyKind=(int?)c["kind"]??-1;fx.TrackBounds=true;fx.Endpoints=()=>((new Vector3(-8,1.5f,0),new Vector3(8,1.5f,0)));if(!fx.Seek(D(c["frame"]),View))throw new Exception("Source graph sample rejected "+label);
    if(fx.HasBounds){var b=fx.RenderBounds;float radius=Mathf.Max(.1f,b.extents.magnitude);View.transform.position=b.center+new Vector3(1,1,1).normalized*radius*3.5f;View.transform.LookAt(b.center);View.farClipPlane=Mathf.Max(1200,radius*10+100);View.nearClipPlane=Mathf.Max(.01f,radius*.001f);}else throw new Exception("No source geometry "+label);
    yield return null;fx.Root.SetActive(false);Capture(Path.Combine(output,label+"-base.png"));fx.Root.SetActive(true);fx.Seek(D(c["frame"]),View);Capture(Path.Combine(output,label+".png"));
    var before=new Texture2D(2,2);before.LoadImage(File.ReadAllBytes(Path.Combine(output,label+"-base.png")));var after=new Texture2D(2,2);after.LoadImage(File.ReadAllBytes(Path.Combine(output,label+".png")));var a=before.GetPixels32();var b2=after.GetPixels32();int changed=0;for(int i=0;i<a.Length;i++)if(Math.Abs(a[i].r-b2[i].r)+Math.Abs(a[i].g-b2[i].g)+Math.Abs(a[i].b-b2[i].b)>16)changed++;Destroy(before);Destroy(after);
    var row=new JObject{{"label",label},{"source",c},{"debug_solid_non_source",fx.DebugSolidMaterial},{"debug_mode",fx.DebugMaterialMode},{"camera_callbacks",fx.CameraCallbacks},{"command_bytes",fx.CommandBytes},{"particles",fx.ParticleCount},{"draws",fx.DrawCount},{"drawnKinds",new JArray(fx.DrawnKinds)},{"changed_pixels",changed},{"diagnostics",new JArray(fx.Diagnostics)}};rows.Add(row);File.WriteAllText(Path.Combine(output,"states.json"),rows.ToString());Debug.Log("TOP_FX_SMOKE "+row.ToString(Newtonsoft.Json.Formatting.None));if(fx.DebugMaterialMode==0&&(fx.DrawCount==0||changed<50))throw new Exception("No visible source pixels "+label);
   }yield return null;
  }
  File.WriteAllText(Path.Combine(output,"result.json"),new JObject{{"status",Arg("fx-debug-probe")=="1"?"DEBUG_CHANNEL_PROBE_COMPLETE_NOT_SOURCE_ACCEPTANCE":"SOURCE_PRIMITIVES_RENDERED_PENDING_PARENT_VISUAL_REVIEW"},{"cases",rows.Count},{"gpu",SystemInfo.graphicsDeviceName},{"original_game_equivalence",false},{"host_lifecycle_complete",false}}.ToString());Application.Quit(0);
 }
}
}
