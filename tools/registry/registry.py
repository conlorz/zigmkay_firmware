#!/usr/bin/env python3
"""Bootstrap or check the deterministic board registry independently of the Zig graph."""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tempfile


def load(catalog, root):
    entries = json.loads(catalog.read_text())
    if not isinstance(entries, list) or not entries:
        raise ValueError('catalog must be a nonempty list')
    seen = set()
    root = root.resolve()
    for entry in entries:
        if set(entry) != {'name', 'source', 'split', 'encoder', 'companion'}:
            raise ValueError('entry requires name, source, split, encoder, companion')
        name, source = entry['name'], entry['source']
        if not isinstance(name, str) or not re.fullmatch(r'[a-z][a-z0-9_]*', name):
            raise ValueError(f'invalid target name: {name!r}')
        if name in seen:
            raise ValueError(f'duplicate target: {name}')
        seen.add(name)
        if not isinstance(source, str) or not re.fullmatch(r'[a-zA-Z0-9_/.-]+\.zig', source):
            raise ValueError(f'invalid source path for {name}: {source!r}')
        path = PurePosixPath(source)
        if path.is_absolute() or any(part in ('.', '..') for part in source.split('/')) or str(path) != source:
            raise ValueError(f'invalid source path for {name}: {source}')
        resolved = (root / source).resolve()
        if not resolved.is_relative_to(root):
            raise ValueError(f'source escapes keyboard package: {source}')
        if not resolved.is_file():
            raise ValueError(f'missing entry source for {name}: {source}')
        for field in ('split', 'encoder', 'companion'):
            if not isinstance(entry[field], bool):
                raise ValueError(f'{field} must be boolean for {name}')
    return sorted(entries, key=lambda entry: entry['name'])


def render(entries):
    text = '// Generated from boards.json by tools/registry/registry.py. Do not edit.\n'
    text += 'pub const Entry = struct {\n    name: []const u8,\n    source: []const u8,\n    split: bool,\n    encoder: bool,\n    companion: bool,\n};\n\npub const entries = [_]Entry{\n'
    for entry in entries:
        fields = ', '.join(f'.{field} = {json.dumps(entry[field])}' for field in ('name', 'source', 'split', 'encoder', 'companion'))
        text += '    .{ ' + fields + ' },\n'
    return (text + '};\n').encode()


def atomic_write(output, data):
    output.parent.mkdir(parents=True, exist_ok=True)
    # Replacement happens only after the complete output is closed and synced.
    fd, temporary = tempfile.mkstemp(prefix='.' + output.name + '-', dir=output.parent)
    try:
        with os.fdopen(fd, 'wb') as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, output)
    finally:
        Path(temporary).unlink(missing_ok=True)


def compare(output, data):
    if not output.is_file():
        raise ValueError(f'missing registry: {output}; run the independent registry bootstrap command')
    if output.read_bytes() != data:
        raise ValueError(f'stale registry: {output}; regenerate explicitly with tools/registry/registry.py')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--compare', type=Path, help='Compare cache output with the committed registry')
    args = parser.parse_args()
    if args.compare:
        compare(args.compare, args.output.read_bytes())
        return
    data = render(load(args.catalog, args.root))
    if args.check:
        compare(args.output, data)
    else:
        atomic_write(args.output, data)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        sys.exit(f'registry: {error}')
