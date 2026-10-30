import sys,unittest,struct,tempfile,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/asset_lab'))
from sample_cinematic_paps import pap_header,sklb_payload,validate_parents,sample_times
from extract_cinematic_rigs import confined,verify,paths
class Validation(unittest.TestCase):
 def test_short_headers(self):
  for f in (pap_header,sklb_payload):
   for b in (b'',b'pap ',b'sklb'+b'\0'*12):
    with self.assertRaises(ValueError):f(b)
 def test_table_overflow(self):
  b=b'pap '+b'\x01\x00\x02\x00'+struct.pack('<hHBBiii',32767,424,1,0,26,26,27)+b'x'
  with self.assertRaises(ValueError):pap_header(b)
 def test_parent_cycles_and_range(self):
  for ps in ([0],[1,0],[-2],[9]):
   with self.assertRaises(ValueError):validate_parents(ps)
  validate_parents([-1,0,1])
 def test_duration_budget_and_endpoint(self):
  for d in (0,-1,float('nan'),float('inf'),1e9):
   with self.assertRaises(ValueError):sample_times(d,100)
  ts=sample_times(.101,2);self.assertEqual(ts[-1],.101);self.assertEqual(ts[:-1],[0,1/30,2/30,3/30])
 def test_manifest_trust(self):
  with tempfile.TemporaryDirectory() as d:
   r=Path(d);(r/'inputs.json').write_text('{}')
   with self.assertRaisesRegex(ValueError,'untrusted manifest'):verify(r,r)
 def test_traversal(self):
  with self.assertRaises(ValueError):confined(Path.cwd(),'../escape')
 def test_original_tagfile_is_open_not_corrupt(self):
  record=b'clip'+b'\0'*28+struct.pack('<hi',0,0)+b'\0'*2
  payload=bytes.fromhex('1e0db0cacefa11d0')+b'\0'*64
  b=b'pap '+b'\x01\x00\x02\x00'+struct.pack('<hHBBiii',1,424,1,0,26,66,66+len(payload))+record+payload
  h=pap_header(b);self.assertEqual(h['container_validation'],'OUTER_VALIDATED');self.assertEqual(h['clips'][0]['index'],0)
 def test_negative_clip_index(self):
  record=b'clip'+b'\0'*28+struct.pack('<hi',0,-1)+b'\0'*2
  b=b'pap '+b'\x01\x00\x02\x00'+struct.pack('<hHBBiii',1,424,1,0,26,66,74)+record+b'\0'*8
  with self.assertRaisesRegex(ValueError,'negative clip index'):pap_header(b)
 def test_body_two_preserved(self):
  self.assertIn('b0002',paths(424)['mdl']);self.assertIn('b0001',paths(424)['sklb'])
 def test_float32_and_huge_endpoints(self):
  for d in (struct.unpack('<f',struct.pack('<f',x))[0] for x in (.1,.2,1/30,10.1)):
   ts=sample_times(d,1);self.assertEqual(ts[-1],d);self.assertEqual(ts.count(d),1)
   self.assertTrue(all(a<b for a,b in zip(ts,ts[1:])))
  with self.assertRaises(ValueError):sample_times(1e308,1)
 def test_actual_sklb_magic_and_tagfile(self):
  tag=bytes.fromhex('1e0db0cacefa11d0')+b'\0'*16
  b=b'blks0031'+b'\0'*4+struct.pack('<H',16)+b'\0'*2+tag
  self.assertEqual(sklb_payload(b),tag)
  for bad in (b'sklb'+b[4:],b[:12]+b'\xff\xff'+b[14:],b[:16]+b'X'+tag[1:]):
   with self.assertRaises(ValueError):sklb_payload(bad)
 def test_supplement_pin_and_same_buffer(self):
  from sample_cinematic_paps import checked
  import hashlib
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'input';p.write_bytes(b'actual');pin={'sha256':hashlib.sha256(b'actual').hexdigest(),'bytes':6}
   self.assertEqual(checked(p,pin),b'actual')
   p.write_bytes(b'mutate')
   with self.assertRaises(ValueError):checked(p,pin)
 def test_actual_native_endpoint_aliases(self):
  for d,expected in ((2.2333333492279053,68),(.7333333492279053,23)):
   ts=sample_times(d,1);qs=[struct.unpack('<f',struct.pack('<f',v))[0] for v in ts]
   self.assertEqual(len(ts),expected);self.assertEqual(qs.count(d),1)
   self.assertEqual(qs[0],0);self.assertEqual(qs[-1],d)
   self.assertTrue(all(a<b for a,b in zip(qs,qs[1:])))
 def test_float32_grid_endpoints(self):
  for i in range(1,2001):
   d=struct.unpack('<f',struct.pack('<f',i/30))[0]
   qs=[struct.unpack('<f',struct.pack('<f',t))[0] for t in sample_times(d,1)]
   self.assertEqual(qs[0],0);self.assertEqual(qs[-1],d);self.assertEqual(qs.count(d),1)
   self.assertTrue(all(a<b for a,b in zip(qs,qs[1:])))
if __name__=='__main__':unittest.main()

