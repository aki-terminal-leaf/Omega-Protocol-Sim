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
            self.assertNotIn("source_color",source.split("uniform sampler2D")[1])
            self.assertNotIn("COLOR *=",source)
        self.assertIn("0.3333333432674407958984375",radial)
        self.assertIn("viewport.zw",radial)
        self.assertNotIn("viewport.zw",merge)
        self.assertIn("sum_rgba / sum_weight",radial)

    def test_diagnostics_are_nonuniform_and_portable(self):
        cases=k.cases()
        self.assertEqual(len(cases["cases"]),22)
        for spec in cases["textures"].values():
            self.assertEqual(len(spec["rgba8"]),spec["size"][0]*spec["size"][1]*4)
            self.assertGreaterEqual(len(set(spec["rgba8"][3::4])),min(5,spec["size"][0]*spec["size"][1]))
        for row in cases["cases"]:
            self.assertIn(row["sampler_policy"],k.POLICIES)
            self.assertIn("NOT_ORIGINAL",row["provenance"])

    def test_mirror_texel_centers_seams_and_independent_fold(self):
        # Independent continuous triangle mapping, followed by CLAMP bilinear.
        # Dyadic coordinates are exact here, avoiding fold/ALU rounding ambiguity.
        coords=[-16.,-15.75,-3.,-2.,-1.,0.,1.,2.,3.,15.75,16.]
        coords += [seam+d for seam in [-2.,-1.,0.,1.,2.] for d in [-1/1024,1/1024]]
        for spec in k.cases()["textures"].values():
            for x in coords:
                for y in coords:
                    folded=[1.-abs((v%2.)-1.) for v in [x,y]]
                    actual=k.linear_sample(spec,[x,y],k.MIRROR_POLICY)
                    expected=k.linear_sample(spec,folded,k.POLICY)
                    for a,b in zip(actual,expected): self.assertAlmostEqual(a,b,places=6)
            width,height=spec["size"]
            for y in range(height):
                for x in range(width):
                    uv=[(x+.5)/width,(y+.5)/height]
                    got=k.linear_sample(spec,uv,k.MIRROR_POLICY)
                    expected=[k.div(v,255.) for v in spec["rgba8"][4*(y*width+x):4*(y*width+x)+4]]
                    for a,b in zip(got,expected): self.assertAlmostEqual(a,b,places=6)
        with self.assertRaises(ValueError): k.linear_sample(spec,[0.,0.],None)

    def test_mirror_edge_duplication_and_singleton(self):
        spec={"size":[2,1],"rgba8":[0,20,40,60,255,220,200,180]}
        for coord in [-.25,0.,.25,1.75,2.,2.25]:
            self.assertEqual(k.linear_sample(spec,[coord,-16.],k.MIRROR_POLICY)[0],0.)
        for coord in [.75,1.,1.25]:
            self.assertEqual(k.linear_sample(spec,[coord,16.],k.MIRROR_POLICY)[0],1.)
        self.assertEqual(k.linear_sample(spec,[.5,0.],k.MIRROR_POLICY)[0],.5)
        singleton=k.cases()["textures"]["single"]
        self.assertEqual(k.linear_sample(singleton,[-15.9,15.9],k.MIRROR_POLICY),
                         [k.div(v,255.) for v in singleton["rgba8"]])

    def test_full_rgba_radial_counterexample_after_kernel_clamp(self):
        fixtures=k.cases(); spec=fixtures["textures"]["odd"]
        row=next(c for c in fixtures["cases"] if c["id"]=="odd-"+k.MIRROR_POLICY+"-1")
        mirror=k.radial_image(row,spec)
        clamp=k.radial_image(dict(row,sampler_policy=k.POLICY),spec)
        self.assertEqual(len(mirror),9*7*4)
        for channel in range(4): self.assertNotEqual(mirror[channel::4],clamp[channel::4])
        taps,_=k.radial_samples([.9,.8],row["radial"],row["viewport"])
        self.assertTrue(any(max(c)>1. for c,w in taps))
        negative=dict(row,viewport=[-16.,-16.,16.,16.])
        self.assertNotEqual(k.radial_image(negative,spec),k.radial_image(dict(negative,sampler_policy=k.POLICY),spec))

    def test_manifest_partition_and_sampler_surface(self):
        self.assertEqual(len(self.manifest["source_lf_sha256"]),106)
        self.assertEqual(len(self.manifest["new_files"]),8)
        self.assertIn(k.SOURCES[1],self.manifest["source_lf_sha256"])
        shader=(k.ROOT/k.SOURCES[0]).read_text()
        self.assertEqual(shader.count("texelFetch(s_input,"),4)
        self.assertIn("textureSize(s_input, 0)",shader)
        self.assertIn("period - 1 - r",shader)
        self.assertIn("return texture(s_input, coord)",shader)

if __name__=="__main__":unittest.main()
