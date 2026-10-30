import copy
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/asset_lab'))
from decode_source_scene_events import SceneState, decode, records, f32


def target(r):
    return dict(verified=True, token='test-only-source-resolution', context='inspection', epoch=7,
                namespace=r['namespace'], current_native_scale=[2,3,4], state_byte=0xCF)


def modified(r, offset, fmt, value):
    r = copy.deepcopy(r)
    b = bytearray.fromhex(r['source_event']['raw_hex'])
    struct.pack_into('<'+fmt, b, offset, *value)
    r['source_event'].update(raw_hex=b.hex(), sha256=hashlib.sha256(b).hexdigest())
    return r


def vector_expected(angles, v):
    x,y,z = angles
    a,b,c = v
    b,c = math.cos(x)*b-math.sin(x)*c, math.sin(x)*b+math.cos(x)*c
    a,c = math.cos(y)*a+math.sin(y)*c, -math.sin(y)*a+math.cos(y)*c
    a,b = math.cos(z)*a-math.sin(z)*b, math.sin(z)*a+math.cos(z)*b
    return [a,b,c]


def rotate(q, v):
    x,y,z,w = q
    a,b,c = v
    tx,ty,tz = 2*(y*c-z*b),2*(z*a-x*c),2*(x*b-y*a)
    return [a+w*tx+y*tz-z*ty,b+w*ty+z*tx-x*tz,c+w*tz+x*ty-y*tx]


def cases(graph):
    actual = [r for r in records(graph) if r['source_event']['tag'] in ('C018','C196')]
    c18 = next(r for r in actual if r['source_event']['tag']=='C018')
    c196 = next(r for r in actual if r['source_event']['tag']=='C196')
    synthetic = [modified(c18,32,'6f',[.7,-1.1,2.2,9,8,7])]
    for n,d in [(math.nan,0),(1e10,2**-149),(0,0),(1,0),(1,-0.0),(-0.0,1)]:
        synthetic.append(modified(c196,24,'ff',[n,d]))
    for threshold in [16777219,-16777219,-2147483648]:
        synthetic.append(modified(c196,40,'i',[threshold]))
    synthetic.append(modified(c196,32,'II',[0xDEADBEEF,0x76543210]))
    return actual, synthetic


class ContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.graph=json.loads(Path(os.environ['SCENE_GRAPH']).read_text())
        cls.actual,cls.synthetic=cases(cls.graph)

    def test_all_actual_and_independent_rotation(self):
        self.assertEqual(len(self.graph['graphs']),15)
        self.assertEqual([sum(r['source_event']['tag']==tag for r in self.actual) for tag in ('C018','C196')],[41,24])
        self.assertEqual(len({tuple(r['namespace']) for r in self.actual}),65)
        for r in self.actual+self.synthetic:
            s=SceneState(); t=target(r); result=s.begin(r,t,7)
            if r['source_event']['tag']=='C018':
                self.assertEqual(result['scale'],[2,3,4])
                for v in ([1,0,0],[0,1,0],[0,0,1],[.3,-2,4]):
                    for a,b in zip(rotate(result['quaternion_xyzw'],v),vector_expected(decode(r)['euler'],v)):
                        self.assertAlmostEqual(a,b,places=12)
            else:
                self.assertEqual(result['descriptor']['unknown_padding'],[20,21,22,23,25,26,27])
                self.assertEqual([(x['offset'],x['width']) for x in result['descriptor']['writes']],[(0,4),(4,4),(8,8),(16,4),(24,1),(28,4),(32,4),(36,4)])
                threshold=decode(r)['threshold_f32']['value']
                self.assertEqual(s.update(threshold,t,7)['type'],'no_request')
                later=s.update(threshold+256,t,7)
                self.assertEqual(later['descriptor']['unknown_padding'],[2,3,10,11])
                self.assertEqual([(x['offset'],x['width']) for x in later['descriptor']['writes']],[(0,2),(4,4),(8,2),(12,8),(20,4),(24,4)])
                self.assertEqual(s.update(threshold+512,t,7)['type'],'no_request')

    def test_parent_counterexamples(self):
        values=[decode(r) for r in self.synthetic[1:7]]
        self.assertEqual([x['ratio']['status'] for x in values],['nan','infinite','nan','infinite','infinite','finite'])
        self.assertEqual(values[4]['ratio']['bits'],'000080ff')
        self.assertEqual(values[5]['ratio']['bits'],'00000080')
        r=self.synthetic[7]; s=SceneState(); t=target(r); s.begin(r,t,7)
        self.assertEqual(s.update(16777220,t,7)['type'],'no_request')
        self.assertEqual(s.update(16777222,t,7)['type'],'queued_action_request')
        r=self.synthetic[-1]; t=target(r); s=SceneState(); first=s.begin(r,t,7)
        self.assertEqual(first['descriptor']['writes'][6]['value'],0xDEADBEEF)
        self.assertEqual(s.update(11,t,7)['descriptor']['writes'][4]['value'],0x76543210)

    def test_fail_closed_and_retention(self):
        r=next(r for r in self.actual if r['source_event']['tag']=='C196'); t=target(r); s=SceneState()
        s.begin(r,t,7)
        self.assertEqual(s.update(1,t,7)['type'],'no_request')
        self.assertEqual(s.update(10,t,7)['type'],'no_request')
        for clock in [math.nan,math.inf,9]:
            with self.assertRaises(ValueError): s.update(clock,t,7)
        self.assertEqual(s.update(11,t,7)['type'],'queued_action_request')
        s.reset(); self.assertIsNone(s.target)
        for bad in [None,{},dict(t,epoch=8),dict(t,namespace=['collision'])]:
            s.begin(r,t,7)
            with self.assertRaises(ValueError): s.begin(r,bad,7)
            self.assertIsNone(s.target)
        s.begin(r,t,7)
        with self.assertRaises(ValueError): s.update(11,dict(t,token='remapped'),7)
        self.assertIsNone(s.target)
        for bad in [modified(r,20,'I',[2]),modified(r,4,'I',[55]),modified(r,8,'H',[0])]:
            with self.assertRaises(ValueError): s.begin(bad,t,7)
            self.assertIsNone(s.target)
        bad=copy.deepcopy(r); bad['source_event']['sha256']='0'*64
        with self.assertRaises(ValueError): decode(bad)
        bad=copy.deepcopy(r); bad['source_event']['tag']='C040'
        with self.assertRaisesRegex(ValueError,'unsupported'): decode(bad)
        other=copy.deepcopy(r); other['namespace'][1]+=1
        self.assertNotEqual(decode(r)['namespace'],decode(other)['namespace'])
        with self.assertRaises(ValueError): s.begin(other,t,7)

if __name__=='__main__': unittest.main()
