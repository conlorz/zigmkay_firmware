#!/usr/bin/env python3
"""Regress source-inventory and early compiler-pin validation boundaries."""
from pathlib import Path
import os
import runpy
import subprocess
import sys
import tempfile
import unittest

WRAPPER = Path(__file__).with_name('check-local')
SOURCES = runpy.run_path(str(WRAPPER))['sources']


class LocalCheckTests(unittest.TestCase):
    def test_ignored_source_additions_and_deletions_are_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.gitignore').write_text('src/ignored.zig\n')
            (root / 'src').mkdir()
            before = SOURCES(root)
            file = root / 'src/ignored.zig'
            file.write_text('pub const added = true;\n')
            added = SOURCES(root)
            self.assertNotEqual(before, added)
            file.unlink()
            self.assertEqual(before, SOURCES(root))

    def test_only_explicit_output_locations_are_excluded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'src').mkdir()
            (root / 'src/main.zig').write_text('source')
            before = SOURCES(root)
            for output in ('.zig-cache', 'zig-out', 'zig-pkg', 'docs/evidence', '__pycache__'):
                location = root / output
                location.mkdir(parents=True)
                (location / 'output').write_bytes(b'cache')
            self.assertEqual(before, SOURCES(root))
            (root / 'src/main.zig').write_text('changed')
            self.assertNotEqual(before, SOURCES(root))

    def test_wrong_compiler_is_rejected_before_any_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            compiler = root / 'fake-zig'
            marker = root / 'build-executed'
            compiler.write_text('#!' + sys.executable + '\nimport sys\nfrom pathlib import Path\nif sys.argv[1:] == ["version"]: print("0.15.2")\nelse: Path(' + repr(str(marker)) + ').write_text("build")\n')
            compiler.chmod(0o755)
            result = subprocess.run([sys.executable, '-B', WRAPPER], env=dict(os.environ, ZIG_BIN=str(compiler)), capture_output=True, text=True)
            self.assertEqual(2, result.returncode)
            self.assertIn('Expected Zig 0.16.0, got 0.15.2', result.stderr)
            self.assertFalse(marker.exists())


if __name__ == '__main__':
    unittest.main()
