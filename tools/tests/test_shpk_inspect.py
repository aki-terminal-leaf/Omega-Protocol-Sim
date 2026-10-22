import struct,subprocess,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]));from shpk_inspect import ShpkError,inspect
def dxbc():
 c=b"SHEX"+struct.pack("<I",4)+b"abcd";z=36+len(c);return b"DXBC"+bytes(16)+struct.pack("<III",1,z,1)+struct.pack("<I",36)+c
def sample(bad=0):
 b=dxbc();n=b"g_Test\0";h=bytearray(b"ShPk"+struct.pack("<I",0x0D01)+b"DX11"+b"\0"*12)
 h+=struct.pack("<IIIHHIHHIIIIII",1,1,0,0,0,0,0,0,0,1,0,0,1,0)+struct.pack("<III",0,0,0)
 rr=struct.pack("<IIHHHH",7,0,len(n),0,2,3);m=bytearray(struct.pack("<IIHHHHI",0,len(b)+8,1,0,0,0,1)+rr+struct.pack("<IIHHHHI",len(b)+8,len(b),0,0,0,0,4))
 m+=struct.pack("<II",0,0)+struct.pack("<II",8,9)+struct.pack("<II",9,1)+bytes(16)+struct.pack("<II",8,9)+struct.pack("<I",0)+struct.pack("<II",10,11)+struct.pack("<IIIIII",99,3 if bad else 0,0,0xffffffff,0xffffffff,0xffffffff)
 bo=len(h)+len(m);so=bo+8+2*len(b);struct.pack_into("<III",h,12,so+len(n),bo,so);return bytes(h+m+b"12345678"+b+b+n)
class Test(unittest.TestCase):
 def test_parse(self):
  x=inspect(sample());p=x["programs"]["vertex"][0];self.assertEqual(p["bindings"]["constants"][0]["name"],"g_Test");self.assertEqual(p["bindings"]["constants"][0]["size"],3);self.assertEqual(p["bytecode"]["chunks"][0]["fourcc"],"SHEX");self.assertEqual(x["nodes"][0]["passes"][0]["pixel"],0)
 def test_truncated(self):
  with self.assertRaises(ShpkError):inspect(sample()[:7])
 def test_version(self):
  b=sample();
  with self.assertRaisesRegex(ShpkError,"unsupported ShPk version"):inspect(b[:4]+struct.pack("<I",0xF01)+b[8:])
 def test_reference(self):
  with self.assertRaisesRegex(ShpkError,"missing vertex shader"):inspect(sample(1))
 def test_dxbc_integrity(self):
  b=bytearray(sample());bo=struct.unpack_from("<I",b,16)[0];struct.pack_into("<I",b,bo+8+24,999)
  with self.assertRaisesRegex(ShpkError,"declared size"):inspect(bytes(b))
 def test_dxbc_chunk_cannot_alias_header_or_another_chunk(self):
  from shpk_inspect import dxbc as decode
  original=bytearray(dxbc());struct.pack_into("<I",original,32,4)
  with self.assertRaisesRegex(ShpkError,"outside payload"):decode(bytes(original),required=True)
  with self.assertRaisesRegex(ShpkError,"not DXBC"):decode(b"not a shader",required=True)
  overlapping=b"DXBC"+bytes(16)+struct.pack("<III",1,52,2)+struct.pack("<II",40,40)+b"SHEX"+struct.pack("<I",4)+b"abcd"
  with self.assertRaisesRegex(ShpkError,"overlapping DXBC"):decode(overlapping,required=True)
 def test_negative_extract_index_does_not_create_output(self):
  with tempfile.TemporaryDirectory()as td:
   src,out=Path(td)/"x.shpk",Path(td)/"x.dxbc";src.write_bytes(sample())
   cmd=[sys.executable,str(Path(__file__).parents[1]/"shpk_inspect.py"),str(src),"--extract-stage","pixel","--extract-index","-1","--output",str(out)]
   self.assertNotEqual(subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10).returncode,0)
   self.assertFalse(out.exists())
 def test_extract_exclusive(self):
  with tempfile.TemporaryDirectory()as td:
   src,out=Path(td)/"x.shpk",Path(td)/"x.dxbc";src.write_bytes(sample());cmd=[sys.executable,str(Path(__file__).parents[1]/"shpk_inspect.py"),str(src),"--extract-stage","pixel","--extract-index","0","--output",str(out)];self.assertEqual(subprocess.run(cmd,stdout=subprocess.DEVNULL).returncode,0);self.assertTrue(out.read_bytes().startswith(b"DXBC"));self.assertNotEqual(subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode,0)
if __name__=="__main__":unittest.main()
