#!/usr/bin/env python3
"""Compare every cache-generated output, including the export index, without writing sources."""
import sys
from pathlib import Path

def check(directory, expected):
    actual = {p.name for p in directory.glob('*.zig')}
    wanted = set(expected)
    errors = [f"missing generated file: {name}" for name in sorted(wanted - actual)]
    errors += [f"extra generated file: {name}" for name in sorted(actual - wanted)]
    for name in sorted(wanted & actual):
        if (directory / name).read_bytes() != expected[name].read_bytes():
            errors.append(f"stale generated file: {name}")
    if errors:
        raise ValueError('; '.join(errors) + '; run zig build convert-all explicitly')

if __name__ == '__main__':
    try:
        args = sys.argv[2:]
        if len(args) % 2: raise ValueError('expected output name/path pairs')
        check(Path(sys.argv[1]), {args[i]: Path(args[i+1]) for i in range(0, len(args), 2)})
    except (ValueError, OSError) as error:
        sys.exit(str(error))
