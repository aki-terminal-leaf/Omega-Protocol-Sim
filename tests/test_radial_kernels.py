"""Actual pinned source, float32 arithmetic, and diagnostic project contract tests."""
import hashlib, json, math, struct, sys, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/asset_lab"))
import prepare_radial_kernels as k

class RadialKernels(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest=k.validate(k.DEFAULT_INPUTS,k.EXPECTED)
        cls.original=Path(next(n for n in cls.manifest["readonly_files"] if n.endswith("/RadialBlur.shcd"))).parent
        cls.contract=json.loads((cls.original/"shcd-contract.json").read_bytes())

    def test_actual_shcd_dxbc_and_reflection(self):
        for row in self.contract:
            raw=(self.original/row["file"]).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row["sha256"])
            blob=raw[row["dxbc_offset"]:row["dxbc_offset"]+row["dxbc_size"]]
            self.assertEqual(blob[:4],b"DXBC")
            self.assertEqual(hashlib.sha256(blob).hexdigest(),row["dxbc_sha256"])
            self.assertEqual(struct.unpack_from("<I",blob,24)[0],len(blob))
            chunks={}
            for i in range(struct.unpack_from("<I",blob,28)[0]):
                offset=struct.unpack_from("<I",blob,32+4*i)[0]
                size=struct.unpack_from("<I",blob,offset+4)[0]
                self.assertLessEqual(offset+8+size,len(blob))
                chunks[blob[offset:offset+4]]=blob[offset+8:offset+8+size]
            self.assertIn(b"RDEF",chunks)
            self.assertIn(b"SHEX",chunks)
            if row["file"]=="RadialBlur.shcd":
                self.assertEqual(struct.unpack_from("<I",chunks[b"SHEX"],75*4)[0],0x07000038) # MUL, seven words
                self.assertEqual(struct.unpack_from("<I",chunks[b"SHEX"],80*4)[0],0x4001) # immediate32
                self.assertEqual(struct.unpack_from("<I",chunks[b"SHEX"],81*4)[0],0x3eaaaaab)
                self.assertIn(b"cRadialBlurParam",chunks[b"RDEF"])
            if row["file"]=="DonutMerge.shcd":
                self.assertIn(b"sMerge1",chunks[b"RDEF"])
                self.assertEqual([b["register"] for b in row["bindings"] if b["kind"]=="texture"],[0,1])
            if row["file"]=="VSSampling1.shcd":
                self.assertEqual(row["vertex_prefix_bytes"],8)
                self.assertIn(b"cParam",chunks[b"RDEF"])

    def test_original_instruction_order(self):
        radial=(self.original/"RadialBlur.dxbc.txt").read_text()
        ops=["itof r2.x", "mul r2.xy", "mul r2.x,", "mad r2.y", "mad_sat r2.xz", "mul r2.xz", "min r2.xz", "sample_indexable", "mad r1.xyzw", "div o0.xyzw"]
        positions=[radial.index(op) for op in ops]
        self.assertEqual(positions,sorted(positions))
        merge=(self.original/"DonutMerge.dxbc.txt").read_text()
        self.assertIn("min_sat r0.x",merge)
        self.assertNotIn("cb0[0].zzwz",merge)
        self.assertIn("cb0[0].zzwz",radial)
        vertex=(self.original/"VSSampling1.dxbc.txt").read_text()
        self.assertIn("vs_5_0",vertex)
        self.assertIn("-2.000000",vertex)

    def test_float32_order_weights_and_rgba(self):
        taps,total=k.radial_samples([.2,.8],[.8,.2,1.,.6],[.75,.5,.4,.3])
        self.assertEqual([w for _,w in taps],[1.,.75,.5,.25])
        self.assertEqual(total,2.5)
        self.assertEqual(taps[0][0],[k.f32(.15),k.f32(.3)])
        got=k.radial([.2,.8],[.8,.2,1.,.6],[.75,.5,.4,.3],lambda uv:[uv[0],uv[1],uv[0]*uv[1],.125])
        self.assertAlmostEqual(got[3],.125)
        self.assertNotEqual(got[0],got[1])
        self.assertEqual(k.THIRD,0.3333333432674407958984375)
        self.assertNotEqual(k.f32(.333333),k.THIRD)

    def test_merge_coordinate_distinction_strength_and_alpha(self):
        seen=[]
        def base(uv): seen.append(uv); return [.1,.2,.3,.4]
        def other(uv): return [.9,.8,.7,.6]
        args=([1.2,-.1],[.2,.3,.8,.6],[.4,.5,1.,0.],[.75,.8,.1,.1])
        self.assertEqual(k.merge(*args,base,other),list(map(k.f32,[.1,.2,.3,.4])))
        self.assertEqual(seen[-1],[.75,0.])
        self.assertLessEqual(k.radial_samples([1.2,-.1],[.4,.5,0.,0.],[.75,.8,.1,.1])[0][0][0][0],k.f32(.1))
        result=k.merge([.5,.5],[.2,.3,.8,.6],[.4,.5,.5,.75],[1.,1.,0.,0.],base,other)
        self.assertGreater(result[3],k.f32(.4))
        self.assertLess(result[3],k.f32(.6))
        self.assertNotEqual(k.merge_factor([.6,.6],[.2,.4,.8,.6],[.4,.5,1.,1.]),k.merge_factor([.6,.6],[.4,.2,.6,.8],[.4,.5,1.,1.]))

    def test_negative_float32_domains(self):
        for x in [math.inf,math.nan,1e39,-1e39]:
            with self.assertRaises(ValueError):k.f32(x)
        with self.assertRaises(ValueError):k.div(1.,1e-50)
        with self.assertRaises(ValueError):k.mul(3e38,2.)
        with self.assertRaises(ValueError):k.merge_factor([.2,.3],[0.,1.,1.,1.],[.5,.5,1.,1.])
        with self.assertRaises(ValueError):k.radial_samples([.1,.2],[.5,.5,1e39,1.],[1.]*4)

    def test_shader_surface_contract(self):
        radial=(k.ROOT/k.SOURCES[0]).read_text();merge=(k.ROOT/k.SOURCES[1]).read_text()
        for source in [radial,merge]:
            self.assertIn("blend_disabled",source)
            self.assertIn("filter_linear, repeat_disable",source)
            self.assertNotIn("textureLod",source)
            self.assertNotIn("source_color",source.split("uniform sampler2D")[1])
            self.assertNotIn("COLOR *=",source)
        self.assertIn("0.3333333432674407958984375",radial)
        self.assertIn("viewport.zw",radial)
        self.assertNotIn("viewport.zw",merge)
        self.assertIn("sum_rgba / sum_weight",radial)

    def test_diagnostics_are_nonuniform_and_portable(self):
        cases=k.cases()
        self.assertEqual(len(cases["cases"]),6)
        for spec in cases["textures"].values():
            self.assertEqual(len(spec["rgba8"]),spec["size"][0]*spec["size"][1]*4)
            self.assertGreater(len(set(spec["rgba8"][3::4])),20)
        for row in cases["cases"]:
            self.assertEqual(row["sampler_policy"],k.POLICY)
            self.assertIn("NOT_ORIGINAL",row["provenance"])

if __name__=="__main__":unittest.main()
