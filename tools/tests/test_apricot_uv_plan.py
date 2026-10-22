# SPDX-License-Identifier: MIT
import copy
import unittest
from tools.apricot_color_plan import binding_signature
from tools.apricot_uv_plan import (UvPlanError, compile_uv_plan, load_verified,
                                   sample_coordinates)

class OriginalUvAbiTests(unittest.TestCase):
    def plan(self, label, vertex_file=None):
        book = load_verified()
        pixel = next(p for p in book['pixels'] if p['label'] == label)
        pairs = [p for p in book['pairs'] if p['pixel_sha256'] == pixel['bytecode_sha256']]
        if vertex_file:
            vertex = next(v for v in book['vertices'] if v['observed_file'] == vertex_file)
            pair = next(p for p in pairs if p['vertex_sha256'] == vertex['bytecode_sha256'])
        else:
            pair = pairs[0]
            vertex = next(v for v in book['vertices'] if v['bytecode_sha256'] == pair['vertex_sha256'])
        return {'status': 'verified_uv_abi', 'package_sha256': pair['package_sha256'],
                'programs': {stage: {'sha256': p['bytecode_sha256'], 'bindings_sha256': p['bindings_sha256']}
                             for stage,p in [('vertex',vertex),('pixel',pixel)]}}

    def test_shape_integer_precision_variants(self):
        # Independent original itof/mul operands: .001, .005, .01.
        for index,expected in [(3,[.25,-.5]),(16,[1.25,-2.5]),(17,[2.5,-5.0])]:
            plan=self.plan('shape1',f'apricot-shape-vertex{index}.dxbc')
            got=sample_coordinates(plan,{'TEXCOORD1':[250,-500,750,1000]})
            for a,b in zip(got['samples'][0]['uv'],expected):self.assertAlmostEqual(a,b,places=6)

    def test_shape_four_layers_take_four_distinct_pairs(self):
        got=sample_coordinates(self.plan('shape4'),{'TEXCOORD1':[250,500,750,1000],'TEXCOORD2':[-250,-500,-750,-1000]})
        for r,expected in zip(got['samples'],[[.25,.5],[.75,1],[-.25,-.5],[-.75,-1]]):
            for a,b in zip(r['uv'],expected):self.assertAlmostEqual(a,b,places=6)

    def test_model_permutation_routes_and_affine_xyw(self):
        attrs={'TEXCOORD0':[.25,.5,.75,1.0],'TEXCOORD1':[-.25,-.5,-.75,-1.]}
        # .z is deliberately huge; .w, not .z, supplies translation.
        rows=[[0.,-2.,9999.,.125],[3.,0.,-9999.,-.25]]
        got=sample_coordinates(self.plan('model4'),attrs,uv_transform_rows=rows)
        self.assertEqual([r['uv'] for r in got['samples']],[[-.875,.5],[.75,1.],[-.75,-1.],[-.75,-1.]])
        self.assertEqual([r['texture_slot'] for r in got['samples']],[0,1,2,3])
        self.assertEqual(sample_coordinates(self.plan('model1'),{'TEXCOORD0':attrs['TEXCOORD0']})['samples'][0]['uv'],[.75,1.])
        for label in ['model2','model3']:
            got=sample_coordinates(self.plan(label),{'TEXCOORD0':attrs['TEXCOORD0']},uv_transform_rows=rows)
            self.assertTrue(all(r['uv']==[-.875,.5] for r in got['samples']))

    def test_powder_float_inputs_are_not_integer_scaled(self):
        got=sample_coordinates(self.plan('powder1'),{'TEXCOORD2':[.125,-.75]})
        self.assertEqual(got['samples'][0]['uv'],[.125,-.75])

    def test_no_guessed_inputs_or_rows(self):
        plan=self.plan('shape1')
        for attrs in [{},{'TEXCOORD1':[250.,0,0,0]},{'TEXCOORD1':[True,0,0,0]},{'TEXCOORD1':[1<<31,0,0,0]}]:
            with self.assertRaises(UvPlanError):sample_coordinates(plan,attrs)
        with self.assertRaises(UvPlanError):sample_coordinates(self.plan('model2'),{'TEXCOORD0':[0,0,0,0]})
        for x in [float('nan'),float('inf'),1e100,True]:
            with self.assertRaises(UvPlanError):sample_coordinates(self.plan('powder1'),{'TEXCOORD2':[x,0]})

    def test_reject_unreviewed_pair_and_layout(self):
        plan=self.plan('model4');plan['programs']['vertex']=self.plan('shape1')['programs']['vertex']
        with self.assertRaises(UvPlanError):sample_coordinates(plan,{'TEXCOORD1':[0,0,0,0]})
        plan=self.plan('model4');plan['programs']['pixel']['bindings_sha256']='0'*64
        with self.assertRaises(UvPlanError):sample_coordinates(plan,{})
        plan=self.plan('model4');plan['samples']=[{'uv':[99,99]}]
        got=sample_coordinates(plan,{'TEXCOORD0':[0,0,0,0],'TEXCOORD1':[0,0,0,0]},uv_transform_rows=[[1,0,999,0],[0,1,999,0]])
        self.assertEqual(got['samples'][0]['uv'],[0.,0.])

    def compile_fixture(self):
        # Synthetic resource layout isolates compiler gates; private original
        # corpus separately exercises 37 real layouts and package pass uses.
        plan=self.plan('model4');book=copy.deepcopy(load_verified())
        stages={}
        for stage,group in [('vertex','vertices'),('pixel','pixels')]:
            identity=plan['programs'][stage]
            row=next(r for r in book[group] if r['bytecode_sha256']==identity['sha256'])
            row['bindings_sha256']=binding_signature({})
            stages[stage]=[{'index':0,'bindings':{},'bytecode':{'sha256':identity['sha256']}}]
        meta={'source_sha256':plan['package_sha256'],'programs':stages,
              'nodes':[{'index':0,'passes':[{'vertex':0,'pixel':0}]}]}
        return meta,book

    def test_compile_positive_and_reject_package_or_program_mutation(self):
        meta,book=self.compile_fixture()
        self.assertEqual(compile_uv_plan(meta,0,verified=book)['status'],'verified_uv_abi')
        meta['source_sha256']='0'*64
        self.assertEqual(compile_uv_plan(meta,0,verified=book)['status'],'unsupported')
        meta,book=self.compile_fixture();meta['programs']['vertex'][0]['bytecode']['sha256']='0'*64
        self.assertEqual(compile_uv_plan(meta,0,verified=book)['status'],'unsupported')

    def test_reject_intervening_shader_stages(self):
        for stage in ['hull','domain','geometry']:
            meta,book=self.compile_fixture();meta['nodes'][0]['passes'][0][stage]=0
            self.assertEqual(compile_uv_plan(meta,0,verified=book)['status'],'unsupported')

    def test_invalid_or_ambiguous_pass_is_not_selected(self):
        meta={'nodes':[{'index':0,'passes':[{},{}]}]}
        self.assertEqual(compile_uv_plan(meta,0)['status'],'unsupported')
        for index in [-1,True,0.5]:self.assertEqual(compile_uv_plan(meta,index)['status'],'unsupported')
        for index in [-1,True,2]:self.assertEqual(compile_uv_plan(meta,0,pass_index=index)['status'],'unsupported')

if __name__=='__main__':unittest.main()
