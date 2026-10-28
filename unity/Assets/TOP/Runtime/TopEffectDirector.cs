// SPDX-License-Identifier: MIT
// Source-event AVFX director: bounded reconstruction over the native source-preview renderer; not game-host equivalence.
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Top.UnityReplay {
public sealed partial class TopReplay {
 public bool EffectsEnabled=true;
 sealed class DirCue {public string Key,Source,Target,Avfx,Basis,Family;public double Anchor,Start,End;public int TetherId,Ability;public bool Body,Weapon;public JObject Pack;public JToken SourcePos,TargetPos;}
 sealed class DirInstance {public DirCue Cue;public TopAvfxRenderer R;public JObject Pack;public double Frame;}
 static readonly Dictionary<int,string> DirBoneIds=new(){{1,"j_kao"},{25,"n_atama"},{28,"j_sebo_c"},{29,"n_root"},{30,"n_hara"},{31,"j_kosi"},{32,"j_te_r"},{33,"j_te_l"},{42,"n_root"},{71,"n_root"},{77,"n_buki_r"},{78,"n_buki_l"},{107,"n_throw"}};
 readonly Dictionary<string,DirInstance> dirInstances=new();
 readonly Dictionary<string,string> dirSkipped=new();
 readonly Dictionary<string,JObject> dirPacks=new();
 readonly HashSet<string> dirDiagnostics=new();
 List<DirCue> dirCues;GameObject dirRoot;
 static int DirInt(JToken t){if(t is JObject o)t=o["value"];return t==null||t.Type==JTokenType.Null?0:(int)t;}
 static Quaternion DirYaw(float heading)=>Quaternion.Euler(0,-(Mathf.PI/2-heading/100)*Mathf.Rad2Deg,0);
 static bool DirNumber(JToken t)=>t is JValue {Type:JTokenType.Integer or JTokenType.Float}&&double.IsFinite(D(t));
 static uint DirSeed(string key){uint h=2166136261;foreach(char ch in key)h=unchecked((h^(byte)ch)*16777619);return h;}
 static string DirFamily(string form)=>form==null?null:form.StartsWith("female")?"m0514":form.StartsWith("male")?"m0513":null;
 bool DirOwned(string id)=>(bool?)Record["actors"]?[id]?["friendly"]==true||(bool?)Record["actors"]?[id]?["player"]==true;
 DirCue DirFromCue(JToken r)=>new DirCue{Key=S(r["key"]),Source=S(r["source"]),Target=S(r["target"]),Avfx=S(r["path"]),Anchor=D(r["anchor"]),Start=D(r["start"]),End=D(r["end"]),Ability=(int)D(r["ability"]),TetherId=(int)D(r["tetherID"]),Basis=S(r["lifecycle_basis"]),Body=(bool?)r["isBody"]==true,SourcePos=r["source_pos"],TargetPos=r["target_pos"]};
 void BuildDirCues(){
  if(dirCues!=null)return;dirCues=new List<DirCue>();var keys=new HashSet<string>();
  void Add(DirCue c){if(c.Key!=""&&c.Avfx!=""&&keys.Add(c.Key))dirCues.Add(c);}
  try{
   foreach(var row in (Full["cues"] as JArray??new JArray()).Concat(Full["bodyCues"] as JArray??new JArray())){var c=DirFromCue(row);if(c.TetherId!=0||!DirOwned(c.Source))Add(c);}
   foreach(var e in Full["tether_events"] as JArray??new JArray()){
    if(e["end"] is not JValue {Type: JTokenType.Integer or JTokenType.Float} end)continue;
    int id=(int)D(e["tetherID"]);string path=S(Full["channeling"]?[id.ToString()]);if(path==""){dirDiagnostics.Add("tether_path_missing/"+id);continue;}
    Add(new DirCue{Key="record-tether/"+S(e["event_index"]),Source=S(e["s"]),Target=S(e["d"]),Anchor=D(e["t"]),Start=D(e["t"]),End=D(end),Avfx=path,TetherId=id,Basis=S(e["lifetime_status"])});
   }
   DirWeaponCues(c=>{if(!dirCues.Any(x=>!x.Weapon&&x.Source==c.Source&&x.Avfx==c.Avfx&&Math.Abs(x.Start-c.Start)<1))Add(c);});
  }catch(Exception e){dirDiagnostics.Add("cue_build_failed/"+e.GetType().Name+"/"+e.Message);}
  dirCues=dirCues.OrderBy(c=>c.Start).ToList();
 }
 void DirWeaponCues(Action<DirCue> add){
  if(Weapons["actions"] is not JObject actions)return;
  foreach(var cast in Record["events"]){if(S(cast["type"])!="cast")continue;string ability=S(cast["a"]);var action=actions[ability];if(action==null)continue;string src=S(cast["s"]),tmb=S(action["tmb"]);
   foreach(var n in action["nodes"]??new JArray()){
    string path=S(n["path"]);var pack=Weapons["packs"]?[path] as JObject;if(pack==null){dirDiagnostics.Add("weapon_pack_missing/"+path);continue;}double anchor=D(cast["t"]),start=anchor+D(n["time"])/30*1000;
    add(new DirCue{Key=anchor.ToString(System.Globalization.CultureInfo.InvariantCulture)+"|"+src+"|"+ability+"|"+S(n["id"]),Source=src,Target=S(cast["d"],src),Avfx=path,Pack=pack,Ability=(int)D(cast["a"]),Anchor=anchor,Start=start,End=start+6000,Weapon=true,Family=tmb.Contains("m0514")?"m0514":tmb.Contains("m0513")?"m0513":null,SourcePos=cast["source_pos"],Basis="source preview 6s envelope; original host stop OPEN"});
   }
  }
 }
 JObject DirPack(DirCue c){
  if(c.Pack!=null)return c.Pack;string id=S(Full["packs"]?[c.Avfx]);if(id=="")return null;
  if(dirPacks.TryGetValue(id,out var cached))return cached;
  string file=S(Manifest["native_assets"]?[id]?["file"]);if(file=="")return null;
  string path=Path.Combine(DataRoot,file);return dirPacks[id]=File.Exists(path)?JObject.Parse(File.ReadAllText(path)):null;
 }
 bool DirPoint(DirCue c,string key,double t,bool anchor,out Vector3 p,out float heading){
  var raw=key==c.Source?c.SourcePos:key==c.Target?c.TargetPos:null;
  if(anchor&&raw is JArray row&&row.Count>=2&&DirNumber(row[0])&&DirNumber(row[1])){p=new Vector3(-F(row[0]),0,F(row[1]));heading=row.Count>2&&DirNumber(row[2])?F(row[2]):0;return true;}
  if(Position(key,t,out p,out heading,out var age,false)&&age<=10000)return true;return false;
 }
 bool DirPose(DirInstance v,JToken prop,int binderIndex,double frame,out Vector3 pos,out Quaternion rot){
  var c=v.Cue;var d=v.R.Diagnostics;pos=Vector3.zero;rot=Quaternion.identity;
  int type=DirInt(prop["BPTP"]);bool freeze=DirInt(prop["CoUF"])==1;string key=c.Weapon?c.Source:DirInt(prop["BPT"])==1?c.Target:c.Source;
  if(c.Weapon)freeze=type!=3;
  if(type==3&&freeze){d.Add("frozen_bone_pose_unresolved");return false;}
  if(type!=0&&type!=1&&type!=3){d.Add("unsupported_bind_target/"+type);return false;}
  float heading=0;
  if(!(c.Weapon&&type==3)&&!DirPoint(c,key,freeze?c.Anchor:Clock,freeze,out pos,out heading)){d.Add("stale_or_missing_position/"+key);return false;}
  rot=DirYaw(heading);
  if(type==3){
   if(!AttachmentActor(key,out var a)||a.Rig==null){d.Add("attachment_actor_unavailable/"+key);return false;}
   if(hiddenTargets.ContainsKey(key))d.Add("player_bone_proxy/original_preset_not_recorded_motion");
   int id=DirInt(prop["BPID"]);string family=c.Weapon?c.Family:DirFamily(a.Form);JToken row=null;
   if(family!=null&&Weapons["eid"]?[family]?["rows"] is JArray rows)row=rows.FirstOrDefault(x=>DirInt(x["id"])==id);
   string bone=S(row?["bone"]);if(bone==""){DirBoneIds.TryGetValue(id,out bone);d.Add("bone_id_fallback/"+key+"/"+id);}
   if(bone==null||!a.Rig.Nodes.TryGetValue(bone,out var node)){d.Add("missing_attachment_bone/"+key+"/"+id);return false;}
   var m=node.localToWorldMatrix;
   if(row!=null){var r=V(row["rotation_radians"])*Mathf.Rad2Deg;m*=Mirror(Matrix4x4.TRS(V(row["position"]),Quaternion.AngleAxis(r.x,Vector3.right)*Quaternion.AngleAxis(r.y,Vector3.up)*Quaternion.AngleAxis(r.z,Vector3.forward),Vector3.one));}
   pos=m.GetColumn(3);
   if(c.Weapon){var f=(Vector3)m.GetColumn(2);var u=(Vector3)m.GetColumn(1);if(f.sqrMagnitude<1e-10f||u.sqrMagnitude<1e-10f){d.Add("degenerate_bone_orientation/"+bone);return false;}rot=Quaternion.LookRotation(f.normalized,u.normalized);}
  }
  var offset=TopAvfxMath.Axes(prop["Pos"],frame,c.Weapon?1:DirSeed(c.Key),c.Weapon?"binder"+binderIndex:"binder-offset",0);if(!offset.HasValue){d.Add("binder_offset_curve");return false;}var delta=offset.Value;delta.x=-delta.x;pos+=(c.Weapon&&type==3?rot:DirYaw(heading))*delta;
  return true;
 }
 (Vector3,Vector3)? DirEndpoints(DirInstance v,int index,double age){
  var binds=v.Pack["groups"]?["Bind"] as JArray;if(binds==null||index<0||index>=binds.Count)return null;var p=binds[index]?["properties"];if(p?["PrpS"]==null||p["PrpG"]==null)return null;
  if(!DirPose(v,p["PrpS"],index,age,out var start,out _)||!DirPose(v,p["PrpG"],index,age,out var end,out _))return null;var root=v.R.Root.transform;return(root.InverseTransformPoint(start),root.InverseTransformPoint(end));
 }
 DirInstance DirCreate(DirCue c){
  var pack=DirPack(c);if(pack==null){dirSkipped[c.Key]="source pack unavailable";return null;}
  if(!DirPoint(c,c.Source,c.Anchor,true,out var p,out var heading)){dirSkipped[c.Key]="no reliable source position";return null;}
  DirInstance v=null;
  try{
   if(!dirRoot)dirRoot=new GameObject("Source effects");
   v=new DirInstance{Cue=c,Pack=pack};v.R=new TopAvfxRenderer(pack,SourceTexture,DirSeed(c.Key));
   var self=v;v.R.ParticleEndpoints=spec=>DirEndpoints(self,spec.Binder,spec.Age);
   v.R.Root.transform.SetParent(dirRoot.transform,false);v.R.Root.transform.SetPositionAndRotation(p,DirYaw(heading));
   v.R.Diagnostics.Add(c.TetherId!=0?"tether_lifetime/"+c.Basis:c.Body?"body_lifecycle/observed_activity_only":c.Weapon?"weapon_special_6s_source_preview/original_host_stop_open":"C012_host_stop_semantics_unresolved");
   dirInstances.Add(c.Key,v);return v;
  }catch(Exception e){v?.R?.Dispose();dirSkipped[c.Key]="renderer error: "+e.Message;return null;}
 }
 void DirRemove(string key){if(dirInstances.TryGetValue(key,out var v)){v.R.Dispose();dirInstances.Remove(key);}}
 void DisposeInstances(){foreach(var v in dirInstances.Values)v.R.Dispose();dirInstances.Clear();}
 void DisposeEffects(){DisposeInstances();if(dirRoot)Destroy(dirRoot);dirRoot=null;}
 partial void EvaluateEffects(){
  dirSkipped.Clear();
  if(!EffectsEnabled||Full==null){DisposeInstances();return;}
  BuildDirCues();var desired=new Dictionary<string,DirCue>();
  foreach(var c in dirCues){if(c.Start>Clock)break;if(Clock<c.End)desired[c.Key]=c;}
  foreach(var key in dirInstances.Keys.Where(k=>!desired.ContainsKey(k)).ToArray())DirRemove(key);
  foreach(var pair in desired){
   var c=pair.Value;
   if(c.Family!=null&&actors.TryGetValue(c.Source,out var owner)&&owner.Form!=null&&DirFamily(owner.Form)!=c.Family){DirRemove(pair.Key);dirSkipped[pair.Key]="weapon family mismatch";continue;}
   if(!dirInstances.TryGetValue(pair.Key,out var v)){v=DirCreate(c);if(v==null)continue;}
   v.Frame=(Clock-c.Start)*.03;v.R.Root.SetActive(true);
   var binds=v.Pack["groups"]?["Bind"] as JArray;
   for(int i=0;binds!=null&&i<binds.Count;i++){
    var prop=binds[i]?["properties"]?["PrpS"];var tr=v.R.Binder(i);
    if(prop==null){tr.gameObject.SetActive(false);v.R.Diagnostics.Add("missing_binder_properties/"+i);continue;}
    bool ok=DirPose(v,prop,i,v.Frame,out var pos,out var rot);tr.gameObject.SetActive(ok);if(ok)tr.SetPositionAndRotation(pos,rot);
   }
   v.Frame=(Clock-c.Start)*.03;bool sampled;
   try{sampled=v.R.Seek(v.Frame,View);}catch(Exception e){sampled=false;v.R.Diagnostics.Add("seek_exception/"+e.GetType().Name);}
   v.R.Root.SetActive(sampled);if(!sampled)dirSkipped[pair.Key]="runtime sample rejected; diagnostics retained";
  }
 }
 public JObject EffectsReport(){
  var rows=new JArray();
  foreach(var v in dirInstances.Values){var c=v.Cue;var pos=v.R.Root.transform.position;
   rows.Add(new JObject{{"key",c.Key},{"ability",c.Ability},{"path",c.Avfx},{"source",c.Source},{"target",c.Target},{"start",c.Start},{"end",c.End},{"basis",c.Basis},{"particles",v.R.ParticleCount},{"draws",v.R.DrawCount},{"frame",v.Frame},{"position",new JArray(pos.x,pos.y,pos.z)},{"bindings",new JArray(v.R.Binders.OrderBy(x=>x.Key).Select(x=>new JObject{{"index",x.Key},{"active",x.Value.gameObject.activeInHierarchy},{"worldRH",MatrixJson(Mirror(x.Value.localToWorldMatrix))}}))},{"diagnostics",new JArray(v.R.Diagnostics)},{"rendering_complete",false}});}
  return new JObject{{"enabled",EffectsEnabled},{"cueCount",dirCues?.Count??0},{"instances",rows},{"skipped",new JArray(dirSkipped.Select(kv=>new JObject{{"key",kv.Key},{"reason",kv.Value}}))},{"diagnostics",new JArray(dirDiagnostics)},{"complete",false}};
 }
}
}
