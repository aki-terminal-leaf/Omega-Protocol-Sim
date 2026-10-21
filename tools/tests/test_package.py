import contextlib
import io
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location("top_package",Path(__file__).parents[1]/"package.py")
package=importlib.util.module_from_spec(spec); spec.loader.exec_module(package)

class PackageEvidenceTests(unittest.TestCase):
    def test_runtime_patch_not_hardcoded(self):
        for version in ["4.4.1","4.7.2"]:
            with self.subTest(version=version), patch.object(package.subprocess,"run",return_value=subprocess.CompletedProcess([],0,version+".stable.official.hash\n","")):
                self.assertEqual(package.engine_version("godot")[0],version)

    def test_unstable_binary_rejected(self):
        with patch.object(package.subprocess,"run",return_value=subprocess.CompletedProcess([],0,"4.8.dev1.official.hash","")):
            with self.assertRaises(SystemExit): package.engine_version("godot")

    def test_exit_zero_script_error_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            target=Path(d)/"index.html"; target.write_text("stale output")
            with patch.object(package.subprocess,"run",return_value=subprocess.CompletedProcess([],0,"SCRIPT ERROR: Parse Error: invalid source\n")):
                with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit): package.export_checked("godot",Path(d),"Web",target)

    def test_missing_or_nonzero_export_rejected(self):
        for code in [0,1]:
            with self.subTest(code=code), tempfile.TemporaryDirectory() as d, patch.object(package.subprocess,"run",return_value=subprocess.CompletedProcess([],code,"")):
                with self.assertRaises(SystemExit): package.export_checked("godot",Path(d),"Web",Path(d)/"index.html")

if __name__=="__main__":unittest.main()
