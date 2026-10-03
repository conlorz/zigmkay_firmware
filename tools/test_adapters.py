#!/usr/bin/env python3
"""Exercise offline executables through real process and temporary-file I/O."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

COMPANION, FIXTURE, GENERATOR, CHECKER = map(lambda p: Path(p).resolve(), sys.argv[1:5])
sys.argv = sys.argv[:1]


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.trace = FIXTURE.read_bytes()

    def replay(self, data, expected=0):
        source = self.root / 'reports.bin'
        source.write_bytes(data)
        result = subprocess.run([COMPANION, source], cwd=self.root, capture_output=True, text=True, timeout=15)
        self.assertEqual(expected, result.returncode, result.stderr)
        return result

    def test_literal_trace_final_state(self):
        self.assertEqual('board=lk7\nkeys=34\nlayers=4\nreports=8\npressed=[]\nactive_layers=1\nhighest_layer=0\nmodifiers=0x00\nlast_sequence=7\nneeds_resync=false\n', self.replay(self.trace).stdout)

    def test_trace_intermediate_state(self):
        state = self.replay(self.trace[:4*32]).stdout
        self.assertIn('pressed=[30]\nactive_layers=3\nhighest_layer=1', state)

    def test_modifier_state_uses_reducer(self):
        report = bytearray(self.trace[:32])
        report[11] = 0x22
        self.assertIn('pressed=[0]', self.replay(report).stdout)
        self.assertIn('modifiers=0x22', self.replay(report).stdout)

    def test_empty_session(self):
        self.assertIn('reports=0\npressed=[]', self.replay(b'').stdout)
        self.assertIn('last_sequence=none', self.replay(b'').stdout)

    def test_truncated_report(self):
        self.assertIn('complete 32-byte boundaries', self.replay(self.trace[:-1], 1).stderr)

    def test_invalid_report(self):
        for index, value in ((0, 0), (1, 2), (2, 99), (8, 2), (9, 127), (31, 1)):
            with self.subTest(index=index):
                report = bytearray(self.trace[:32])
                report[index] = value
                self.assertIn('Replay report 0 at byte 0', self.replay(report, 1).stderr)

    def test_sequence_duplicate_and_gap(self):
        for sequence in (0, 3):
            with self.subTest(sequence=sequence):
                reports = bytearray(self.trace[:64])
                reports[36] = sequence
                self.assertIn('SequenceDiscontinuity', self.replay(reports, 1).stderr)

    def test_missing_file_and_arguments(self):
        for args in ([], [self.root / 'missing.bin']):
            result = subprocess.run([COMPANION, *args], capture_output=True, text=True, timeout=15)
            self.assertEqual(1, result.returncode)
            self.assertTrue('Usage:' in result.stderr or 'FileNotFound' in result.stderr)

    def test_generator_failure_preserves_existing_and_missing_outputs(self):
        source = self.root / 'keycodes_0.0.1_basic.hjson'
        output = self.root / 'output.zig'
        for content in ('{}', '{"0x0004": {"key": "KC_A"', 'not hjson'):
            source.write_text(content)
            for existing in (True, False):
                with self.subTest(content=content, existing=existing):
                    if existing: output.write_bytes(b'original')
                    else: output.unlink(missing_ok=True)
                    result = subprocess.run([GENERATOR, source, output], capture_output=True, text=True, timeout=15)
                    self.assertNotEqual(0, result.returncode)
                    if existing: self.assertEqual(b'original', output.read_bytes())
                    else: self.assertFalse(output.exists())
        result = subprocess.run([GENERATOR], capture_output=True, text=True, timeout=15)
        self.assertNotEqual(0, result.returncode)
        self.assertIn('Usage:', result.stderr)

    def test_keycode_stale_missing_extra_and_index_checks_are_read_only(self):
        committed = self.root / 'keycodes'
        committed.mkdir()
        generated = self.root / 'cache.zig'
        generated.write_bytes(b'expected')
        args = [sys.executable, '-B', CHECKER, committed, 'all.zig', generated]
        for state in ('missing', 'stale', 'extra', 'matching'):
            with self.subTest(state=state):
                for file in committed.iterdir(): file.unlink()
                if state != 'missing':
                    (committed / 'all.zig').write_bytes(b'stale' if state == 'stale' else b'expected')
                if state == 'extra': (committed / 'extra.zig').write_bytes(b'extra')
                before = {p.name: p.read_bytes() for p in committed.iterdir()}
                result = subprocess.run(args, capture_output=True, text=True, timeout=15)
                self.assertEqual(0 if state == 'matching' else 1, result.returncode)
                self.assertEqual(before, {p.name: p.read_bytes() for p in committed.iterdir()})
                if state != 'matching': self.assertIn(state, result.stderr)


if __name__ == '__main__':
    unittest.main()
