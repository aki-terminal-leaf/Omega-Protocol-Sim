"""Actual pinned source, float32 arithmetic, and diagnostic project contract tests."""
import hashlib, json, math, struct, sys, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/asset_lab"))
import prepare_radial_kernels as k

class RadialKernels(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest=k.validate(k.DEFAULT_INPUTS,k.EXPECTED)
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
        self.assertEqual(len(cases["cases"]),50)
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
        self.assertEqual(len(self.manifest["source_lf_sha256"]),105)
        self.assertEqual(len(self.manifest["new_files"]),9)
        self.assertNotIn(k.SOURCES[1],self.manifest["source_lf_sha256"])
        shader=(k.ROOT/k.SOURCES[0]).read_text()
        self.assertEqual(shader.count("texelFetch(s_input,"),4)
        self.assertIn("textureSize(s_input, 0)",shader)
        self.assertIn("period - 1 - r",shader)
        self.assertIn("return texture(s_input, coord)",shader)

    def test_point_exact_integer_boundaries_and_away_boundaries(self):
        pair=k.cases()["textures"]["pair"]
        # Independent table for floor(k) then integer MIRROR, including negatives.
        for integer,expected in [(-6,1),(-5,0),(-4,0),(-3,1),(-2,1),(-1,0),(0,0),(1,1),(2,1),(3,0),(4,0)]:
            got=k.point_sample(pair,[integer/2,0.])
            self.assertEqual(got,[k.div(v,255.) for v in pair["rgba8"][expected*4:expected*4+4]])
        self.assertEqual(k.point_sample(pair,[-.5,0.])[0],k.div(13,255.))
        self.assertNotEqual(k.point_sample(pair,[-.5,0.]),k.point_sample(pair,[.5,0.]))
        for coord,expected in [(-.5-1/128,1),(-.5+1/128,0),(-1/128,0),(1/128,0),(1-1/128,1),(1+1/128,1),(2-1/128,0),(2+1/128,0)]:
            self.assertEqual(k.point_sample(pair,[coord,0.])[0],k.div(pair["rgba8"][expected*4],255.))
        for bad in [float('nan'),float('inf'),16.01,1e39]:
            with self.assertRaises(ValueError): k.point_sample(pair,[bad,0.])
        for name in ["single","column","row","odd"]:
            spec=k.cases()["textures"][name]
            for uv in [[-16.,16.],[-.4375,.3125],[0.,1.],[2.,-.5]]:
                self.assertEqual(len(k.point_sample(spec,uv)),4)

    def test_mixed_distinguishes_both_alternatives_all_rgba_after_saturation(self):
        data=k.cases(); spec=data["textures"]["odd"]; other=data["textures"]["b"]
        row=next(r for r in data["cases"] if r["id"]=="mixed-odd-0.375")
        mixed=k.merge_image(row,spec,other)
        for alternative in [k.merge_image(row,spec,other,all_linear=True),k.merge_image(dict(row,sampler_policy=k.POLICY),spec,other)]:
            for c in range(4): self.assertNotEqual(mixed[c::4],alternative[c::4])
        positive=dict(row,radii=[abs(v) for v in row["radii"]])
        self.assertEqual(mixed,k.merge_image(positive,spec,other))
        # Explicit factors 0, 1, fractional; no sampler expectation derived from UV fold.
        for strength in [0.,1.,.375]:
            self.assertEqual(k.merge_factor([1.,0.],[1.,1.,2.,2.],[0.,0.,1.,strength]),strength)
        for r in data["cases"]:
            if r["kind"]=="merge":
                self.assertEqual(len(k.merge_image(r,data["textures"][r["s_input"]],data["textures"][r["s_merge"]])),4*math.prod(r["target_size"]))
        with self.assertRaises(ValueError): k.merge_image(dict(row,sampler_policy=k.MIRROR_POLICY),spec,other)

    def test_conditional_chain_quantized_forward_reverse(self):
        data=k.chain_cases(); case=data["cases"][0]
        def run(rows):
            textures=json.loads(json.dumps(data["textures"])); stages=[]
            for i,row in enumerate(rows):
                self.assertEqual(row["s_input"],["A","B","A","I"][i])
                self.assertEqual(row["output"],["B","A","B","output"][i])
                spec=textures[row["s_input"]]
                self.assertEqual(spec["size"],row["s_input_size"])
                rgba=(k.radial_image(row,spec) if i<3 else k.merge_image(row,spec,textures["B"]))
                self.assertTrue(all(type(x) is int and 0<=x<=255 for x in rgba))
                textures[row["output"]]={"size":row["target_size"],"rgba8":rgba}
                stages.append(rgba)
            return stages
        initial=run(case["initial"]); forward=run(case["forward"]); reverse=run(case["initial"])
        self.assertEqual(initial,reverse)
        for a,b in zip(initial,forward): self.assertNotEqual(a,b)
        ids=[r["id"] for r in k.cases()["cases"]]+[case["id"]]+[r["id"] for state in ["initial","forward"] for r in case[state]]
        self.assertEqual(len(ids),len(set(ids)))

if __name__=="__main__":unittest.main()
