// SPDX-License-Identifier: MIT
// Original preset skeletons supply invisible attachment proxies, not recorded player appearance/motion.
using System;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Top.UnityReplay {
public sealed partial class TopReplay {
 readonly Dictionary<string,Actor> hiddenTargets=new();
 void InitializeInvisibleTargets(){
  foreach(var row in ((JObject)Record["actors"]).Properties().Where(x=>(bool?)x.Value["player"]==true)){
   var actor=new Actor{Id=row.Name,Root=new GameObject("Invisible target "+row.Name),Binding=new JObject{{"scale",F(Manifest["scales"]?["player"],1)}}};SelectRig(actor,"player");foreach(var renderer in actor.Rig.Renderers)renderer.enabled=false;hiddenTargets.Add(row.Name,actor);
  }
  diagnostics.Add("invisible_target_bones/original_preset_proxy_not_recorded_race_appearance_or_job_motion");
 }
 void EvaluateInvisibleTargets(){
  foreach(var a in hiddenTargets.Values){
   bool exists=Position(a.Id,Clock,out var point,out var heading,out var age,false);a.Root.transform.SetPositionAndRotation(point,DirYaw(heading));a.Root.SetActive(exists&&age<=10000);
   var rig=a.Rig;string name=rig.Clips.Keys.FirstOrDefault(n=>n.EndsWith("cbnm_id0",StringComparison.Ordinal));
   if(name!=null){
    for(int i=0;i<rig.Bones.Length;i++){var bone=rig.Bones[i];var rest=rig.Rest[i];bone.SetParent(rest.Parent,false);bone.localPosition=rest.Position;bone.localRotation=rest.Rotation;bone.localScale=rest.Scale;}
    double period=rig.Source.Has(name)?rig.Source.Duration(name):rig.Clips[name].length;double seconds=period>0?(Clock/1000%period+period)%period:0;
    if(rig.Source.Has(name))rig.Source.Sample(name,seconds,rig.Nodes);else rig.Clips[name].SampleAnimation(rig.SampleRoot,(float)seconds);rig.Clip=name;
   }else diagnostics.Add("invisible_target_idle_clip_missing");
   // No player meshes may become visible when the proxy root is reactivated.
   foreach(var renderer in rig.Renderers)renderer.enabled=false;
  }
 }
 bool AttachmentActor(string id,out Actor actor)=>actors.TryGetValue(id,out actor)||hiddenTargets.TryGetValue(id,out actor);
 int VisiblePlayerCount()=>hiddenTargets.Values.Count(a=>a.Rig.Renderers.Any(r=>r.enabled&&r.gameObject.activeInHierarchy));
 public JObject InvisibleTargetReport(){var rows=new JArray();foreach(var a in hiddenTargets.Values.OrderBy(a=>a.Id)){var p=a.Root.transform.position;var head=a.Rig.Nodes.GetValueOrDefault("j_kao");rows.Add(new JObject{{"id",a.Id},{"active",a.Root.activeInHierarchy},{"position",new JArray(p.x,p.y,p.z)},{"bones",a.Rig.Bones.Length},{"clip",a.Rig.Clip},{"headWorldRH",head?MatrixJson(Mirror(head.localToWorldMatrix)):new JArray()},{"visible_renderers",a.Rig.Renderers.Count(r=>r.enabled&&r.gameObject.activeInHierarchy)}});}return new JObject{{"representation","original preset bone proxy; actual recorded race/appearance/job motion unknown"},{"targets",rows},{"visiblePlayers",VisiblePlayerCount()},{"complete",false}};}
}
}
