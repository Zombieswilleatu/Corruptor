#!/usr/bin/env python3
"""Compare native launch export with Python authority, including fallback/Breach."""
import json
import sys
from u13_pysim.kroni_actors import create

rows = json.load(open(sys.argv[1]))
for row in rows:
    actual = create('cross-runtime', row['owner'], 2, row['hunger'], row['breach'], row['seed'], row['start'], row['units'])
    assert actual == row['actor'], (row, actual)
print(f'Kroni native/Python launch parity: {len(rows)} cases passed')
