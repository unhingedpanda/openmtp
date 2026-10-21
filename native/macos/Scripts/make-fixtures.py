#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('root', type=Path)
a = p.parse_args()
manifest = {}
for count in [1000, 10000]:
    directory = a.root / str(count)
    directory.mkdir(parents=True, exist_ok=True)
    for index in range(count):
        (directory / f'file-{index:05}.txt').write_bytes(b'OpenMTP native fixture\n')
    manifest[str(count)] = str(directory.resolve())
a.root.joinpath('manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest))
