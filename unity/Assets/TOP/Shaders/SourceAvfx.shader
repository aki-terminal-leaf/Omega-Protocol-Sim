// SPDX-License-Identifier: MIT
Shader "TOP/SourceAVFX" {
 Properties {
  _Tex0("Layer0",2D)="white" {} _Tex1("Layer1",2D)="white" {} _Tex2("Layer2",2D)="white" {} _Tex3("Layer3",2D)="white" {}
  _Tint("Linear source tint",Vector)=(1,1,1,1) _DebugSolid("Debug-only non-source calibration",Float)=0
  _Uv0("UV0",Vector)=(1,1,0,0) _Uv1("UV1",Vector)=(1,1,0,0) _Uv2("UV2",Vector)=(1,1,0,0) _Uv3("UV3",Vector)=(1,1,0,0)
  _Flags0("enable/colorToAlpha/uv/colorOp",Vector)=(0,0,0,0) _Flags1("Flags1",Vector)=(0,0,0,0) _Flags2("Flags2",Vector)=(0,0,0,0) _Flags3("Flags3",Vector)=(0,0,0,0)
  _Rot0("Rot0",Float)=0 _Rot1("Rot1",Float)=0 _Rot2("Rot2",Float)=0 _Rot3("Rot3",Float)=0
  _Alpha0("Alpha0",Float)=0 _Alpha1("Alpha1",Float)=0 _Alpha2("Alpha2",Float)=0 _Alpha3("Alpha3",Float)=0
  _Decal("Flat arena decal",Float)=0
  [HideInInspector] _SrcBlend("SrcBlend",Float)=5 [HideInInspector] _DstBlend("DstBlend",Float)=10 [HideInInspector] _Offset("Offset",Float)=0
 }
 SubShader { Tags {"Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True"}
  Pass { Cull Off ZWrite Off ZTest LEqual Blend [_SrcBlend] [_DstBlend] Offset [_Offset],0
   CGPROGRAM
   #pragma target 3.5
   #pragma vertex vert
   #pragma fragment frag
   #include "UnityCG.cginc"
   struct appdata {float4 vertex:POSITION;float4 color:COLOR;float2 uv:TEXCOORD0;float2 uv1:TEXCOORD1;float2 uv2:TEXCOORD2;float2 uv3:TEXCOORD3;};
   struct v2f {float4 pos:SV_POSITION;float4 color:COLOR;float2 uv:TEXCOORD0;float2 uv1:TEXCOORD1;float2 uv2:TEXCOORD2;float2 uv3:TEXCOORD3;float3 world:TEXCOORD4;};
   sampler2D _Tex0,_Tex1,_Tex2,_Tex3;float4 _Tint,_Uv0,_Uv1,_Uv2,_Uv3,_Flags0,_Flags1,_Flags2,_Flags3;float _Rot0,_Rot1,_Rot2,_Rot3,_Alpha0,_Alpha1,_Alpha2,_Alpha3,_Decal,_DebugSolid;
   v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;o.color=v.color;o.uv=v.uv;o.uv1=v.uv1;o.uv2=v.uv2;o.uv3=v.uv3;return o;}
   float2 coord(v2f i,float index,float4 p,float angle){float2 uv=index<.5?i.uv:index<1.5?i.uv1:index<2.5?i.uv2:i.uv3;uv=(uv-.5)*p.xy;float c=cos(angle),s=sin(angle);uv=float2(c*uv.x-s*uv.y,s*uv.x+c*uv.y)+.5+p.zw;uv.y=1-uv.y;return uv;}
   float4 merge(float4 a,float4 b,float co,float ao){float3 rgb=co<.5?a.rgb*b.rgb:co<1.5?a.rgb+b.rgb:co<2.5?a.rgb-b.rgb:co<3.5?max(a.rgb,b.rgb):min(a.rgb,b.rgb);float alpha=ao<.5?a.a*b.a:ao<1.5?max(a.a,b.a):ao<2.5?min(a.a,b.a):a.a;return float4(rgb,alpha);}
   float4 ink(sampler2D tex,v2f i,float4 flags,float4 uv,float angle){float4 b=tex2D(tex,coord(i,flags.z,uv,angle));if(flags.y>.5)b.a*=max(b.r,max(b.g,b.b));return b;}
   float4 frag(v2f i):SV_Target {if(_DebugSolid>7.5)return tex2D(_Tex0,i.uv);if(_DebugSolid>6.5)return float4(i.color.rgb,1);if(_DebugSolid>5.5)return i.color;if(_DebugSolid>4.5)return ink(_Tex0,i,_Flags0,_Uv0,_Rot0);if(_DebugSolid>3.5)return float4(_Flags0.xyz,1);if(_DebugSolid>2.5)return tex2D(_Tex0,i.uv);if(_DebugSolid>1.5)return _Tint;if(_DebugSolid>.5)return float4(1,0,0,1);if(_Decal>.5&&length(i.world.xz)>20.5)discard;float4 c=1;
    if(_Flags0.x>.5)c=ink(_Tex0,i,_Flags0,_Uv0,_Rot0);
    if(_Flags1.x>.5)c=merge(c,ink(_Tex1,i,_Flags1,_Uv1,_Rot1),_Flags1.w,_Alpha1);
    if(_Flags2.x>.5)c=merge(c,ink(_Tex2,i,_Flags2,_Uv2,_Rot2),_Flags2.w,_Alpha2);
    if(_Flags3.x>.5)c=merge(c,ink(_Tex3,i,_Flags3,_Uv3,_Rot3),_Flags3.w,_Alpha3);
    return float4(max(0,_Tint.rgb*i.color.rgb*c.rgb),saturate(_Tint.a*i.color.a*c.a));
   }
   ENDCG
  }
 }
}
