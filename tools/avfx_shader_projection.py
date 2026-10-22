#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Static, source-backed projection of declared AVFX particle fields."""
try:
    from .avfx_shader_select import load_names
except ImportError:
    from avfx_shader_select import load_names

UVP={0:'High',1:'Medium',2:'Low'}; UVC={i:str(i) for i in range(5)}
CUV={0:'ByParameter',1:'ByPixelPosition'}; COP={0:'Mul',1:'Add',2:'Sub',3:'Max',4:'Min'}
AOP={0:'Mul',1:'Max',2:'Min',3:'None'}

def _lit(v,path,ds,boolean=False):
    if isinstance(v,dict) and 'value' in v:
        if boolean and 'byte' in v and (v['byte'] not in (0,1) or not isinstance(v['value'],(bool,int)) or v['value'] not in (0,1) or bool(v['value']) != bool(v['byte'])):
            ds.append({'path':path,'reason':'inconsistent_boolean_record','value':v}); return
        v=v['value']
    if boolean and (isinstance(v,bool) or isinstance(v,int) and not isinstance(v,bool) and v in (0,1)):
        return bool(v)
    if not boolean and isinstance(v,int) and not isinstance(v,bool): return v
    ds.append({'path':path,'reason':'invalid_boolean_literal' if boolean else 'invalid_integer_literal','value':v})

def project_particle(document,particle_index):
    ds=[]; out={'status':'projected','rendering_complete':False,
      'scope':'declared AVFX fields only; no host state or shader selection',
      'particle_index':particle_index,'constraints':[],'diagnostics':ds}
    groups=document.get('groups',{}) if isinstance(document,dict) else {}
    ps=groups.get('Ptcl',[]) if isinstance(groups,dict) else []
    if not isinstance(ps,list):ps=[]
    if not isinstance(particle_index,int) or isinstance(particle_index,bool) or not 0<=particle_index<len(ps):
        out['status']='invalid'; ds.append({'path':'particle_index','reason':'out_of_range'}); return out
    p=ps[particle_index]
    if not isinstance(p,dict) or not isinstance(p.get('values',{}),dict) or not isinstance(p.get('materials',{}),dict) or not isinstance(p.get('uv_sets',[]),list):
        out['status']='invalid';ds.append({'path':'particle','reason':'invalid_particle_structure'});return out
    out['source_sha256']=document.get('source_sha256')
    db=load_names(); ids={}; ambiguous=set()
    for h,n in db['keys'].items():
        if n in ids and ids[n]!=int(h,16):ambiguous.add(n)
        else:ids[n]=int(h,16)
    for n in ambiguous:ids.pop(n,None)
    def add(k,v,path):
        if k not in ids or v not in ids:
            ds.append({'path':path,'reason':'semantic_missing_from_pinned_crc_map','key':k,'value':v}); return
        out['constraints'].append({'source_path':path,
          'key':{'id':ids[k],'hex':f'0x{ids[k]:08X}','name':k},
          'value':{'id':ids[v],'hex':f'0x{ids[v]:08X}','name':v}})
    def enum(src,tag,mapping,key,path=None):
        if tag not in src:return
        path=path or f'values.{tag}'; v=_lit(src[tag],path,ds)
        if v in mapping:add(key,mapping[v],path)
        elif v is not None:ds.append({'path':path,'reason':'unknown_enum_value','value':v})
    vals=p.get('values',{}); enum(vals,'UVPT',{k:'UvPrecisionType_'+v for k,v in UVP.items()},'UvPrecisionType_Table')
    enum(vals,'UvSN',{k:'UvSetCount_'+v for k,v in UVC.items()},'UvSetCount_Table')
    for i,uv in enumerate(p.get('uv_sets',[])):
        if not isinstance(uv,dict):
            ds.append({'path':f'uv_sets[{i}]','reason':'invalid_uv_record'});continue
        enum(uv,'CUvT',{k:'UvCompute_'+v for k,v in CUV.items()},f'UvCompute{i}_Table',f'uv_sets[{i}].CUvT')
    prefixes={'TC1':'TextureColor1','TC2':'TextureColor2','TC3':'TextureColor3','TC4':'TextureColor4',
              'TN':'TextureNormal','TR':'TextureReflection','TD':'TextureDistortion','TP':'TexturePalette'}
    for slot,prefix in prefixes.items():
        m=p.get('materials',{}).get(slot)
        if not isinstance(m,dict) or 'bEna' not in m:continue
        ena=_lit(m['bEna'],f'materials.{slot}.bEna',ds,True)
        if ena is None:continue
        add(prefix+'_Table',prefix+('_Enable' if ena else '_Disable'),f'materials.{slot}.bEna')
        if not ena:continue
        if slot.startswith('TC'):
            if 'bC2A' in m:
                flag=_lit(m['bC2A'],f'materials.{slot}.bC2A',ds,True)
                if flag is not None:add(prefix+'_ColorToAlpha_Table',prefix+'_ColorToAlpha_'+('On' if flag else 'Off'),f'materials.{slot}.bC2A')
            if 'UvSN' in m:
                uv=_lit(m['UvSN'],f'materials.{slot}.UvSN',ds)
                if uv in range(4):add(prefix+'_UvNo_Table',prefix+f'_Uv_{uv}',f'materials.{slot}.UvSN')
                elif uv is not None:ds.append({'path':f'materials.{slot}.UvSN','reason':'unknown_uv_index','value':uv})
        if slot in ('TC2','TC3','TC4'):
            enum(m,'TCCT',{k:prefix+'_CalculateColor_'+v for k,v in COP.items()},prefix+'_CalculateColor_Table',f'materials.{slot}.TCCT')
            enum(m,'TCAT',{k:prefix+'_CalculateAlpha_'+v for k,v in AOP.items()},prefix+'_CalculateAlpha_Table',f'materials.{slot}.TCAT')
        if slot in ('TN','TD') and 'UvSN' in m:
            uv=_lit(m['UvSN'],f'materials.{slot}.UvSN',ds)
            if uv in range(4):add(prefix+'_UvNo_Table',prefix+f'_Uv_{uv}',f'materials.{slot}.UvSN')
            elif uv is not None:ds.append({'path':f'materials.{slot}.UvSN','reason':'unknown_uv_index','value':uv})
    # These are real remaining inputs, not silently ignored/defaulted fields.
    host_fields={'DsSp':'requires_host_depth_capability_context',
                 'bAFg':'requires_host_fog_mode_context',
                 'bFar':'far_clip_flag_is_not_force_far_z',
                 'RMT':'requires_host_final_color_and_blend_context'}
    for tag,reason in host_fields.items():
        if tag in vals:ds.append({'path':'values.'+tag,'reason':reason})
    first=p.get('materials',{}).get('TC1',{})
    if isinstance(first,dict):
        for tag in ('TCCT','TCAT'):
            if tag in first:ds.append({'path':'materials.TC1.'+tag,'reason':'requires_dynamic_color_alpha_control_mapping'})
    uv_count=_lit(vals['UvSN'],'values.UvSN',[]) if 'UvSN' in vals else None
    if isinstance(uv_count,int) and not isinstance(uv_count,bool) and uv_count!=len(p.get('uv_sets',[])):
        ds.append({'path':'values.UvSN','reason':'declared_uv_set_count_differs_from_records','declared':uv_count,'records':len(p.get('uv_sets',[]))})
    return out
