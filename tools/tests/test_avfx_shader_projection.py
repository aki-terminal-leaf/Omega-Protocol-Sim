import unittest
from tools.avfx_shader_projection import project_particle
from tools.avfx_shader_select import load_names

def doc(p):return {'groups':{'Ptcl':[p]}}
class Tests(unittest.TestCase):
 def test_mapping_and_bool_dict(self):
  p={'values':{'UVPT':1,'UvSN':2},'uv_sets':[{'CUvT':1}], 'materials':{'TC1':{'bEna':{'value':True},'bC2A':0,'UvSN':3}}}
  n=[(x['key']['name'],x['value']['name']) for x in project_particle(doc(p),0)['constraints']]
  self.assertIn(('UvPrecisionType_Table','UvPrecisionType_Medium'),n); self.assertIn(('TextureColor1_ColorToAlpha_Table','TextureColor1_ColorToAlpha_Off'),n)
 def test_disabled_skips_inactive(self):
  p={'values':{},'uv_sets':[],'materials':{'TC2':{'bEna':False,'UvSN':2,'TCCT':1}}}
  self.assertEqual(['TextureColor2_Disable'],[x['value']['name'] for x in project_particle(doc(p),0)['constraints']])
 def test_unknown_operation_and_missing(self):
  r=project_particle(doc({'values':{},'uv_sets':[],'materials':{'TC3':{'bEna':1,'TCCT':5}}}),0)
  self.assertTrue(any(x['reason']=='unknown_enum_value' for x in r['diagnostics'])); self.assertFalse(any(x['value']['name'].endswith('None') for x in r['constraints']))
 def test_fog_far_unmapped_soft_unresolved(self):
  r=project_particle(doc({'values':{'bAFg':1,'bFar':1,'DsSp':1},'uv_sets':[],'materials':{}}),0)
  self.assertEqual([],r['constraints']); self.assertEqual('requires_host_depth_capability_context',r['diagnostics'][0]['reason'])
 def test_invalid_bool_and_index(self):
  r=project_particle(doc({'values':{},'uv_sets':[],'materials':{'TN':{'bEna':2}}}),0)
  self.assertEqual([],r['constraints']); self.assertEqual('invalid_boolean_literal',r['diagnostics'][0]['reason']); self.assertEqual('invalid',project_particle(doc({}),-1)['status'])
 def test_actual_graph_boolean_record_and_unknown_byte(self):
  p={'values':{},'materials':{'TC1':{'bEna':{'value':True,'byte':1},'bC2A':{'value':False,'byte':0}}}}
  r=project_particle(doc(p),0)
  self.assertTrue(any(x['value']['name']=='TextureColor1_Enable' for x in r['constraints']))
  p['materials']['TC1']['bEna']={'value':True,'byte':0}
  r=project_particle(doc(p),0)
  self.assertFalse(r['constraints'])
  self.assertTrue(any(x['reason']=='inconsistent_boolean_record' for x in r['diagnostics']))
 def test_dynamic_tc1_controls_are_not_silently_ignored(self):
  p={'values':{},'materials':{'TC1':{'bEna':1,'TCCT':1,'TCAT':1}}}
  r=project_particle(doc(p),0)
  self.assertEqual(2,sum(x['reason']=='requires_dynamic_color_alpha_control_mapping' for x in r['diagnostics']))
  self.assertFalse(any('CalculateColor' in x['key']['name'] for x in r['constraints']))
 def test_malformed_particle_is_invalid(self):
  self.assertEqual('invalid',project_particle(doc({'materials':[]}),0)['status'])
 def test_record_count_and_malformed_uv_are_diagnosed(self):
  p={'values':{'UvSN':{'value':2}},'uv_sets':[None],'materials':{}}
  r=project_particle(doc(p),0)
  self.assertTrue(any(x['reason']=='declared_uv_set_count_differs_from_records' for x in r['diagnostics']))
  self.assertTrue(any(x['reason']=='invalid_uv_record' for x in r['diagnostics']))
  self.assertEqual('invalid',project_particle({'groups':{'Ptcl':None}},0)['status'])
 def test_all_constraints_in_crc_map(self):
  p={'values':{'UVPT':0,'UvSN':4},'uv_sets':[{'CUvT':0}]*4,'materials':{'TC2':{'bEna':1,'bC2A':1,'UvSN':0,'TCCT':4,'TCAT':3},'TD':{'bEna':1,'UvSN':3},'TP':{'bEna':0}}}
  known=set(load_names()['keys'].values())
  for c in project_particle(doc(p),0)['constraints']:self.assertIn(c['key']['name'],known);self.assertIn(c['value']['name'],known)
if __name__=='__main__':unittest.main()
