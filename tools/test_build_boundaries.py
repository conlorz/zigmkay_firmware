#!/usr/bin/env python3
"""Check real root selection diagnostics without compiling firmware for negative cases."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

ZIG, ROOT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
sys.argv = sys.argv[:1]


class BuildBoundaries(unittest.TestCase):
    def run_build(self, flags, expected=1):
        result = subprocess.run([ZIG, 'build', '-j4', *flags], cwd=ROOT, capture_output=True, text=True, timeout=60)
        self.assertEqual(expected, result.returncode, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def test_selection_is_required_only_by_selected_steps(self):
        for step in ('firmware', 'companion'):
            with self.subTest(step=step):
                text = self.run_build([step])
                self.assertIn('Missing -Dkeyboard', text)
                self.assertIn('available IDs:', text)
                self.assertIn('lk7', text)
                self.assertNotIn('compile exe zigmkay', text)

    def test_unknown_target_is_actionable(self):
        for step in ('firmware', 'companion'):
            with self.subTest(step=step):
                text = self.run_build([step, '-Dkeyboard=does_not_exist'])
                self.assertIn("Unknown keyboard 'does_not_exist'", text)
                self.assertIn('available IDs:', text)

    def test_unsupported_companion_is_explicit(self):
        self.assertIn("Unsupported companion board 'yak'; supported companion IDs: lk7", self.run_build(['companion', '-Dkeyboard=yak']))

    def test_listing_matches_catalog_and_unique_artifact_paths(self):
        entries = json.loads((ROOT / 'keyboards/boards.json').read_text())
        text = self.run_build(['list-keyboards'], 0)
        actual = [line.split(':')[0] for line in text.splitlines() if ': companion=' in line]
        self.assertEqual(sorted(e['name'] for e in entries), actual)
        destinations = [f"firmware/{name}/zigmkay.uf2" for name in actual]
        self.assertEqual(10, len(set(destinations)))
        self.assertIn('lk7: companion=lk7 offline', text)

    def test_flash_placeholder_fails_explicitly(self):
        self.assertIn('flash is not implemented in phase 2', self.run_build(['flash', '-Dkeyboard=lk7']))


if __name__ == '__main__':
    unittest.main()
