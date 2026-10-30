import sys
sys.dont_write_bytecode=True
import copy, pathlib, unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools/asset_lab'))
from prepare_ring_action import trace, read, validate, EXPECTED
MANIFEST=pathlib.Path('D:/Dev/OpenClawCodexBridge/probes/top-one-action-50954/inputs/inputs.json')
class RingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m=validate(MANIFEST,EXPECTED); cls.pack=read(pathlib.Path(cls.m['cache_root'])/cls.m['pack_file'])
    def test_exact_graph(self):
        t=trace(self.pack)
        self.assertEqual(t['supported_last_death'],90)
        self.assertEqual({p['particle'] for p in t['particles']},set(range(10)))
        self.assertFalse(t['original_lifetime_finite'])
        self.assertEqual(sum(x['classification']=='unreachable' for x in t['flags']),12)
        self.assertEqual(sum(x['classification']=='disabled' and '/TN/' in x['path'] for x in t['flags']),10)
    def test_pin_counterexample(self):
        with self.assertRaises(ValueError): validate(MANIFEST,'0'*64)
    def test_lifetime_counterexamples(self):
        for change in ['loop','negative','nan','cycle','reference']:
            p=copy.deepcopy(self.pack)
            if change=='loop': p['groups']['TmLn'][0]['values']['LpEd']=10
            if change=='negative': p['groups']['Emit'][1]['life']['Val']=-1
            if change=='nan': p['groups']['Emit'][1]['life']['Val']=float('nan')
            if change=='cycle': p['groups']['Emit'][1]['items'][0]['values']['TgtB']=1
            if change=='reference': p['groups']['Emit'][1]['items'][0]['values']['TgtB']=99
            with self.subTest(change=change), self.assertRaises(ValueError): trace(p)
if __name__=='__main__': unittest.main()
