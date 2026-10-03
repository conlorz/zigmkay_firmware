#!/usr/bin/env python3
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import registry


class RegistryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.catalog = self.root / 'boards.json'
        self.output = self.root / 'generated.zig'
        (self.root / 'entry.zig').write_text('pub fn main() void {}\n')
        self.a = dict(name='a', source='entry.zig', split=False, encoder=False, companion=False)
        self.b = dict(self.a, name='b')

    def load(self, entries):
        self.catalog.write_text(json.dumps(entries))
        return registry.load(self.catalog, self.root)

    def test_order_is_deterministic(self):
        self.assertEqual(registry.render(self.load([self.a, self.b])), registry.render(self.load([self.b, self.a])))

    def test_duplicate(self):
        with self.assertRaisesRegex(ValueError, 'duplicate target: a'):
            self.load([self.a, self.a])

    def test_invalid_names(self):
        for name in ('', 'UPPER', 'a-b', 'a"'):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'invalid target name'):
                self.load([dict(self.a, name=name)])

    def test_paths(self):
        for source in ('/entry.zig', '../entry.zig', 'x/../../entry.zig', './entry.zig', 'x//entry.zig', 'a".zig'):
            with self.subTest(source=source), self.assertRaisesRegex(ValueError, 'invalid source path'):
                self.load([dict(self.a, source=source)])

    def test_missing_source(self):
        with self.assertRaisesRegex(ValueError, 'missing entry source for a'):
            self.load([dict(self.a, source='missing.zig')])

    def test_symlink_escape(self):
        (self.root / 'escape.zig').symlink_to(Path(__file__).resolve())
        with self.assertRaisesRegex(ValueError, 'escapes keyboard package'):
            self.load([dict(self.a, source='escape.zig')])

    def test_bootstrap_missing_output(self):
        registry.atomic_write(self.output, registry.render(self.load([self.a])))
        registry.compare(self.output, registry.render(self.load([self.a])))

    def test_changed_and_removed_entries_are_stale(self):
        original = registry.render(self.load([self.a, self.b]))
        self.output.write_bytes(original)
        for entries in ([self.a], [self.a, dict(self.b, encoder=True)]):
            with self.assertRaisesRegex(ValueError, 'stale registry'):
                registry.compare(self.output, registry.render(self.load(entries)))
        self.assertEqual(original, self.output.read_bytes())

    def test_missing_check_never_creates_output(self):
        with self.assertRaisesRegex(ValueError, 'missing registry'):
            registry.compare(self.output, registry.render(self.load([self.a])))
        self.assertFalse(self.output.exists())

    def test_interrupted_replace_preserves_output(self):
        self.output.write_bytes(b'original')
        with patch.object(registry.os, 'replace', side_effect=InterruptedError), self.assertRaises(InterruptedError):
            registry.atomic_write(self.output, b'new')
        self.assertEqual(b'original', self.output.read_bytes())
        self.assertFalse(list(self.root.glob('.generated.zig-*')))

    def test_empty_catalog(self):
        with self.assertRaisesRegex(ValueError, 'nonempty list'):
            self.load([])

    def test_metadata_is_typed(self):
        with self.assertRaisesRegex(ValueError, 'boolean'):
            self.load([dict(self.a, split='yes')])


if __name__ == '__main__':
    unittest.main()
