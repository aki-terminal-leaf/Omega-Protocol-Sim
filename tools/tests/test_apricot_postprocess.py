# SPDX-License-Identifier: MIT
"""Behavior boundaries and independent hand-calculated explicit-PS examples."""
from pathlib import Path
import struct
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from apricot_color_plan import load_verified as color_book
from apricot_postprocess import (PostprocessError, compile_postprocess_plan,
    evaluate_postprocess, evaluate_pixel, fresnel_factor, load_verified,
    postprocess_coordinates)


def color_plan(label):
    row = next(x for x in color_book()['programs'] if x['equation_id'] == label)
    return {'status': 'verified_color_stage', 'rendering_complete': False,
            **{k: row[k] for k in ('bytecode_sha256', 'bindings_sha256',
                                  'nonnegative_clamp', 'discard_threshold_bits')},
            'review_equation': label, 'color_equation_sha256': row['equation_sha256']}


def output(plan, rgba=(.2, .4, .6, .5), **overrides):
    values = dict(rgba=rgba, tone_map_parameter=(.75, 17, -9, 1.5), apply_tone_map=1,
                  blend_state_type=1, depth=.65, lut_start_z=.15, lut_inv_range=2,
                  sample=lambda role, uv: (.0, .2, .8, .9) if role=='tone_map' else (.37, .4, .5, .6))
    values.update(overrides)
    return evaluate_postprocess(plan, **values)


class ExplicitPostprocess(unittest.TestCase):
    def test_hash_and_layout_not_mutable_equation_label_select_output_modes(self):
        p = compile_postprocess_plan(color_plan('shape1'))
        for key in ('bytecode_sha256', 'bindings_sha256'):
            changed = dict(p); changed[key] = 'f'*64
            with self.assertRaises(PostprocessError): output(changed)
        # A forged mode flag is deliberately ignored; only reviewed identity wins.
        changed = dict(p, rgb_output='saturate_then_alpha_white', equation_id='model1')
        self.assertEqual(output(changed)['mrt0'], output(p)['mrt0'])
        p = color_plan('shape1'); p['nonnegative_clamp'] = 'before_common'
        with self.assertRaises(PostprocessError): compile_postprocess_plan(p)
        with self.assertRaises(PostprocessError): compile_postprocess_plan(color_plan('identity'))

    def test_non_neutral_tone_and_original_red_channel_not_swizzled_alpha(self):
        # radicand=1+.75*(0-1)=.25; rsqrt=2; gain=1.5*2=3.
        p = compile_postprocess_plan(color_plan('shape1'))
        got = output(p)
        for x, y in zip(got['mrt0'], (.6, 1.2, 1.8, .5)): self.assertAlmostEqual(x, y)
        # Partial ApplyToneMap .4 -> exposure 1.4, not binary on/off.
        got = output(p, apply_tone_map=.4)
        for x, y in zip(got['mrt0'][:3], (.42, .84, 1.26)): self.assertAlmostEqual(x, y)
        got = output(p, apply_tone_map=0)
        for x, y in zip(got['mrt0'][:3], (.3, .6, .9)): self.assertAlmostEqual(x, y)

    def test_model1_only_saturates_rgb_and_composites_over_white(self):
        for label in ('shape1', 'powder1', 'model2', 'model3', 'model4'):
            p = compile_postprocess_plan(color_plan(label))
            self.assertAlmostEqual(output(p)['mrt0'][2], 1.8)
        got = output(compile_postprocess_plan(color_plan('model1')))
        for x, y in zip(got['mrt0'], (.8, 1, 1, .5)): self.assertAlmostEqual(x, y)

    def test_mrt1_blend_sign_and_square_not_boolean_or_clamped_rgb(self):
        p = compile_postprocess_plan(color_plan('shape1'))
        weights = [struct.unpack('<f', struct.pack('<I', int(x,16)))[0]
                   for x in load_verified()['output_luma_weight_bits']]
        rgb = (.2, .4, .6)
        luma = sum(x*y for x,y in zip(rgb,weights))
        for blend in (-2, -1, -.5, 0, .5, 1, 2):
            got = output(p, tone_map_parameter=(0,0,0,1), blend_state_type=blend)
            branch = 1-luma if blend<0 else luma
            want = min(1, max(0, 2*max(1-blend*blend, branch)))*.5
            self.assertAlmostEqual(got['mrt1'][3], want)
        # Unclamped negative powder RGB drives MRT1 SAT to zero, not negative.
        got = output(compile_postprocess_plan(color_plan('powder1')), rgba=(-2,-2,-2,.5),
                     tone_map_parameter=(0,0,0,1), blend_state_type=2)
        self.assertEqual(got['mrt1'][3],0)

    def test_depth_sampler_receives_transformed_coordinate_and_original_x(self):
        p = compile_postprocess_plan(color_plan('model1')); calls=[]
        def sample(role, uv):
            calls.append((role,uv))
            return (1,9,8,7) if role=='tone_map' else (uv[0]+.25,9,8,7)
        got=output(p, depth=.55, lut_start_z=.15, lut_inv_range=2, sample=sample)
        self.assertEqual(calls[0],('tone_map',(.5,.5)))
        self.assertAlmostEqual(calls[1][1][0],.8)
        self.assertAlmostEqual(got['mrt1'][0],1.05)
        self.assertEqual(got['mrt1'][1:3],(0,0))

    def test_discard_has_no_mrt_writes_and_exact_float32_boundary(self):
        p=compile_postprocess_plan(color_plan('shape1'))
        threshold=struct.unpack('<f',struct.pack('<I',0x3b808081))[0]
        below=struct.unpack('<f',struct.pack('<I',0x3b808080))[0]
        got=output(p,rgba=(.2,.3,.4,below),sample=lambda *_: self.fail('discarded output sampled'))
        self.assertTrue(got['discard']); self.assertIsNone(got['mrt0']);self.assertIsNone(got['mrt1'])
        self.assertFalse(output(p,rgba=(.2,.3,.4,threshold))['discard'])
        for a in (-.1,1.1):
            with self.assertRaises(PostprocessError):output(p,rgba=(1,1,1,a))

    def test_dynamic_fresnel_vectors_and_exponent_are_not_constant_factor(self):
        p=compile_postprocess_plan(color_plan('model1'))
        inputs=dict(position=(1,0,0),normal=(0,2,0),axis_modifier=1,
                    parameter0=(1,1,0,2),parameter1=(.2,.4,.6,.8),parameter2=(.8,.6,.4,.2))
        # direction=(0,1,0), normalized dot=1 -> upper row exactly.
        for x,y in zip(fresnel_factor(p,**inputs),(.8,.6,.4,.2)): self.assertAlmostEqual(x,y)
        inputs['position']=(0,0,0) # direction=(1,1,0), dot^2=.5 -> midpoint.
        for x in fresnel_factor(p,**inputs): self.assertAlmostEqual(x,.5)
        # Orthogonal vectors hit original float32 epsilon, not zero or 1e-4.
        inputs.update(normal=(0,0,3),parameter0=(1,1,0,1),parameter1=(0,0,0,0),parameter2=(1,1,1,1))
        epsilon=struct.unpack('<f',struct.pack('<I',0x3727c5ac))[0]
        self.assertEqual(fresnel_factor(p,**inputs),(epsilon,)*4)
        with self.assertRaises(PostprocessError):fresnel_factor(compile_postprocess_plan(color_plan('shape1')),**inputs)
        inputs['normal']=(0,0,0)
        with self.assertRaises(PostprocessError):fresnel_factor(p,**inputs)

    def test_full_chain_preserves_signed_powder_vs_shape_and_model_fresnel(self):
        layers=[{'number':n,'enabled':n==1} for n in range(1,5)]
        layers[0].update(color_to_alpha=False,sample_required=True,color_op='DynamicMul',alpha_op='DynamicMul')
        post=dict(tone_map_parameter=(0,0,0,1),apply_tone_map=0,blend_state_type=1,
                  depth=.6,lut_start_z=.1,lut_inv_range=2)
        for label,want in [('powder1',(0,-.3,.4,.5)),('shape1',(.2,0,.4,.5))]:
            p=color_plan(label);p['layers']=layers
            got=evaluate_pixel(p,[(-.2,.3,.4,.5)]*4,calculate_color=1,calculate_alpha=1,
                               vertex_factor=(-1,-1,1,1),document_factor=(1,1,1,1),
                               postprocess=post,sample=lambda *_:(1,0,0,0))
            for x,y in zip(got['mrt0'],want):self.assertAlmostEqual(x,y)
        p=color_plan('model1');p['layers']=[dict(x) for x in layers]
        p['layers'][0]['color_to_alpha']=True
        p['color_to_alpha_weights']=color_book()['color_to_alpha_weights']
        model=dict(position=(0,0,0),normal=(1,0,0),axis_modifier=0,
                   parameter0=(1,0,0,2),parameter1=(0,0,0,0),parameter2=(.2,.4,.6,.5))
        args=dict(calculate_color=1,calculate_alpha=0,vertex_factor=(1,1,1,1),
                  document_factor=(1,1,1,1),postprocess=post,sample=lambda *_:(1,0,0,0))
        got=evaluate_pixel(p,[(.2,.3,.4,1)]*4,model_context=model,**args)
        for x,y in zip(got['mrt0'],(.6,.7,.8,.5)):self.assertAlmostEqual(x,y)
        with self.assertRaises(PostprocessError):evaluate_pixel(p,[(1,1,1,1)]*4,**args)
        p['layers'][0]['color_to_alpha']=False
        with self.assertRaises(PostprocessError):evaluate_pixel(p,[(1,1,1,1)]*4,model_context=model,**args)

    def test_invalid_domain_never_invents_fallback(self):
        p=compile_postprocess_plan(color_plan('shape1'))
        for values in ({'sample':None},{'apply_tone_map':True},{'depth':float('nan')},
                       {'blend_state_type':1e308},{'tone_map_parameter':(1,0,0,1)}):
            with self.assertRaises(PostprocessError):output(p,**values)
        with self.assertRaises(PostprocessError):postprocess_coordinates(p,depth=1e308,lut_start_z=-1e308,lut_inv_range=1)


if __name__ == '__main__':unittest.main()
