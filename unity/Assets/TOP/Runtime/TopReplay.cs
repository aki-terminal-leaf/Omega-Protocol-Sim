// SPDX-License-Identifier: MIT
using System;
using System.IO;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using GLTFast;

namespace Top.UnityReplay {
public sealed partial class TopReplay : MonoBehaviour {
 public static TopReplay Instance;
 public double Clock {get; private set;}
 public bool Ready {get; private set;}
 public bool Playing;
 public float Rate=1;
 public int Phase {get;private set;}
 public Camera View;
 public JObject Record,Manifest,Plan,Scenes,Full,Weapons;
 public string DataRoot,Status="Loading TOP";
 readonly Dictionary<string,GltfImport> imports=new();
 readonly Dictionary<string,TopAnimationData> sourceAnimations=new();
 readonly Dictionary<string,GameObject> templates=new();
 readonly Dictionary<string,Actor> actors=new();
 readonly Dictionary<int,GameObject> floors=new();
 readonly List<string> diagnostics=new();
 readonly Dictionary<string,Texture2D> textures=new();
 GameObject templateRoot;double duration;float orbitYaw=148.1092f,orbitPitch=32.689f,distance=63.1269f;
 Vector3 focus=new(0,2,0);bool shuttingDown;
 sealed class Rig {public GameObject Root,SampleRoot;public Dictionary<string,AnimationClip> Clips;public Transform[] Bones;public Dictionary<string,Transform> Nodes;public TopAnimationData Source;public RestPose[] Rest;public Renderer[] Renderers;public string Clip;}
 sealed class RestPose {public Transform Parent;public Vector3 Position,Scale;public Quaternion Rotation;}
 sealed class Actor {public string Id,Form;public GameObject Root;public JObject Binding,Motion;public readonly Dictionary<string,Rig> Rigs=new();public Rig Rig;public bool Visible;}
 public static string Arg(string key){string prefix="--"+key+"=";return Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith(prefix,StringComparison.Ordinal))?.Substring(prefix.Length);}
 JObject Read(string name)=>JObject.Parse(File.ReadAllText(Path.Combine(DataRoot,name+".json")));
 public static float F(JToken t,float d=0)=>t==null||t.Type==JTokenType.Null?d:(float)t;
 public static double D(JToken t,double d=0)=>t==null||t.Type==JTokenType.Null?d:(double)t;
 public static string S(JToken t,string d="")=>t==null||t.Type==JTokenType.Null?d:(string)t;
 public static Vector3 V(JToken t)=>t==null?Vector3.zero:new(F(t[0]),F(t[1]),F(t[2]));
 public static Matrix4x4 Mirror(Matrix4x4 m){var h=Matrix4x4.Scale(new Vector3(-1,1,1));return h*m*h;}
 static Matrix4x4 Matrix(JToken t){var m=new Matrix4x4();for(int i=0;i<16;i++)m[i]=F(t[i]);return Mirror(m);}
 public static void SetMatrix(Transform tr,Matrix4x4 m){tr.localPosition=m.GetColumn(3);tr.localRotation=m.rotation;tr.localScale=m.lossyScale;}
 async void Start(){
  Instance=this;Application.runInBackground=true;QualitySettings.vSyncCount=0;Application.targetFrameRate=60;
  DataRoot=Arg("top-data")??Path.GetFullPath(Path.Combine(Application.dataPath,"../TOPData"));
  try {
   Record=Read("record");Manifest=Read("manifest");Plan=Read("motion-plan");Scenes=Read("scene-data");Full=Read("full-data");Weapons=Read("weapon-data");duration=D(Record["duration_ms"]);
   CreateCamera();templateRoot=new GameObject("Private templates");templateRoot.SetActive(false);
   var needed=new HashSet<string>();foreach(var p in (JObject)Plan["actors"])needed.Add(S(p.Value["form"]));
   foreach(var p in (JObject)Scenes["phases"])foreach(var key in new[]{"nodes","floor_nodes"})foreach(var n in p.Value[key]??new JArray())needed.Add(S(n["asset"]));
   foreach(string id in needed){Status="Loading "+id;await LoadModel(id);}
   foreach(var phase in (JObject)Scenes["phases"])CreateFloor(int.Parse(phase.Key),(JObject)phase.Value);
   foreach(var p in (JObject)Plan["actors"]){if((bool?)Record["actors"]?[p.Key]?["player"]==true)continue;var root=new GameObject("Actor "+p.Key);var a=new Actor{Id=p.Key,Root=root,Binding=(JObject)p.Value};actors.Add(p.Key,a);}
   EffectsEnabled=Arg("fx-smoke")==null;Ready=true;Status="";Seek(0);Debug.Log("TOP_READY "+actors.Count+" actors / "+floors.Count+" phases");
   if(Arg("qa")!=null)StartCoroutine(Qa(Arg("qa")));
   if(Arg("scene-qa")!=null)StartCoroutine(GuardFxSmoke(SceneQa(Arg("scene-qa")),Arg("scene-qa")));
   if(Arg("audio-qa")!=null)StartCoroutine(GuardFxSmoke(AudioQa(Arg("audio-qa")),Arg("audio-qa")));
   if(Arg("fx-qa")!=null)StartCoroutine(GuardFxSmoke(FxQa(Arg("fx-qa")),Arg("fx-qa")));
   if(Arg("fx-smoke")!=null)StartCoroutine(GuardFxSmoke(FxSmoke(Arg("fx-smoke")),Arg("fx-smoke")));
  }catch(Exception e){Status=e.ToString();Debug.LogError("TOP_FATAL "+e);if((Arg("qa")??Arg("fx-qa")??Arg("fx-smoke")??Arg("audio-qa")??Arg("scene-qa"))!=null)Application.Quit(1);}
 }
 async Task LoadModel(string id){
  if(templates.ContainsKey(id))return;var spec=Manifest["native_assets"]?[id];if(S(spec?["kind"])!="glb")throw new Exception("Missing model "+id);
  var gltf=new GltfImport();string path=Path.Combine(DataRoot,S(spec["file"]));
  var bytes=File.ReadAllBytes(path);var source=new TopAnimationData(bytes);if(id=="female"||id=="female_p5")source.AddSupplement(Weapons["legClip"]);sourceAnimations.Add(id,source);
  if(!await gltf.LoadGltfBinary(bytes,new Uri(path),new ImportSettings{AnimationMethod=AnimationMethod.Legacy}))throw new Exception("glTF import failed: "+id);
  var holder=new GameObject(id);holder.transform.SetParent(templateRoot.transform,false);
  if(!await gltf.InstantiateMainSceneAsync(holder.transform))throw new Exception("glTF instantiation failed: "+id);
  foreach(var anim in holder.GetComponentsInChildren<Animation>(true)){anim.Stop();anim.playAutomatically=false;anim.enabled=false;}
  foreach(var renderer in holder.GetComponentsInChildren<SkinnedMeshRenderer>(true))renderer.updateWhenOffscreen=true;
  templates.Add(id,holder);imports.Add(id,gltf);ApplyBackground(id,holder);
 }
 void ApplyBackground(string id,GameObject root){
  if(!id.StartsWith("scene_"))return;
  var path=Path.Combine(DataRoot,S(Manifest["native_assets"][id]["file"]));var bytes=File.ReadAllBytes(path);int n=BitConverter.ToInt32(bytes,12);var glb=JObject.Parse(System.Text.Encoding.UTF8.GetString(bytes,20,n));
  var mats=(JArray)glb["materials"];var unsupported=new HashSet<Material>();
  for(int i=0;i<mats.Count;i++){
   var extra=mats[i]["extras"];string shader=S(extra?["original_shader"]);var material=imports[id].GetMaterial(i);if(!material)continue;
   if(shader.Contains("lightshaft")||shader.Contains("verticalfog")){unsupported.Add(material);diagnostics.Add(id+"/unsupported_volumetric_shader");continue;}
   if(!new[]{"bg.shpk","bguvscroll.shpk","bgcolorchange.shpk","bgcrestchange.shpk"}.Contains(shader))continue;
   var c=extra?["original_shader_constants"]?["0x38a64362"];if(c is not JArray colors||colors.Count<3)continue;
   material.SetColor("emissiveFactor",new Color(Mathf.Max(0,F(c[0])),Mathf.Max(0,F(c[1])),Mathf.Max(0,F(c[2])),1));
   material.SetTexture("emissiveTexture",material.GetTexture("baseColorTexture"));material.EnableKeyword("_EMISSION");
   if(shader!="bg.shpk")diagnostics.Add(id+"/static_only_"+shader);
  }
  foreach(var renderer in root.GetComponentsInChildren<Renderer>(true))if(renderer.sharedMaterials.Any(m=>unsupported.Contains(m)))renderer.enabled=false;
 }
 void CreateFloor(int id,JObject phase){var g=new GameObject("Source scene P"+id);floors.Add(id,g);var nodes=((JArray)phase["nodes"]).Concat(phase["floor_nodes"]??new JArray());
  foreach(var n in nodes){string asset=S(n["asset"]);if(!templates.TryGetValue(asset,out var template))throw new Exception("Missing scene "+asset);var instance=Instantiate(template,g.transform);instance.name=S(n["key"]);SetSceneMatrix(instance,Matrix(n["worldMatrix"]));bool visible=!(id==2&&S(n["source"]?["rootLayer"])=="p1_boss");instance.SetActive(visible);if(!visible)diagnostics.Add("P2_replaces_P1_floor_layer/"+instance.name);}g.SetActive(false);
 }
 void SetSceneMatrix(GameObject instance,Matrix4x4 matrix){
  SetMatrix(instance.transform,matrix);var x=(Vector3)matrix.GetColumn(0);var y=(Vector3)matrix.GetColumn(1);var z=(Vector3)matrix.GetColumn(2);
  bool shear=Mathf.Abs(Vector3.Dot(x.normalized,y.normalized))>1e-5f||Mathf.Abs(Vector3.Dot(x.normalized,z.normalized))>1e-5f||Mathf.Abs(Vector3.Dot(y.normalized,z.normalized))>1e-5f;
  if(!shear)return;
  foreach(var filter in instance.GetComponentsInChildren<MeshFilter>(true)){
   var local=instance.transform.worldToLocalMatrix*filter.transform.localToWorldMatrix;var correction=filter.transform.worldToLocalMatrix*matrix*local;
   var mesh=filter.mesh;var vertices=mesh.vertices;for(int i=0;i<vertices.Length;i++)vertices[i]=correction.MultiplyPoint3x4(vertices[i]);mesh.vertices=vertices;
   var normals=mesh.normals;var normalMatrix=correction.inverse.transpose;for(int i=0;i<normals.Length;i++)normals[i]=normalMatrix.MultiplyVector(normals[i]).normalized;mesh.normals=normals;
   var tangents=mesh.tangents;for(int i=0;i<tangents.Length;i++){var value=correction.MultiplyVector((Vector3)tangents[i]).normalized;tangents[i]=new Vector4(value.x,value.y,value.z,tangents[i].w*Mathf.Sign(correction.determinant));}mesh.tangents=tangents;mesh.RecalculateBounds();
  }
  diagnostics.Add("exact_static_shear_bake/"+instance.name);
 }
 void SelectRig(Actor a,string form){
  if(a.Form==form)return;if(a.Rig!=null)a.Rig.Root.SetActive(false);
  if(!a.Rigs.TryGetValue(form,out var rig)){
   if(!templates.TryGetValue(form,out var template))throw new Exception("Missing form "+form);
   var root=Instantiate(template,a.Root.transform);root.name=form;root.transform.localScale=Vector3.one*F(a.Binding["scale"],1);root.SetActive(true);
   var animation=root.GetComponentInChildren<Animation>(true);var sampleRoot=animation?animation.gameObject:root;
   var clips=(imports[form].GetAnimationClips()??Array.Empty<AnimationClip>()).ToDictionary(x=>x.name,x=>x);
   if(form=="female"||form=="female_p5")AddLegClip(root,sampleRoot,clips);
   var boneSet=new HashSet<Transform>(root.GetComponentsInChildren<SkinnedMeshRenderer>(true).SelectMany(x=>x.bones));
   rig=new Rig{Root=root,SampleRoot=sampleRoot,Clips=clips,Bones=boneSet.OrderBy(Depth).ToArray(),Renderers=root.GetComponentsInChildren<Renderer>(true)};rig.Source=sourceAnimations[form];rig.Nodes=root.GetComponentsInChildren<Transform>(true).GroupBy(t=>t.name).ToDictionary(g=>g.Key,g=>g.First());rig.Rest=rig.Bones.Select(b=>new RestPose{Parent=b.parent,Position=b.localPosition,Rotation=b.localRotation,Scale=b.localScale}).ToArray();a.Rigs.Add(form,rig);
  }a.Form=form;a.Rig=rig;rig.Root.SetActive(true);
 }
 void AddLegClip(GameObject root,GameObject sampleRoot,Dictionary<string,AnimationClip> clips){var source=Weapons["legClip"];if(source!=null)clips[S(source["name"])]=new AnimationClip{legacy=true,name=S(source["name"]),frameRate=30};}
 static int Depth(Transform t){int d=0;while(t.parent){d++;t=t.parent;}return d;}
 public double NormalizeTime(double t){t=Math.Clamp(t,0,duration);foreach(var c in Full["cutscene_skips"])if(D(c["start"])<=t&&t<D(c["end"]))return D(c["end"]);return t;}
 public void Seek(double t){if(!Ready)return;Clock=NormalizeTime(t);Evaluate();}
 int PhaseAt(double t){int p=1;foreach(var row in Record["phase_markers"])if(D(row["t"])<=t)p=(int)row["id"];return p;}
 public bool Position(string id,double t,out Vector3 p,out float heading,out float age,bool smooth=true){
  p=Vector3.zero;heading=0;age=0;var tr=Record["tracks"]?[id] as JArray;if(tr==null||tr.Count==0)return false;
  int lo=0,hi=tr.Count;while(lo<hi){int m=(lo+hi)/2;if(D(tr[m][0])<=t)lo=m+1;else hi=m;}int i=lo-1;if(i<0)return false;var a=tr[i];double rawAge=t-D(a[0]);float x=F(a[1]),z=F(a[2]);heading=F(a[3]);age=(float)rawAge;
  if(smooth&&i+1<tr.Count){var b=tr[i+1];double dt=D(b[0])-D(a[0]);float dx=F(b[1])-x,dz=F(b[2])-z;if(dt>0&&dt<=1500&&Math.Sqrt(dx*dx+dz*dz)<=12*dt/1000){float f=(float)(rawAge/dt);x+=dx*f;z+=dz*f;}}
  p=new Vector3(-x,0,z);return true;
 }
 void Evaluate(){
  int p=PhaseAt(Clock);if(p!=Phase){foreach(var floor in floors)floor.Value.SetActive(floor.Key==p);Phase=p;}
  foreach(var a in actors.Values){
   var motions=(JArray)a.Binding["motions"];var m=motions.LastOrDefault(x=>D(x["start"])<=Clock);if(m==null)continue;a.Motion=(JObject)m;SelectRig(a,S(m["form"]));
   bool exists=Position(a.Id,Clock,out var position,out var heading,out var age);bool visible=exists&&age<=10000&&(((JArray)a.Binding["windows"]).Any(w=>D(w[0])<=Clock&&Clock<=D(w[1])+800)||(bool?)m["activeAction"]==true);
   if(a.Form=="optical"){
    var cast=((JArray)a.Binding["opticalCasts"]).FirstOrDefault(c=>D(c["start"])<=Clock&&Clock<D(c["end"]));visible=cast!=null;
    var sample=cast==null?null:Record["tracks"]?[a.Id]?.FirstOrDefault(x=>D(x[0])>=D(cast["start"])&&D(x[0])<=D(cast["castEnd"])+100);
    if(sample==null)visible=false;else{position=new Vector3(-F(sample[1]),0,F(sample[2]));heading=0;}a.Root.transform.localPosition=Vector3.zero;a.Root.transform.localRotation=Quaternion.Euler(0,-Mathf.Atan2(position.x,-position.z)*Mathf.Rad2Deg,0);
   }else{a.Root.transform.localPosition=position;a.Root.transform.localRotation=Quaternion.Euler(0,-(Mathf.PI/2-heading/100)*Mathf.Rad2Deg,0);}
   a.Visible=visible;a.Root.SetActive(visible);if(!exists)continue;
   string clip=S(m["clip"]);if(!a.Rig.Clips.TryGetValue(clip,out var anim)){clip=a.Rig.Clips.Keys.FirstOrDefault(k=>k.EndsWith("cbbm_id0"));if(clip==null)continue;anim=a.Rig.Clips[clip];}
   double clipDuration=a.Rig.Source.Has(clip)?a.Rig.Source.Duration(clip):anim.length;double loopPeriod=D(m["period"]);if(loopPeriod<=0)loopPeriod=clipDuration;
   double seconds=(Clock-D(m["anchor"]))/1000*D(m["rate"],1)+D(m["offset"]);double sampleTime=(bool?)m["once"]==true?Math.Clamp(seconds,0,Math.Max(0,clipDuration-.0001)):((seconds%loopPeriod+loopPeriod)%loopPeriod);
   // Restore bind hierarchy and untouched channels before every absolute sample.
   // This also makes reverse seeks independent of the previous clip.
   for(int i=0;i<a.Rig.Bones.Length;i++){var b=a.Rig.Bones[i];var rest=a.Rig.Rest[i];b.SetParent(rest.Parent,false);b.localPosition=rest.Position;b.localRotation=rest.Rotation;b.localScale=rest.Scale;}
   if(a.Rig.Source.Has(clip))a.Rig.Source.Sample(clip,sampleTime,a.Rig.Nodes);else anim.SampleAnimation(a.Rig.SampleRoot,(float)sampleTime);a.Rig.Clip=clip;
   if(clip.StartsWith("action_")){
    // Native original PAP action tracks contain model-space joint matrices, unlike resident clips.
    // Independent model-space joints must not inherit zero-scaled hidden tails.
    // Preserve the sampled TRS, then flatten only for this rendered action pose.
    var positions=a.Rig.Bones.Select(b=>b.localPosition).ToArray();var rotations=a.Rig.Bones.Select(b=>b.localRotation).ToArray();var scales=a.Rig.Bones.Select(b=>b.localScale).ToArray();
    for(int i=0;i<a.Rig.Bones.Length;i++){var b=a.Rig.Bones[i];b.SetParent(a.Rig.Root.transform,false);b.localPosition=positions[i];b.localRotation=rotations[i];b.localScale=scales[i];}
   }
   string stance=S(m["stance"]);foreach(var renderer in a.Rig.Renderers){string n=renderer.name;if(n.Contains("atr_parts_a"))renderer.enabled=stance==(a.Form.StartsWith("male")?"SHIELD":"LEGS");else if(n.Contains("atr_parts_b"))renderer.enabled=a.Form.StartsWith("female")?stance!="LEGS":stance!="NEUTRAL"&&stance!="SHIELD";else if(n.Contains("atr_bv_c"))renderer.enabled=stance!="LEGS";}
  }
  EvaluateEffects();
 }
 partial void EvaluateEffects();
 void CreateCamera(){
  var go=new GameObject("Replay camera");View=go.AddComponent<Camera>();View.tag="MainCamera";go.AddComponent<AudioListener>();View.fieldOfView=43;View.nearClipPlane=.1f;View.farClipPlane=1200;View.backgroundColor=new Color(.035f,.06f,.11f);View.clearFlags=CameraClearFlags.SolidColor;View.allowHDR=true;
  RenderSettings.ambientMode=AmbientMode.Trilight;RenderSettings.ambientSkyColor=new Color(.65f,.74f,.9f);RenderSettings.ambientEquatorColor=new Color(.35f,.4f,.5f);RenderSettings.ambientGroundColor=new Color(.15f,.2f,.3f);
  var key=new GameObject("Scene light").AddComponent<Light>();key.type=LightType.Directional;key.intensity=1.5f;key.color=new Color(1,.95f,.87f);key.transform.rotation=Quaternion.Euler(50,-30,0);UpdateCamera();
 }
 void UpdateCamera(){if(!View)return;var q=Quaternion.Euler(orbitPitch,orbitYaw,0);View.transform.position=focus+q*new Vector3(0,0,-distance);View.transform.LookAt(focus);}
 void Update(){if(!Ready)return;if(Playing){Seek(Clock+Time.unscaledDeltaTime*1000*Rate);if(Clock>=duration)Playing=false;}SyncAudio();if(Arg("qa")!=null||Arg("fx-smoke")!=null||Arg("fx-qa")!=null||Arg("audio-qa")!=null||Arg("scene-qa")!=null)return;
  if(Input.GetKeyDown(KeyCode.Space))Playing=!Playing;if(Input.GetKeyDown(KeyCode.LeftArrow))Seek(Clock-5000);if(Input.GetKeyDown(KeyCode.RightArrow))Seek(Clock+5000);
  if(Input.GetMouseButton(1)){orbitYaw+=Input.GetAxis("Mouse X")*3;orbitPitch=Mathf.Clamp(orbitPitch-Input.GetAxis("Mouse Y")*3,5,85);UpdateCamera();}
  float scroll=Input.mouseScrollDelta.y;if(scroll!=0){distance=Mathf.Clamp(distance-scroll*4,12,250);UpdateCamera();}
 }
 void OnGUI(){if(!Ready){GUI.Label(new Rect(20,20,Screen.width-40,200),Status);return;}GUILayout.BeginArea(new Rect(16,Screen.height-95,Screen.width-32,85),GUI.skin.box);GUILayout.BeginHorizontal();if(GUILayout.Button(Playing?"Pause":"Play",GUILayout.Width(70)))Playing=!Playing;
  foreach(int p in Enumerable.Range(1,6))if(GUILayout.Button("P"+p,GUILayout.Width(40)))Seek(D(Record["phase_markers"][p-1]["t"]));
  bool effects=GUILayout.Toggle(EffectsEnabled,"Effects",GUILayout.Width(70));if(effects!=EffectsEnabled){EffectsEnabled=effects;EvaluateEffects();}
  bool audio=GUILayout.Toggle(AudioEnabled,"Sound",GUILayout.Width(65));if(audio!=AudioEnabled){AudioEnabled=audio;SyncAudio();}bool mute=GUILayout.Toggle(AudioMuted,"Mute",GUILayout.Width(55));if(mute!=AudioMuted){AudioMuted=mute;SyncAudio();}
  GUILayout.Label("P"+Phase+"  "+TimeSpan.FromMilliseconds(Clock).ToString(@"mm\:ss\.fff"));foreach(float speed in new[]{.5f,1,2,8})if(GUILayout.Button(speed+"x",GUILayout.Width(40)))Rate=speed;GUILayout.EndHorizontal();float t=GUILayout.HorizontalSlider((float)Clock,0,(float)duration);if(Math.Abs(t-Clock)>1)Seek(t);GUILayout.Label("Right mouse: orbit | Wheel: zoom | Space: pause | Arrows: +/-5s");GUILayout.EndArea();}
 static JArray MatrixJson(Matrix4x4 matrix){var a=new JArray();for(int i=0;i<16;i++)a.Add(matrix[i]);return a;}
 public JObject Snapshot(){var rows=new JArray();foreach(var a in actors.Values)if(a.Visible)rows.Add(new JObject{{"id",a.Id},{"form",a.Form},{"clip",a.Rig.Clip},{"position",new JArray(a.Root.transform.position.x,a.Root.transform.position.y,a.Root.transform.position.z)},{"bones",a.Rig.Bones.Length},{"firstBoneWorldRH",a.Rig.Bones.Length>0?MatrixJson(Mirror(a.Rig.Bones[0].localToWorldMatrix)):new JArray()}});
  return new JObject{{"time",Clock},{"phase",Phase},{"actors",rows},{"visiblePlayers",0},{"invisibleTargetTracks",Record["actors"].Children<JProperty>().Count(x=>(bool?)x.Value["player"]==true)},{"sceneObjects",floors[Phase].transform.childCount},{"activeSceneObjects",floors[Phase].transform.Cast<Transform>().Count(x=>x.gameObject.activeSelf)},{"diagnostics",new JArray(diagnostics)},{"complete",false}};}
 IEnumerator Qa(string output){
  Directory.CreateDirectory(output);var rows=new JArray();double[] times=Arg("qa-mode")=="closeups"?new double[]{208000,650727,673000,884000}:new double[]{26500,80000,140000,158000,200000,208000,210000,226603,226653,260000,270000,315900,477000,560000,650727,670500,673000,725900,884000,1039000,1068500,1109404,200000,26500};
  foreach(double t in times){Seek(t);yield return null;yield return new WaitForEndOfFrame();var s=Snapshot();rows.Add(s);Capture(Path.Combine(output,"frame-"+rows.Count+"-"+((int)t)+".png"));if(new double[]{208000,650727,673000,884000}.Contains(t)){
   foreach(var a in actors.Values.Where(a=>a.Visible&&a.Rig.Bones.Length>0)){
    var pose=new JObject();foreach(var bone in a.Rig.Bones)pose[bone.name]=MatrixJson(Mirror(bone.localToWorldMatrix));
    File.WriteAllText(Path.Combine(output,"pose-"+(int)t+"-"+a.Id.Replace(":","_")+".json"),pose.ToString());
    var priorFocus=focus;var priorDistance=distance;focus=(a.Rig.Bones.FirstOrDefault(b=>b.name=="j_sebo_c")?.position??a.Root.transform.position+new Vector3(0,2,0));distance=18;UpdateCamera();Capture(Path.Combine(output,"close-"+(int)t+"-"+a.Id.Replace(":","_")+".png"));focus=priorFocus;distance=priorDistance;UpdateCamera();
   }
  }File.WriteAllText(Path.Combine(output,"states.json"),rows.ToString());Debug.Log("TOP_QA "+s.ToString(Newtonsoft.Json.Formatting.None));}
  if(Arg("qa-mode")!="closeups"){
  Playing=false;Seek(315900);double pauseClock=Clock;yield return null;yield return null;if(Clock!=pauseClock)throw new Exception("Pause clock advanced");
  Seek(0);Rate=64;Playing=true;var seen=new HashSet<int>();var continuous=new JArray();float began=Time.realtimeSinceStartup;
  while(Clock<duration&&Time.realtimeSinceStartup-began<40){yield return null;foreach(var cut in Full["cutscene_skips"])if(D(cut["start"])<=Clock&&Clock<D(cut["end"]))throw new Exception("Forced cinematic was not excluded");if(seen.Add(Phase)){continuous.Add(Snapshot());Capture(Path.Combine(output,"continuous-P"+Phase+".png"));}}
  if(Clock<duration||seen.Count!=6||Playing)throw new Exception("Continuous all-phase playback failed");File.WriteAllText(Path.Combine(output,"continuous.json"),continuous.ToString());Capture(Path.Combine(output,"continuous-end.png"));
  }
  File.WriteAllText(Path.Combine(output,"result.json"),new JObject{{"status","CAPTURED_NOT_VISUALLY_ACCEPTED"},{"unity",Application.unityVersion},{"gpu",SystemInfo.graphicsDeviceName},{"frames",rows.Count},{"complete",false}}.ToString());Application.Quit(0);
 }
 void Capture(string path){var rt=RenderTexture.GetTemporary(1280,800,24,RenderTextureFormat.ARGB32);var prior=View.targetTexture;var active=RenderTexture.active;try{View.targetTexture=rt;View.Render();RenderTexture.active=rt;var tex=new Texture2D(1280,800,TextureFormat.RGB24,false);tex.ReadPixels(new Rect(0,0,1280,800),0,0);tex.Apply();File.WriteAllBytes(path,tex.EncodeToPNG());Destroy(tex);}finally{View.targetTexture=prior;RenderTexture.active=active;RenderTexture.ReleaseTemporary(rt);}}
 void OnDestroy(){shuttingDown=true;DisposeAudio();DisposeEffects();foreach(var import in imports.Values)import.Dispose();foreach(var texture in textures.Values)Destroy(texture);}
}
}
