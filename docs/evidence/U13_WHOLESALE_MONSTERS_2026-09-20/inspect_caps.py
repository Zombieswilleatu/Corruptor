"""Replay only capped army fixtures, preserving their original 16-round result."""
import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--sim-dir', type=Path, required=True)
parser.add_argument('--directory', type=Path, required=True)
a = parser.parse_args()
sys.path.insert(0, str(a.sim_dir.resolve()))
from audit_u13_monsters import read_rows, resolve, finish, canonical_owner, name, fort, codec

source = json.load(gzip.open(a.directory/'armies.json.gz', 'rt'))
expected = {(b['case'], b['seed_index']): b for b in source['battles'] if b['round_cap'] and not b['reflected']}
reports = []
with (a.directory/'caps-parity.jsonl').open('w') as samples:
 for record in read_rows(a.directory/'army-initials.jsonl'):
  key = (record['case'], record['seed_index'])
  if record['reflected'] or key not in expected: continue
  world, seed = record['world'], record['seed']
  goals, seen = [0, 0], [set(), set()]
  states = []
  for offset in range(32):
   number = record['round']+offset
   capture = offset == 16
   raw = codec.loads(codec.dumps(world)) if capture else None
   result = resolve(world, seed, number, capture)
   if capture:
    samples.write(codec.dumps(dict(name=f"cap:{record['case']}:{seed}:{number}", world=raw, seed=seed, round=number, result_sha256=hashlib.sha256(codec.dumps(result).encode()).hexdigest()))+'\n')
   counts = Counter(e['event']['type'] for e in result['events'] if e['event']['type'] != 'MARCHING_TICK')
   world = finish(result, goals, seen, False)
   forces = [sum(canonical_owner(r, False) == pid for r in world['entities']['entities']+fort.rows(world)) for pid in (0, 1)]
   terminal = not all(forces) or not world['entities']['entities']
   if offset == 15: assert hashlib.sha256(codec.dumps(world).encode()).hexdigest() == expected[key]['final_sha256'], key
   if offset >= 14:
    states.append(dict(interval=offset+1, round=number, events=dict(counts), goals=list(goals), units=codec.loads(codec.dumps(world['entities']['entities'])), fortifications=codec.loads(codec.dumps(fort.rows(world))), pending_beams=codec.loads(codec.dumps(world['data']['monsters']['pending_beams']))))
   if terminal and not world['data']['monsters']['pending_beams']: break
  reports.append(dict(case=key[0], seed_index=key[1], intervals=offset+1, terminal=terminal, states=states))
  print(key, 'intervals', offset+1, 'terminal', terminal, 'units', [(r['owner'],name(r),r['attributes'].get('sprite_form'),r['attributes'].get('x_fp'),r['attributes'].get('y_fp')) for r in world['entities']['entities']], 'fortifications', len(fort.rows(world)), flush=True)
(a.directory/'caps-inspection.json').write_text(json.dumps(dict(original_caps=len(expected), replays=reports), indent=2)+'\n')
assert len(reports) == len(expected) == 5
