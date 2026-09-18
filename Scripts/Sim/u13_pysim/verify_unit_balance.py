"""Export explicit audit cases, then compare their complete native phase results.

Usage: python -m u13_pysim.verify_unit_balance export DIRECTORY VARIANT
       godot --headless --path PROJECT --script res://Scripts/Sim/U13UnitBalanceParityRunner.gd -- DIRECTORY/inputs.jsonl DIRECTORY/native.jsonl
       python -m u13_pysim.verify_unit_balance compare DIRECTORY
       python -m u13_pysim.verify_unit_balance project NEW_PROJECT_DIRECTORY VARIANT

Experimental variants require an isolated native project with the SAME stated
override; the runner itself always executes that project's native game rules.
"""
import json
import sys
from collections import Counter
from pathlib import Path

from . import codec, unit_balance as audit
from .verify import same


def export(directory, variant):
    directory.mkdir(parents=True, exist_ok=True)
    specs = [dict(mode='squad', focus=name, opponent='balanced', sample=i, seat=i % 2,
                  rounds=10, variant=variant) for i, name in enumerate(audit.NAMES)]
    specs += [dict(mode='hunt', focus='Tumler', opponent='cluster', sample=7, seat=seat,
                   rounds=10, variant=variant) for seat in (0, 1)]
    specs += [dict(mode='mixed', focus='mixed', opponent='balanced', sample=i, seat=i % 2,
                   rounds=10, variant=variant) for i in range(5)]
    records = []
    for spec in specs: audit.run_case(spec, export=records)
    with (directory/'inputs.jsonl').open('w') as inputs, (directory/'expected.jsonl').open('w') as expected:
        for record in records:
            inputs.write(json.dumps({k: record[k] for k in ('world', 'seed', 'round')})+'\n')
            expected.write(codec.dumps(record['result'])+'\n')
    print(json.dumps(dict(variant=variant, battles=len(specs), phases=len(records))))


def compare(directory):
    events = Counter(); phases = 0
    with (directory/'expected.jsonl').open() as expected, (directory/'native.jsonl').open() as native:
        for i, (a, b) in enumerate(zip(expected, native, strict=True)):
            a, b = codec.loads(a), codec.loads(b)
            same(b, a, f'phase[{i}]')
            events.update(row['event']['type'] for row in a['events'])
            phases += 1
    result = dict(phases=phases, ticks=phases*200, complete_world_and_combat_events_match=True,
                  visual_tick_events_compared=False, event_types=dict(sorted(events.items())))
    (directory/'verification.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    directory = Path(sys.argv[2])
    if sys.argv[1] == 'export': export(directory, sys.argv[3])
    elif sys.argv[1] == 'compare': compare(directory)
    elif sys.argv[1] == 'project':
        from .unit_balance_variants import native_project
        print(native_project(directory, sys.argv[3]))
    else: raise SystemExit('Expected export or compare')
