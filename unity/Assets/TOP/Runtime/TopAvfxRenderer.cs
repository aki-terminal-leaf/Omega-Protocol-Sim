// SPDX-License-Identifier: MIT
// Source-preview subset. This is not original game shader/host certification.
using System;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;
namespace Top.UnityReplay {
public sealed class TopAvfxRenderer : IDisposable {
 public readonly GameObject Root=new("Source AVFX");
 public readonly Dictionary<int,Transform> Binders=new();
 public HashSet<string> Diagnostics=>graph.Diagnostics;
 public int ParticleCount=>particles.Count;public int DrawCount{get;private set;}
 public Func<(Vector3 Start,Vector3 End)?> Endpoints;
 public int RenderOnlyKind=-1;public int DebugMaterialMode;public bool DebugSolidMaterial=>DebugMaterialMode!=0;public int CameraCallbacks{get;private set;}public int CommandBytes=>commands?.sizeInBytes??0;public bool TrackBounds;public Bounds RenderBounds{get;private set;}public bool HasBounds{get;private set;}public readonly HashSet<int> DrawnKinds=new();
 readonly TopAvfxGraph graph;readonly JObject pack;readonly uint seed;readonly Func<string,Texture2D> textureResolver;
 readonly Dictionary<string,Mesh> meshes=new();readonly Dictionary<string,Draw> draws=new();readonly Dictionary<int,Definition> definitions=new();readonly List<Texture2D> ownedTextures=new();
 List<TopAvfxGraph.Particle> particles=new();Camera camera;CommandBuffer commands;bool disposed;
 sealed class Draw {public Mesh Mesh;public bool Owns;public readonly MaterialPropertyBlock Block=new();}
 sealed class Layer {public Texture2D Texture;public JToken Data,UV;public JObject Scale,Scroll;}
 sealed class Definition {public Material Material;public Layer[] Layers;}
 public TopAvfxRenderer(JObject pack,Func<string,Texture2D> textureResolver,uint seed){this.pack=pack;this.seed=seed;this.textureResolver=textureResolver;graph=new TopAvfxGraph(pack,seed);Camera.onPreCull+=BeforeCamera;}
 static int I(JToken t,int d=0){if(t is JObject o)t=o["value"];return t==null||t.Type==JTokenType.Null?d:(int)t;}
 static float N(JToken t,float d=0){if(t is JObject o)t=o["value"];return t==null||t.Type==JTokenType.Null?d:t.Type==JTokenType.Boolean?((bool)t?1:0):TopReplay.F(t,d);}
 static bool B(JToken t){if(t is JObject o)t=o["value"];return t!=null&&t.Type!=JTokenType.Null&&(t.Type==JTokenType.Boolean?(bool)t:N(t)==1);}
 static Vector3 V(JToken t)=>TopReplay.V(t);
 static Color Multiply(Color a,Color b)=>new(a.r*b.r,a.g*b.g,a.b*b.b,a.a*b.a);
 public Transform Binder(int index){if(!Binders.TryGetValue(index,out var tr)){tr=new GameObject("Source binder "+index).transform;tr.SetParent(Root.transform,false);Binders.Add(index,tr);}return tr;}
 public bool Seek(double nativeFrame,Camera target){if(disposed)return false;particles=graph.Sample(nativeFrame);if(camera!=target){if(camera&&commands!=null)camera.RemoveCommandBuffer(CameraEvent.BeforeForwardAlpha,commands);commands?.Dispose();camera=target;commands=new CommandBuffer{name="TOP source AVFX"};camera.AddCommandBuffer(CameraEvent.BeforeForwardAlpha,commands);}BeforeCamera(camera);return !Diagnostics.Contains("invalid_frame")&&!Diagnostics.Contains("budget_exceeded");}
 void BeforeCamera(Camera target){
  if(disposed||target!=camera||commands==null)return;CameraCallbacks++;commands.Clear();DrawCount=0;HasBounds=false;DrawnKinds.Clear();if(!Root.activeInHierarchy)return;var alive=new HashSet<string>();
  foreach(var p in particles){if(RenderOnlyKind>=0&&p.Kind!=RenderOnlyKind)continue;var node=pack["groups"]?["Ptcl"]?[p.Index];if(node==null)continue;var definition=MaterialDefinition(p.Index,node);if(definition==null)continue;
   var parent=p.Binder>=0?Binder(p.Binder):Root.transform;if(!parent.gameObject.activeInHierarchy)continue;
   if(!draws.TryGetValue(p.Key,out var draw)){draw=new Draw();draws.Add(p.Key,draw);}Mesh mesh;
   if(p.Kind==12){mesh=Disc(p,node,draw);}else if(p.Kind==6){mesh=Ribbon(p,node,draw,target);}else mesh=StaticGeometry(p,node);
   if(!mesh)continue;alive.Add(p.Key);draw.Mesh=mesh;draw.Owns=p.Kind==12||p.Kind==6;
   Color tint=p.Kind==6?Color.white:p.Color;if(!AnimateMaterial(draw.Block,definition,p,tint))continue;
   Matrix4x4 world=p.Kind==6?Root.transform.localToWorldMatrix:parent.localToWorldMatrix*TopReplay.Mirror(p.TransformRH);
   if(Enumerable.Range(0,16).Any(i=>!float.IsFinite(world[i]))){Diagnostics.Add("non_finite_render_transform");continue;}
   int direction=I(node["values"]?["RBDT"],10);if(direction!=10)Diagnostics.Add("direction_base_not_reproduced/"+direction);
   commands.DrawMesh(mesh,world,definition.Material,0,0,draw.Block);DrawCount++;DrawnKinds.Add(p.Kind);
   if(TrackBounds){var bounds=mesh.bounds;for(int ix=0;ix<2;ix++)for(int iy=0;iy<2;iy++)for(int iz=0;iz<2;iz++){var point=world.MultiplyPoint3x4(bounds.center+Vector3.Scale(bounds.extents,new Vector3(ix==0?-1:1,iy==0?-1:1,iz==0?-1:1)));if(!HasBounds){RenderBounds=new Bounds(point,Vector3.zero);HasBounds=true;}else{var total=RenderBounds;total.Encapsulate(point);RenderBounds=total;}}}
  }
  foreach(var key in draws.Keys.Where(k=>!alive.Contains(k)).ToArray()){var draw=draws[key];if(draw.Owns&&draw.Mesh)UnityEngine.Object.Destroy(draw.Mesh);draws.Remove(key);}
 }
 Mesh StaticGeometry(TopAvfxGraph.Particle p,JToken node){
  int model=-1;if(p.Kind==5)model=node["data"]?["MdNo"] is JArray modelList&&modelList.Count>0?I(modelList[0],-1):-1;else if(p.Kind==13)model=I(node["data"]?["MNO"],-1);
  string key=model>=0?"model/"+model:"kind/"+p.Kind;if(meshes.TryGetValue(key,out var prior))return prior;Mesh mesh=null;
  if(model>=0&&pack["models"] is JArray models&&model<models.Count){var source=models[model];var vs=source["vertices"] as JArray;var triangles=source["triangles"] as JArray;if(vs==null||vs.Count==0||triangles==null||triangles.Count==0){Diagnostics.Add("empty_model/"+model);return null;}
   var positions=vs.Select(v=>{var a=V(v["position"]);a.x=-a.x;return a;}).ToArray();var colors=vs.Select(v=>v["color"] is JArray c?new Color(N(c[0])/255,N(c[1])/255,N(c[2])/255,N(c[3])/255):Color.white).ToArray();var indices=triangles.SelectMany(t=>t.Select(x=>(int)x)).ToArray();if(indices.Any(i=>i<0||i>=positions.Length)){Diagnostics.Add("invalid_model_index/"+model);return null;}
   for(int i=0;i<indices.Length;i+=3)(indices[i+1],indices[i+2])=(indices[i+2],indices[i+1]);mesh=NewMesh(positions,colors,indices);
   for(int uv=0;uv<4;uv++){int set=uv;mesh.SetUVs(set,vs.Select(v=>{var u=v["uv"]?[set]??v["uv"]?[0];return u==null?Vector2.zero:new Vector2(N(u[0]),N(u[1]));}).ToList());}
  }else if(p.Kind==1||p.Kind==2||p.Kind==8||p.Kind==10){var positions=p.Kind==10?new[]{new Vector3(.5f,0,-.5f),new Vector3(-.5f,0,-.5f),new Vector3(-.5f,0,.5f),new Vector3(.5f,0,.5f)}:new[]{new Vector3(.5f,-.5f,0),new Vector3(-.5f,-.5f,0),new Vector3(-.5f,.5f,0),new Vector3(.5f,.5f,0)};mesh=NewMesh(positions,Enumerable.Repeat(Color.white,4).ToArray(),p.Kind==10?new[]{0,1,3,3,1,2}:new[]{0,2,1,0,3,2});var uv=new[]{new Vector2(0,1),new Vector2(1,1),new Vector2(1,0),new Vector2(0,0)};for(int i=0;i<4;i++)mesh.SetUVs(i,uv.ToList());if(p.Kind==10)Diagnostics.Add("flat_arena_decal_projection");}
  else Diagnostics.Add("model_selection/"+p.Kind);
  meshes[key]=mesh;return mesh;
 }
 static Mesh NewMesh(Vector3[] vertices,Color[] colors,int[] indices){var mesh=new Mesh{indexFormat=vertices.Length>65535?IndexFormat.UInt32:IndexFormat.UInt16};mesh.vertices=vertices;mesh.colors=colors;mesh.triangles=indices;mesh.RecalculateBounds();return mesh;}
 Mesh DynamicMesh(Draw draw,Vector3[] positions,Color[] colors,Vector2[] uv,int[] indices){var mesh=draw.Owns&&draw.Mesh?draw.Mesh:new Mesh{indexFormat=IndexFormat.UInt32};mesh.Clear();mesh.vertices=positions;mesh.colors=colors;for(int i=0;i<4;i++)mesh.SetUVs(i,uv.ToList());mesh.triangles=indices;mesh.RecalculateBounds();draw.Mesh=mesh;draw.Owns=true;return mesh;}
 Mesh Disc(TopAvfxGraph.Particle p,JToken node,Draw draw){
  var data=node["data"];if(data==null)return null;var values=new Dictionary<string,float>();foreach(var field in new[]{"Ang","WB","WE","RB","RE","HBI","HEI","HBO","HEO"}){var value=TopAvfxMath.Scalar(data[field],data[field+"R"],p.Age,seed,p.Key+"/disc/"+field,field=="Ang"?Math.PI*2:0);if(!value.HasValue){Diagnostics.Add("disc_curve");return null;}values[field]=(float)value.Value;}
  int seg=I(data["PCnV"]),rad=I(data["PCnU"]);if(seg<1||seg>256||rad<1||rad>32||Math.Abs(values["Ang"])>Math.PI*32){Diagnostics.Add("disc_budget");return null;}
  var ci=TopAvfxMath.Colour(data["CEI"],p.Age,seed,p.Key+"/inner");var co=TopAvfxMath.Colour(data["CEO"],p.Age,seed,p.Key+"/outer");if(!ci.HasValue||!co.HasValue)return null;
  int count=(seg+1)*(rad+1);var pos=new Vector3[count];var uv=new Vector2[count];var colors=new Color[count];var indices=new int[seg*rad*6];int k=0;
  for(int i=0;i<=seg;i++){float u=(float)i/seg,angle=values["Ang"]*u,radius=Mathf.Lerp(values["RB"],values["RE"],u),width=Mathf.Lerp(values["WB"],values["WE"],u);for(int j=0;j<=rad;j++){float t=(float)j/rad,r=radius+width*(t-.5f),h=Mathf.Lerp(Mathf.Lerp(values["HBI"],values["HEI"],u),Mathf.Lerp(values["HBO"],values["HEO"],u),t);int n=i*(rad+1)+j;pos[n]=new Vector3(-Mathf.Cos(angle)*r,h,Mathf.Sin(angle)*r);uv[n]=new Vector2(u,t);colors[n]=Color.LerpUnclamped(ci.Value,co.Value,t);if(i<seg&&j<rad){int a=n,b=a+rad+1;foreach(int index in new[]{a,a+1,b,a+1,b+1,b})indices[k++]=index;}}}
  return DynamicMesh(draw,pos,colors,uv,indices);
 }
 Mesh Ribbon(TopAvfxGraph.Particle p,JToken node,Draw draw,Camera view){
  var ends=Endpoints?.Invoke();if(!ends.HasValue){Diagnostics.Add("polyline_endpoint_missing");return null;}var data=node["data"];if(!B(data?["bCtg"])){Diagnostics.Add("polyline_not_endpoint_connected");return null;}Diagnostics.Add("polyline_reconstruction_not_game_equivalence");foreach(var field in new[]{"bSpl","bLcl","bEdg","bNtB","BWpT","LnCT","NBBA","PnED"})if(N(data[field])!=0)Diagnostics.Add("polyline_field_not_reproduced/"+field);
  int raw=I(data["PnC"]);if(raw<2){Diagnostics.Add("polyline_point_count");return null;}int count=Math.Min(raw,64);float centre=N(data["PnCC"],-1)/raw;if(centre<=0||centre>=1){centre=.5f;Diagnostics.Add("polyline_center_index_assumed_half");}
  var widths=new Dictionary<string,float>();foreach(var f in new[]{"Wd","WdB","WdC","WdE"}){if(data[f] is not JObject objectValue||!objectValue.HasValues){Diagnostics.Add("polyline_missing_data/"+f);return null;}var v=TopAvfxMath.Scalar(data[f],data[f+"R"],p.Age,seed,p.Key+"/polyline/"+f,0);if(!v.HasValue)return null;widths[f]=Mathf.Max(0,(float)v.Value);}
  var colorsAt=new Dictionary<string,Color>();foreach(var f in new[]{"ColB","ColC","ColE"}){var c=TopAvfxMath.Colour(data[f],p.Age,seed,p.Key+"/polyline/"+f);if(!c.HasValue)return null;colorsAt[f]=c.Value;}
  Vector3 start=B(data["bCtr"])?ends.Value.End:ends.Value.Start,end=B(data["bCtr"])?ends.Value.Start:ends.Value.End,axis=end-start,cam=Root.transform.InverseTransformPoint(view.transform.position);if(axis.sqrMagnitude<1e-8f)return null;axis.Normalize();var pos=new Vector3[count*2];var uv=new Vector2[count*2];var colors=new Color[count*2];var indices=new int[(count-1)*6];
  for(int i=0;i<count;i++){float t=(float)i/(count-1);var point=Vector3.LerpUnclamped(start,end,t);var side=Vector3.Cross(axis,cam-point);if(side.sqrMagnitude<1e-8f)side=Vector3.Cross(axis,Mathf.Abs(axis.y)<.9f?Vector3.up:Vector3.right);side.Normalize();bool first=t<=centre;float u=first?t/centre:(t-centre)/(1-centre),w=widths["Wd"]*Mathf.Lerp(first?widths["WdB"]:widths["WdC"],first?widths["WdC"]:widths["WdE"],u);Color color=Multiply(Color.LerpUnclamped(first?colorsAt["ColB"]:colorsAt["ColC"],first?colorsAt["ColC"]:colorsAt["ColE"],u),p.Color);for(int j=0;j<2;j++){int v=i*2+j;pos[v]=point+side*w*(j==0?-.5f:.5f);uv[v]=new Vector2(t,j);colors[v]=color;}if(i<count-1){int v=i*2;Array.Copy(new[]{v,v+1,v+2,v+1,v+3,v+2},0,indices,i*6,6);}}
  return DynamicMesh(draw,pos,colors,uv,indices);
 }
 Definition MaterialDefinition(int index,JToken node){
  if(definitions.TryGetValue(index,out var prior))return prior;var shader=Shader.Find("TOP/SourceAVFX");if(!shader)throw new Exception("Missing TOP source shader");var mat=new Material(shader);mat.SetFloat("_DebugSolid",DebugMaterialMode);int mode=I(node["values"]?["RMT"]);BlendMode src=BlendMode.SrcAlpha,dst=BlendMode.OneMinusSrcAlpha;if(mode==1){src=BlendMode.DstColor;}else if(mode==2)dst=BlendMode.One;else if(mode==4)dst=BlendMode.OneMinusSrcColor;else if(mode!=0)Diagnostics.Add("unsupported_blend/"+mode);mat.SetInt("_SrcBlend",(int)src);mat.SetInt("_DstBlend",(int)dst);mat.SetFloat("_Decal",I(node["values"]?["PrVT"])==10?1:0);mat.SetFloat("_Offset",I(node["values"]?["PrVT"])==10?-2:0);
  var def=new Definition{Material=mat,Layers=new Layer[4]};for(int i=0;i<4;i++){var data=node["materials"]?["TC"+(i+1)]??new JObject();Texture2D texture=null;if(B(data["bEna"])){int ti=I(data["TxNo"],I(data["TLst"]?.First,-1));var path=pack["textures"] is JArray names&&ti>=0&&ti<names.Count?names[ti]:null;var raw=path==null?null:textureResolver((string)path);if(raw){if(DebugMaterialMode==8)texture=raw;else{texture=new Texture2D(raw.width,raw.height,raw.format,raw.mipmapCount>1,!raw.isDataSRGB){name=raw.name+"/sampler",filterMode=raw.filterMode,anisoLevel=raw.anisoLevel};Graphics.CopyTexture(raw,texture);ownedTextures.Add(texture);texture.wrapModeU=Wrap(I(data["TBUT"]));texture.wrapModeV=Wrap(I(data["TBVT"]));}}else Diagnostics.Add("missing_texture/"+ti);}
   int uvn=I(data["UvSN"]);var uv=node["uv_sets"] is JArray sets&&uvn>=0&&uvn<sets.Count?sets[uvn]:new JObject();var layer=new Layer{Data=data,Texture=texture,UV=uv,Scale=Remap(uv["Scl"]),Scroll=Remap(uv["Scr"])};def.Layers[i]=layer;mat.SetTexture("_Tex"+i,texture);if(I(data["TCCT"])>4)Diagnostics.Add("unknown_color_operator/"+I(data["TCCT"]));}
  if(B(node["materials"]?["TD"]?["bEna"]))Diagnostics.Add("uv_distortion_not_reproduced");if(B(node["values"]?["bSCt"]))Diagnostics.Add("simple_animation_not_reproduced");definitions[index]=def;return def;
 }
 static TextureWrapMode Wrap(int mode)=>mode switch{1=>TextureWrapMode.Clamp,2=>TextureWrapMode.Mirror,_=>TextureWrapMode.Repeat};
 JObject Remap(JToken token){var value=token is JObject o?(JObject)o.DeepClone():new JObject();foreach(var f in new[]{"ACT","ACTR"}){int link=I(value[f]);if(link<0||link>2){Diagnostics.Add("uv_axis_connect");return null;}value[f]=new[]{0,2,5}[link];}return value;}
 bool AnimateMaterial(MaterialPropertyBlock block,Definition definition,TopAvfxGraph.Particle p,Color tint){block.Clear();block.SetVector("_Tint",new Vector4(tint.r,tint.g,tint.b,tint.a));for(int i=0;i<4;i++){var l=definition.Layers[i];var data=l.Data;if(l.Scale==null||l.Scroll==null)return false;var scale=TopAvfxMath.Axes(l.Scale,p.Age,seed,p.Key+"/scale"+i,1);var scroll=TopAvfxMath.Axes(l.Scroll,p.Age,seed,p.Key+"/scroll"+i,0);var rot=TopAvfxMath.Scalar(l.UV["Rot"],l.UV["RotR"],p.Age,seed,p.Key+"/rot"+i,0);if(!scale.HasValue||!scroll.HasValue||!rot.HasValue){Diagnostics.Add("uv_curve");return false;}block.SetVector("_Uv"+i,new Vector4(scale.Value.x,scale.Value.y,scroll.Value.x,scroll.Value.y));block.SetFloat("_Rot"+i,(float)rot.Value);block.SetVector("_Flags"+i,new Vector4(l.Texture&&(i==0||I(data["TCCT"])<=4)?1:0,B(data["bC2A"])?1:0,I(data["UvSN"]),Math.Min(I(data["TCCT"]),4)));block.SetFloat("_Alpha"+i,I(data["TCAT"]));}return true;}
 public void Dispose(){if(disposed)return;disposed=true;Camera.onPreCull-=BeforeCamera;if(camera&&commands!=null)camera.RemoveCommandBuffer(CameraEvent.BeforeForwardAlpha,commands);commands?.Dispose();foreach(var d in draws.Values)if(d.Owns&&d.Mesh)UnityEngine.Object.Destroy(d.Mesh);foreach(var mesh in meshes.Values)if(mesh)UnityEngine.Object.Destroy(mesh);foreach(var d in definitions.Values)UnityEngine.Object.Destroy(d.Material);foreach(var texture in ownedTextures)UnityEngine.Object.Destroy(texture);UnityEngine.Object.Destroy(Root);draws.Clear();meshes.Clear();definitions.Clear();Binders.Clear();}
}
}
