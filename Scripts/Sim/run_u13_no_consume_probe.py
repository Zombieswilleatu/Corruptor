#!/usr/bin/env python3
"""One Kroni/Odradek replay without Consume, retaining current Ravenous rules."""
import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import sys


def summarize(game):
    w=game._state['world']; counts=Counter(); ravenous=[]; actors={}
    for row in game._state['events']['rows']:
        event=row['event']; d=event['data'];kind=event['type']
        if kind=='RAVENOUS_ARMED' and d['actor']['owner']==0:
            counts['ravenous_uses']+=1;actors[d['actor']['id']]=dict(enemy=0,friendly=0)
        if kind=='MARCHER_DEVOURED' and d['actor_id'] in actors:
            key='friendly' if d['before']['owner']==0 else 'enemy'
            actors[d['actor_id']][key]+=1
        if kind=='RAVENOUS_REWARDED' and d['player_id']==0:
            assert d['enemy_consumed']>=11
            counts['ravenous_souls']+=d['souls']
        if kind=='GUARD_DEVOURED' and d['player_id']==0:
            counts['consume_guards' if d['cause']=='Consume' else 'own_guards_eaten']+=1
        if kind=='SIEGE_RESOLVED' and d['player_id']==0:
            counts['siege_targets_destroyed']+=int(d.get('destroyed',False))
        if kind=='MONSTER_SUMMONED':counts['monster_recipes_seat_'+str(d['player_id'])]+=1
    return dict(outcome=game.outcome(),souls=[p['resources']['souls'] for p in w['players']],
        tears=[p['resources']['personal_tears'] for p in w['players']],counts=dict(counts),ravenous=list(actors.values()))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    source=Path(__file__).resolve().parent;sys.path.insert(0,str(source))
    from u13_pysim import powers
    from u13_pysim.power_match import PowerMatch
    from u13_pysim.benchmark_full_match import digest
    from u13_doctrine import planner_probe
    from u13_doctrine.facts import Facts
    from u13_doctrine.common import Weights
    from u13_doctrine.survey import TracedPolicy
    from u13_doctrine.diagnostics import fingerprint
    name='kroni_odradek_00_tempo'
    record_path=args.baseline/'games'/(name+'.json.gz')
    record=json.load(gzip.open(record_path,'rt'))
    assert record['status']=='complete'
    assert fingerprint(record['semantic'])==record['semantic_sha256']
    assert fingerprint(record['operations'])==record['semantic']['decisions_sha256']
    setup=record['spec']['setup'];assert setup['lords']==['Kroni','Odradek']
    control=PowerMatch(setup)
    for op in record['operations']:assert control.apply(op)['action']!='invalid'
    baseline=summarize(control)
    assert baseline['outcome']==record['semantic']['outcome']
    assert baseline['souls']==record['semantic']['diagnostics']['victory_race']['souls']
    assert baseline['tears']==record['semantic']['diagnostics']['victory_race']['personal_tears']
    print('Archived operations replay under eleven-enemy rule:',baseline,flush=True)
    original_validate=powers.validate; original_available=Facts.available
    def validate(s,w,phase,active):
        if s['power_id']=='Consume':return 'consume_disabled_for_probe'
        return original_validate(s,w,phase,active)
    def available(self,name):
        if name=='Consume':return False,'consume_disabled_for_probe'
        return original_available(self,name)
    powers.validate=validate;Facts.available=available
    assert powers.validate(dict(power_id='Consume'),{},'declaration',[])=='consume_disabled_for_probe'
    assert Facts.available(None,'Consume')==(False,'consume_disabled_for_probe')
    instances=[]
    class Capture(PowerMatch):
        def __init__(self,setup):
            super().__init__(setup);instances.append(self)
        def apply(self,op):
            if op['kind']=='submit':
                assert all(s['power_id']!='Consume' for p in op['plans'] for s in p['powers'])
            return super().apply(op)
    planner_probe.PowerMatch=Capture
    weights=Weights(**json.loads((args.baseline/'manifest.json').read_text())['weights'])
    policy=TracedPolicy(weights)
    semantic,timing,operations=planner_probe.run_case(dict(record['spec'],name=name+'_no_consume_enemy11'),policy)
    changed=summarize(instances[0]);assert changed['counts'].get('consume_guards',0)==0
    report=dict(schema='U13_NO_CONSUME_PROBE_V1',setup=setup,
        scope='One new planned game, current eleven-enemy Ravenous reward, no Consume. Normal Cannibal Hunger remains active; normal free recipes for both sides. No paid-monster experiment.',
        comparison='Archived free-monster game operations replayed under current eleven-enemy rules; outcome/Souls/Tears reproduced. This is not a newly planned matched control for the changed reward-scoring rule.',
        control=baseline,counterfactual=changed,timing=timing,
        rejected_previews=semantic['diagnostics']['rejected_previews'],
        control_replay_sha256=digest(control),counterfactual_sha256=digest(instances[0]),
        archived_record_sha256=hashlib.sha256(record_path.read_bytes()).hexdigest(),
        runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        source_sha256={str(p.relative_to(source)):hashlib.sha256(p.read_bytes()).hexdigest()
            for folder in ('u13_pysim','u13_doctrine') for p in sorted((source/folder).glob('*.py'))})
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    with gzip.open(args.output.with_suffix('.trace.json.gz'),'wt') as f:
        json.dump(dict(report=report,operations=operations,trace=policy.trace,semantic=semantic),f)
    print(json.dumps(dict(counterfactual=changed,rejected_previews=report['rejected_previews']),indent=2))

if __name__=='__main__':main()
