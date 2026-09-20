#!/usr/bin/env python3
"""Compare the focused native Gravity well packets with Python, tick for tick."""
import json
import sys
from pathlib import Path
from u13_pysim import codec, marching_fixtures as f
from u13_pysim.verify import same
from u13_pysim.verify_marching import transition

specs=json.loads(Path(__file__).with_name('u13_pysim').joinpath('gravity_well_inputs.json').read_text())
report=codec.loads(Path(sys.argv[1]).read_text())
same([s['name'] for s in specs],[r['name'] for r in report['cases']],'cases')
operations=0
for spec,row in zip(specs,report['cases']):
    world=f.initial(spec);same(world,row['initial'],spec['name']+'.initial')
    for op,expected in zip(spec['operations'],row['records']):
        actual=f.apply(spec,world,op)
        transition(expected,dict(operation=op,**actual),spec['name'])
        world=actual['world'];operations+=1
        if spec['name']=='gravity_slow_pulses':
            events=[e['event'] for e in actual['result']['events']]
            hits=[e['data'] for e in events if e['type']=='GRAVITY_ORB_DAMAGED']
            expected_ticks=[66,133] if op['round']==1 else [0,67,134]
            same(expected_ticks,sorted(set(h['tick'] for h in hits)),'pulse times')
            assert not any(e['type']=='GRAVITY_ORB_CONSUMED' for e in events)
            if op['round']==1:assert any(e['type']=='MARCHER_DEFEATED' and e['data']['cause']=='gravity' for e in events)
print(json.dumps(dict(cases=len(specs),operations=operations,marching_ticks=operations*200,exact_match=True)))
