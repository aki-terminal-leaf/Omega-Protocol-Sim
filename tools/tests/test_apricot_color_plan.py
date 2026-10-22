# SPDX-License-Identifier: MIT
"""Synthetic core tests plus an optional private original-instruction oracle."""
import copy
import json
from pathlib import Path
import random
import struct
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from apricot_color_plan import compile_plan, evaluate, shade_before_postprocess, binding_signature, PlanError
from avfx_shader_select import load_names
from shpk_inspect import inspect

ROOT=Path('/home/brewuser/.openclaw/workspace/main/artifacts/top-avfx-49027')

def synthetic():
    names={v:int(k,16) for k,v in load_names()['keys'].items()}
    values=[];keys=[]
    for n in range(1,5):
        prefix=f'TextureColor{n}'
        pairs={prefix+'_Table':prefix+('_Enable' if n==1 else '_Disable')}
        if n==1:pairs.update({prefix+'_ColorToAlpha_Table':prefix+'_ColorToAlpha_Off',prefix+'_UvNo_Table':prefix+'_Uv_0'})
        for key,value in pairs.items():keys.append({'id':names[key],'default':names[value]});values.append(names[value])
    bindings={x:[] for x in ('constants','samplers','textures','uavs')}
    bindings['textures']=[{'id':7,'name':'g_SamplerColor1','slot':0,'is_texture':1,'size':0}]
    program={'bytecode':{'sha256':'a'*64},'bindings':bindings}
    node={'index':0,'keys':{'scene':values},'passes':[{'id':5,'vertex':0,'pixel':0}]}
    meta={'keys':{'scene':keys},'nodes':[node],'programs':{'pixel':[program]}}
    book={'programs':[{'bytecode_sha256':'a'*64,'bindings_sha256':binding_signature(bindings),'equation_id':'shape1'}]}
    return meta,book

def reference(label,c,cc,ca):
    # Direct, independently transcribed equations from the selected ORIGINAL
    # instruction traces, not an implementation of the generic plan interpreter.
    m=tuple(1+(c[0][i]-1)*(cc if i<3 else ca) for i in range(4))
    weights=struct.unpack('<3f',struct.pack('<3I',0x3e990afe,0x3f162c23,0x3dea7371))
    lum=lambda x:sum(x[i]*weights[i] for i in range(3))
    a=1+(lum(c[0])-1)*ca
    if label=='identity':return (1.,1.,1.,1.)
    if label in ('shape1','powder1'):return m
    if label in ('shape2','model2'):return (*c[1][:3],a)
    if label=='shape3':return (*(m[i]*c[2][i] for i in range(3)),m[3]*c[1][3]*c[2][3])
    if label=='shape4':return (*(c[1][i]*c[2][i]+c[3][i] for i in range(3)),a*c[1][3])
    if label=='model1':return (1.,1.,1.,a)
    if label=='model3':return (*(m[i]+c[1][i] for i in range(3)),m[3]*lum(c[2]))
    if label=='model4':return (*(c[1][i]+c[2][i] for i in range(3)),a*c[1][3]*lum(c[3]))
    raise AssertionError(label)

class Synthetic(unittest.TestCase):
    def test_reviewed_identity_and_explicit_dynamic_controls(self):
        meta,book=synthetic();p=compile_plan(meta,0,verified=book)
        self.assertEqual(p['status'],'verified_color_stage')
        samples=[(.2,.4,.6,.1)]*4
        self.assertEqual(evaluate(p,samples,calculate_color=0,calculate_alpha=0),(1,1,1,1))
        for got,want in zip(evaluate(p,samples,calculate_color=1,calculate_alpha=1),samples[0]):self.assertAlmostEqual(got,want)
    def test_modified_bytecode_or_resource_layout_is_not_trusted(self):
        meta,book=synthetic();meta['programs']['pixel'][0]['bytecode']['sha256']='b'*64
        self.assertEqual(compile_plan(meta,0,verified=book)['status'],'unsupported')
        meta,book=synthetic();meta['programs']['pixel'][0]['bindings']['textures'][0]['slot']=3
        self.assertEqual(compile_plan(meta,0,verified=book)['status'],'unsupported')
    def test_multiple_passes_require_explicit_choice(self):
        meta,book=synthetic();meta['nodes'][0]['passes']*=2
        self.assertEqual(compile_plan(meta,0,verified=book)['status'],'unsupported')
        self.assertEqual(compile_plan(meta,0,pass_index=1,verified=book)['status'],'verified_color_stage')
    def test_nonfinite_and_wrong_layer_budgets_fail(self):
        meta,book=synthetic();p=compile_plan(meta,0,verified=book)
        with self.assertRaises(PlanError):evaluate(p,[(1,1,1,1)]*4,calculate_color=float('nan'),calculate_alpha=1)
        p['layers']*=2
        with self.assertRaises(PlanError):evaluate(p,[(1,1,1,1)]*4,calculate_color=1,calculate_alpha=1)
    def test_clamp_and_discard_follow_common_factors(self):
        meta,book=synthetic();p=compile_plan(meta,0,verified=book)
        out=shade_before_postprocess(p,[(1,1,1,1)]*4,calculate_color=1,calculate_alpha=1,common_factor=(-2,3,4,.002))
        self.assertEqual(out['rgba'],(0,3,4,.002));self.assertTrue(out['discard'])
    def test_unknown_node_and_schema_are_not_defaulted(self):
        meta,book=synthetic()
        self.assertEqual(compile_plan(meta,-1,verified=book)['status'],'unsupported')
        meta['nodes'][0]['keys']['scene'].pop()
        self.assertEqual(compile_plan(meta,0,verified=book)['status'],'unsupported')

class OriginalOracle(unittest.TestCase):
    def test_every_selected_original_node_matches_independent_disassembly_equations(self):
        source=ROOT/'layer-programs/layer-programs.json'
        if not source.exists():self.skipTest('private original corpus is unavailable')
        records=json.loads(source.read_text());rng=random.Random(49027);nodes=cases=0
        packages={}
        for record in records:
            family=record['kind']
            if family not in packages:
                packages[family]=inspect((ROOT/f'shader-bundle/source/shader/sm5/shpk/apricot_{family}.shpk').read_bytes())
            for original in record['nodes']:
                plan=compile_plan(packages[family],original['index'])
                self.assertEqual(plan['status'],'verified_color_stage',plan['diagnostics']);nodes+=1
                for cc,ca in [(0,0),(1,1),(.35,.7)]:
                    samples=[tuple(rng.random() for _ in range(4)) for _ in range(4)]
                    got=evaluate(plan,samples,calculate_color=cc,calculate_alpha=ca)
                    want=reference(family+str(record['layers']),samples,cc,ca)
                    for x,y in zip(got,want):self.assertAlmostEqual(x,y,places=11,msg=str((family,record['layers'],original['index'],plan['layers'])))
                    cases+=1
        print('ORIGINAL_COLOR_ORACLE nodes',nodes,'cases',cases)
