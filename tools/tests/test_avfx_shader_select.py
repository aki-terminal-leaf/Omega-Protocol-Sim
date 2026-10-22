import pathlib,sys,unittest,weakref,gc,tempfile,subprocess,json,struct
TOOLS=pathlib.Path(__file__).parents[1];sys.path.insert(0,str(TOOLS))
from avfx_shader_select import build_exact_index,describe_scene,load_names,select_nodes,semantic,ConstraintError
from shpk_inspect import inspect
DB={"keys":{"0x00000001":"K","0x00000002":"A","0x00000003":"B"},"passes":{"0x00000009":"P"}}
def node(i,val,vs,ps):return {"index":i,"selector":100+i,"keys":{"scene":[val]},"passes":[{"id":9,"vertex":vs,"pixel":ps,"hull":0xffffffff,"domain":0xffffffff,"geometry":0xffffffff}]}
def meta(nodes=None,keys=None):return {"keys":{"scene":keys or [{"id":1,"default":2}]},"nodes":nodes or [],"aliases":[]}
class Synthetic(unittest.TestCase):
 def test_unknown_names_and_explicit_unknown(self):
  self.assertEqual(select_nodes(meta([node(0,0xdeadbeef,1,2)]),{"K":"wat"},db=DB)["status"],"invalid")
  self.assertEqual(select_nodes(meta([node(0,0xdeadbeef,1,2)]),{"K":"0xDEADBEEF"},db=DB)["status"],"match")
 def test_invalid_value(self):
  self.assertEqual(select_nodes(meta([node(0,2,1,2)]),{"K":-1},db=DB)["status"],"invalid")
 def test_ambiguous_and_no_match(self):
  m=meta([node(0,2,1,2),node(1,2,3,4)])
  self.assertEqual(select_nodes(m,{"K":"A"},db=DB)["status"],"ambiguous")
  self.assertEqual(select_nodes(m,{"K":"B"},db=DB)["status"],"no_match")
 def test_exact_vector_preserves_program_refs(self):
  r=select_nodes(meta([node(0,2,7,8)]),exact_vector=["A"],db=DB)
  self.assertEqual(r["matches"][0]["passes"][0]["programs"]["vertex"],7)
  self.assertEqual(r["matches"][0]["passes"][0]["programs"]["pixel"],8)
  self.assertEqual(r["package"]["scene_key_ids"],[1])
  self.assertIsNone(r["package"]["source_sha256"])
 def test_package_schemas_are_independent(self):
  # The same semantic key may occupy a different ordinal, with unrelated counts.
  short=meta([node(0,2,1,2)])
  long=meta([{"index":0,"selector":1,"keys":{"scene":[3,2]},"passes":[]}],
            [{"id":99,"default":3},{"id":1,"default":2}])
  self.assertEqual(select_nodes(short,{"K":"A"},db=DB)["status"],"match")
  self.assertEqual(select_nodes(long,{"K":"A"},db=DB)["resolved_constraints"][0]["ordinal"],1)
 def test_duplicate_key_ordinal_is_error(self):
  m=meta([{"index":0,"selector":1,"keys":{"scene":[2,2]},"passes":[]}],[{"id":1,"default":2},{"id":1,"default":2}])
  self.assertEqual(select_nodes(m,{"K":"A"},db=DB)["status"],"invalid")
  self.assertTrue(describe_scene(m,DB)["duplicate_key_ids"])
 def test_foreign_package_cache_cannot_return_wrong_shader_refs(self):
  first=meta([node(0,2,7,8)]);second=meta([node(0,2,90,91)])
  result=select_nodes(second,exact_vector=[2],exact_index=build_exact_index(first),db=DB)
  self.assertEqual(result["status"],"invalid")
  self.assertEqual(result["matches"],[])
 def test_conflicting_semantic_and_numeric_aliases_are_not_last_wins(self):
  result=select_nodes(meta([node(0,2,7,8)]),{"K":"A","0x00000001":"B"},db=DB)
  self.assertEqual(result["status"],"invalid")
 def test_detailed_description_is_explicitly_bounded(self):
  source=meta([node(i,2,7,8) for i in range(100)])
  description=describe_scene(source,DB)
  self.assertEqual(description["node_count"],100)
  self.assertEqual(description["nodes"],[])
  self.assertTrue(description["node_details_truncated"])
  self.assertEqual(description["semantic_coverage"]["node_value_count"],100)
  self.assertEqual(len(describe_scene(source,DB,node_details=2)["nodes"]),2)
  with self.assertRaises(ConstraintError):describe_scene(source,DB,node_details=65)
 def test_repeated_semantic_databases_are_actually_released(self):
  class Database(dict):pass
  refs=[]
  for _ in range(100):
   database=Database(DB);refs.append(weakref.ref(database));semantic(1,database)
  del database;gc.collect()
  self.assertLessEqual(sum(ref() is not None for ref in refs),1)
 def test_malformed_vector_is_invalid_not_an_uncaught_lookup_error(self):
  source=meta([node(0,2,7,8)]);source["nodes"][0]["keys"]["scene"]=[]
  self.assertEqual(select_nodes(source,{"K":"A"},db=DB)["status"],"invalid")
 def test_cli_requires_exact_package_vector_and_preserves_existing_report(self):
  from test_shpk_inspect import sample
  with tempfile.TemporaryDirectory() as temp:
   root=pathlib.Path(temp);source=root/"input.shpk";vector=root/"vector.json";output=root/"report.json"
   fixture=bytearray(sample())
   # Reclassify the fixture's one system-key record as one scene-key record;
   # byte count and node-vector width stay unchanged (ShPk header offsets52/56).
   struct.pack_into("<II",fixture,52,0,1)
   source.write_bytes(fixture);vector.write_text("[0]")
   command=[sys.executable,str(TOOLS/"avfx_shader_select.py"),str(source),"--exact-vector",str(vector),"--output",str(output)]
   good=subprocess.run(command,capture_output=True,text=True,timeout=10)
   self.assertEqual(good.returncode,0,good.stdout+good.stderr)
   self.assertEqual(json.loads(output.read_text())["status"],"match")
   proof=output.read_bytes()
   self.assertNotEqual(subprocess.run(command,capture_output=True,timeout=10).returncode,0)
   self.assertEqual(output.read_bytes(),proof)
   vector.write_text("[4294967295]")
   self.assertEqual(subprocess.run(command[:-2],capture_output=True,timeout=10).returncode,3)
class Corpus(unittest.TestCase):
 ROOT=pathlib.Path('/mnt/backup/vps-data/home/brewuser/.openclaw/workspace/main/artifacts/top-avfx-49027/shader-bundle/source/shader/sm5/shpk')
 def test_all_nodes_recover_from_own_vector(self):
  if not self.ROOT.exists():self.skipTest('external original-game corpus not available')
  coverage_by_package={};known={int(x,16) for x in load_names()["keys"]}
  for path in sorted(self.ROOT.glob('*.shpk')):
   m=inspect(path.read_bytes());idx=build_exact_index(m)
   coverage={"key_count":len(m["keys"]["scene"]),"known_key_count":sum(k["id"] in known for k in m["keys"]["scene"])}
   coverage_by_package[path.name]=coverage
   recovered=set()
   # Invoke the PUBLIC resolver for every original source node, not merely
   # iterate the index we just constructed or check one representative vector.
   for original in m["nodes"]:
    vector=original["keys"]["scene"]
    result=select_nodes(m,exact_vector=vector,exact_index=idx)
    self.assertIn(result["status"],("match","ambiguous"),path.name)
    matches={x["index"]:x for x in result["matches"]}
    self.assertIn(original["index"],matches,path.name)
    recovered.add(original["index"])
    for index,match in matches.items():
     source=m["nodes"][index]
     self.assertEqual(source["keys"]["scene"],vector)
     self.assertEqual([(p["programs"]["vertex"],p["programs"]["pixel"]) for p in match["passes"]],[(p["vertex"],p["pixel"]) for p in source["passes"]])
   self.assertEqual(recovered,{n["index"] for n in m["nodes"]})
   del m,idx
  self.assertEqual(len(coverage_by_package),15)
  self.assertTrue(all(v['known_key_count']<=v['key_count'] for v in coverage_by_package.values()))
