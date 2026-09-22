#!/usr/bin/env python3
"""One fresh neutral-Consume game using the retained Kroni/Odradek setup."""
import argparse,gzip,hashlib,json,time
from pathlib import Path
from collections import Counter
from u13_pysim.power_match import PowerMatch
from u13_doctrine import planner_probe
from u13_doctrine.common import Weights
from u13_doctrine.survey import TracedPolicy
from run_u13_no_consume_probe import summarize

def main():
    p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    path=a.baseline/'games/kroni_odradek_00_tempo.json.gz';r=json.load(gzip.open(path,'rt'))
    instances=[]
    class Capture(PowerMatch):
        def __init__(self,setup):super().__init__(setup);instances.append(self)
        def apply(self,op):
            if op['kind']=='submit':
                for plan in op['plans']:
                    for source in plan['powers']:
                        if source['power_id']=='Consume':assert source['target']=={'mode':'guard_bounce'}
            return super().apply(op)
    planner_probe.PowerMatch=Capture
    policy=TracedPolicy(Weights(**json.loads((a.baseline/'manifest.json').read_text())['weights']))
    semantic,timing,ops=planner_probe.run_case(dict(r['spec'],name='kroni_odradek_00_guard_bounce'),policy)
    game=instances[0];meals=[]
    for row in game._state['events']['rows']:
        e=row['event'];d=e['data']
        if e['type']=='GUARD_DEVOURED' and d['cause']=='Consume':
            assert 'guard_bounce' in d
            meals.append(dict(round=d['round'],player=d['player_id'],enemy=d['before']['owner']!=d['player_id'],lane=d['before']['attributes']['lane'],value=d['before']['attributes']['value'],flight=d['guard_bounce']))
    source=Path(__file__).resolve().parent
    result=dict(setup=r['spec']['setup'],scope='One newly planned neutral-Consume game; current eleven-enemy Ravenous reward and free recipes. Historical exact-target control is the archived round-9 Ritual result; no fresh matched control.',
                result=summarize(game),meals=meals,rejected_previews=semantic['diagnostics']['rejected_previews'],timing=timing,
                source_sha256={str(x.relative_to(source)):hashlib.sha256(x.read_bytes()).hexdigest() for folder in ('u13_pysim','u13_doctrine') for x in sorted((source/folder).glob('*.py'))})
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n')
    with gzip.open(a.output.with_suffix('.trace.json.gz'),'wt') as f:json.dump(dict(operations=ops,semantic=semantic,trace=policy.trace),f)
    print(json.dumps({k:result[k] for k in ('result','meals','rejected_previews')},indent=2))
if __name__=='__main__':main()
