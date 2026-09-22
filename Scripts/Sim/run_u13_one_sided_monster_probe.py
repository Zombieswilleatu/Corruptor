#!/usr/bin/env python3
"""One counterfactual game using a verified archived control and frozen rules."""
import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import sys
import time


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--case',default='kroni_odradek_00_tempo')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    source=args.baseline/'source'/'Scripts'/'Sim'
    sys.path.insert(0,str(source.resolve()))
    from u13_pysim.power_match import PowerMatch
    from u13_pysim.benchmark_full_match import digest
    from u13_doctrine import planner_probe
    from u13_doctrine.common import Weights
    from u13_doctrine.diagnostics import fingerprint
    from u13_doctrine.survey import TracedPolicy
    assert Path(sys.modules['u13_pysim.power_match'].__file__).is_relative_to(source.resolve())
    record_path=args.baseline/'games'/(args.case+'.json.gz')
    record=json.load(gzip.open(record_path,'rt'))
    manifest=json.loads((args.baseline/'manifest.json').read_text())
    assert record['status']=='complete'
    assert fingerprint(record['semantic'])==record['semantic_sha256']
    assert fingerprint(record['operations'])==record['semantic']['decisions_sha256']
    winner=record['semantic']['outcome']['winner']
    setup=record['spec']['setup']
    baseline=PowerMatch(setup)
    for op in record['operations']:
        result=baseline.apply(op)
        assert result['action']!='invalid',result
    assert digest(baseline)==record['semantic']['final_state_sha256'], 'control replay mismatch'
    print('Verified control:', baseline.outcome(),flush=True)
    instances=[]
    class Restricted(PowerMatch):
        def __init__(self,setup):
            super().__init__(setup)
            self._state['world']['data']['monsters']['unlocked'][winner]=[]
            instances.append(self)
        def apply(self,op):
            if op.get('kind')=='submit':
                assert not op['plans'][winner]['order'].get('monster_choice')
            result=super().apply(op)
            assert self._state['world']['data']['monsters']['unlocked'][winner]==[]
            return result
    planner_probe.PowerMatch=Restricted
    policy=TracedPolicy(Weights(**manifest['weights']))
    spec=dict(record['spec'],name=args.case+'_winner_no_recipe_summons')
    started=time.perf_counter()
    semantic,timing,operations=planner_probe.run_case(spec,policy)
    match=instances[0]
    def summary(game):
        w=game._state['world']; summons=[Counter(),Counter()]; bodies=[0,0]; normals=[0,0]
        rounds=[]
        for row in game._state['events']['rows']:
            event=row['event'];d=event['data'];kind=event['type']
            if kind=='MONSTER_SUMMONED':
                summons[d['player_id']][d['monster_id']]+=1
                bodies[d['player_id']]+=len(d['unit_ids'])
            if kind=='MARCHER_SPAWNED' and 'monster_id' not in d['attributes']:
                normals[d['owner']]+=1
            if kind=='MATCH_FINISHED': rounds.append(d)
        return dict(outcome=game.outcome(), souls=[p['resources']['souls'] for p in w['players']],
            tears=[p['resources']['personal_tears'] for p in w['players']],
            monster_summons=[dict(c) for c in summons], monster_bodies=bodies,
            normal_spawns=normals, finish=rounds)
    control=summary(baseline);changed=summary(match)
    assert not changed['monster_summons'][winner]
    report=dict(schema='U13_ONE_SIDED_MONSTER_PROBE_V1',setup=setup,
        restricted_seat=winner,restricted_lord=setup['lords'][winner],
        intervention='Only prior winner recipe unlocks are empty from setup; both bots replan normally. No stat, income, cost, target or other rule change.',
        scope='One newly planned counterfactual game; control reused from archive and exact final state independently replay-verified. Python-only balance probe, not native parity or population evidence.',
        baseline_record_sha256=hashlib.sha256(record_path.read_bytes()).hexdigest(),
        baseline_final_state_sha256=digest(baseline),control=control,counterfactual=changed,
        seconds=time.perf_counter()-started, timing=timing,
        rejected_previews=semantic['diagnostics'].get('rejected_previews'),
        final_state_sha256=digest(match),operations_sha256=fingerprint(operations),
        frozen_source_sha256={str(p.relative_to(source)):hashlib.sha256(p.read_bytes()).hexdigest()
            for folder in ('u13_pysim','u13_doctrine') for p in sorted((source/folder).glob('*.py'))})
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    trace_path=args.output.with_suffix('.trace.json.gz')
    with gzip.open(trace_path,'wt') as stream:
        json.dump(dict(report=report,operations=operations,trace=policy.trace,semantic=semantic),stream)
    print(json.dumps({k:report[k] for k in ('control','counterfactual','seconds','rejected_previews')},indent=2))

if __name__=='__main__':main()
