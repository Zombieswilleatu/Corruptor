#!/usr/bin/env python3
"""Compare native guard routes and meal outcomes with independent Python logic."""
import copy,json,sys
from u13_pysim.guard_consume import choose
from u13_pysim.powers import resolve
r=json.load(open(sys.argv[1]))
for row in r['routes']:
    assert choose(row['world'],row['owner'],row['seed'],row['key'])==row['result']
for row in r['resolves']:
    state=dict(world=copy.deepcopy(row['world']),seed=row['seed'],player_order=[0,1])
    # Legacy native Scenario omits the later guard-pair ledger; empty here.
    state['world']['data']['guard_work']={'pairs':[]}
    out=resolve(row['record'],state,2)
    assert out['events']==row['result']['events']
    assert state['world']['players']==row['result']['world']['players']
    assert state['world']['entities']==row['result']['world']['entities']
    assert state['world']['data']['kroni_fed']==row['result']['world']['data']['kroni_fed']
print(f"Guard Consume parity: {len(r['routes'])} routes and {len(r['resolves'])} meal outcomes passed")
