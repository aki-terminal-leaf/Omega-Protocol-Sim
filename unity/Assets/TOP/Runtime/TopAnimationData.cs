// SPDX-License-Identifier: MIT
// Exact seek sampling of the exported source channels, alongside the maintained
// glTFast MODEL importer. This avoids Unity legacy-curve interpolation drift.
// Quaternion interpolation follows Three.js Quaternion.slerpFlat (MIT).
using System;
using System.Linq;
using System.Collections.Generic;
using System.Text;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Top.UnityReplay {
public sealed class TopAnimationData {
 sealed class Channel {public string Node,Path,Interpolation;public float[] Times,Values;public int Width;}
 readonly Dictionary<string,List<Channel>> clips=new();readonly Dictionary<string,double> durations=new();
 public TopAnimationData(byte[] glb){
  int jsonLength=BitConverter.ToInt32(glb,12),binary=28+jsonLength;var doc=JObject.Parse(Encoding.UTF8.GetString(glb,20,jsonLength));var accessorCache=new Dictionary<int,float[]>();
  float[] Read(int index){if(accessorCache.TryGetValue(index,out var cached))return cached;var a=doc["accessors"][index];if((int)a["componentType"]!=5126||a["sparse"]!=null)throw new Exception("Unsupported source animation accessor");var view=doc["bufferViews"][(int)a["bufferView"]];int width=(string)a["type"] switch{"SCALAR"=>1,"VEC3"=>3,"VEC4"=>4,_=>throw new Exception("Unsupported animation accessor width")};int count=(int)a["count"],offset=binary+((int?)view["byteOffset"]??0)+((int?)a["byteOffset"]??0),stride=(int?)view["byteStride"]??width*4;var result=new float[count*width];for(int i=0;i<count;i++)for(int j=0;j<width;j++)result[i*width+j]=BitConverter.ToSingle(glb,offset+i*stride+j*4);accessorCache[index]=result;return result;}
  foreach(var animation in doc["animations"]??new JArray()){
   string name=(string)animation["name"];var list=new List<Channel>();double duration=0;
   foreach(var channel in animation["channels"]){var sampler=animation["samplers"][(int)channel["sampler"]];string path=(string)channel["target"]["path"];if(path!="translation"&&path!="rotation"&&path!="scale")throw new Exception("Unsupported source animation path "+path);string interpolation=(string)sampler["interpolation"]??"LINEAR";if(interpolation!="LINEAR"&&interpolation!="STEP")throw new Exception("Unsupported source interpolation "+interpolation);
    var times=Read((int)sampler["input"]);for(int i=1;i<times.Length;i++)if(!(times[i]>times[i-1]))throw new Exception("Source animation input is not strict");var values=Read((int)sampler["output"]);int width=path=="rotation"?4:3;if(values.Length!=times.Length*width)throw new Exception("Source animation output length mismatch");
    list.Add(new Channel{Node=(string)doc["nodes"][(int)channel["target"]["node"]]["name"],Path=path,Interpolation=interpolation,Times=times,Values=values,Width=width});duration=Math.Max(duration,times[^1]);
   }clips[name]=list;durations[name]=duration;
  }
 }
 public void AddSupplement(JToken source){
  if(source==null)return;string name=(string)source["name"];var times=source["times"].Select(x=>(float)x).ToArray();for(int i=1;i<times.Length;i++)if(!(times[i]>times[i-1]))throw new Exception("Supplemental animation input is not strict");var list=new List<Channel>();
  foreach(var bone in source["bones"])foreach(var path in new[]{"translation","rotation","scale"}){int width=path=="rotation"?4:3;var values=bone[path].Select(x=>(float)x).ToArray();if(values.Length!=times.Length*width)throw new Exception("Supplement animation output mismatch");list.Add(new Channel{Node=(string)bone["name"],Path=path,Interpolation="LINEAR",Times=times,Values=values,Width=width});}
  clips[name]=list;durations[name]=(double)source["duration"];
 }
 public bool Has(string name)=>clips.ContainsKey(name);
 public double Duration(string name)=>durations.TryGetValue(name,out var duration)?duration:0;
 public void Sample(string name,double seconds,Dictionary<string,Transform> nodes){
  foreach(var c in clips[name]){
   if(!nodes.TryGetValue(c.Node,out var node))throw new Exception("Missing animated source node "+c.Node);
   int lo=0,hi=c.Times.Length;while(lo<hi){int m=(lo+hi)/2;if(c.Times[m]<=seconds)lo=m+1;else hi=m;}int a=Math.Clamp(lo-1,0,c.Times.Length-1),b=Math.Min(a+1,c.Times.Length-1);double t=b==a||c.Interpolation=="STEP"?0:Math.Clamp((seconds-c.Times[a])/(c.Times[b]-c.Times[a]),0,1);int ai=a*c.Width,bi=b*c.Width;
   if(c.Path=="rotation"){var q=Slerp(c.Values,ai,bi,t);node.localRotation=new Quaternion(q.x,-q.y,-q.z,q.w);}
   else{float x=(float)(c.Values[ai]+((double)c.Values[bi]-c.Values[ai])*t),y=(float)(c.Values[ai+1]+((double)c.Values[bi+1]-c.Values[ai+1])*t),z=(float)(c.Values[ai+2]+((double)c.Values[bi+2]-c.Values[ai+2])*t);if(c.Path=="translation")node.localPosition=new Vector3(-x,y,z);else node.localScale=new Vector3(x,y,z);}
  }
 }
 static Quaternion Slerp(float[] v,int a,int b,double t){
  double x=v[a],y=v[a+1],z=v[a+2],w=v[a+3],x1=v[b],y1=v[b+1],z1=v[b+2],w1=v[b+3];if(t==0)return new Quaternion((float)x,(float)y,(float)z,(float)w);if(t==1)return new Quaternion((float)x1,(float)y1,(float)z1,(float)w1);
  if(x!=x1||y!=y1||z!=z1||w!=w1){double s=1-t,cos=x*x1+y*y1+z*z1+w*w1,dir=cos>=0?1:-1,sqrSin=1-cos*cos;if(sqrSin>2.220446049250313e-16){double sin=Math.Sqrt(sqrSin),len=Math.Atan2(sin,cos*dir);s=Math.Sin(s*len)/sin;t=Math.Sin(t*len)/sin;}double td=t*dir;x=x*s+x1*td;y=y*s+y1*td;z=z*s+z1*td;w=w*s+w1*td;if(s==1-t){double f=1/Math.Sqrt(x*x+y*y+z*z+w*w);x*=f;y*=f;z*=f;w*=f;}}
  return new Quaternion((float)x,(float)y,(float)z,(float)w);
 }
}
}
