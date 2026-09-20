"""Four predeclared diagnostic games and same-board V19/V20 decisions.

Both variants face frozen V19 Gremory with the same seed in both seats. This
is a small behavior check, not a strength estimate. Counterfactual decisions
receive the identical public view and authority Preview, never later events.
"""
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from dataclasses import asdict
import hashlib
import gzip
import json
from pathlib import Path
import platform
import shutil
import time

from u13_pysim.verify import source_identity
from .common import CommonSmartCore, VERSION, Weights
from .comparison import freeze_baseline
from .diagnostics import fingerprint
from .kanifous_tactics import WISHES
from .planner_probe import PlannerObserver, run_case
from .survey import LOADOUT, atomic_json
from .web_comparison import load_package

BASELINE='3324566936834d42a52c8ff0173f3b612a709616'
NAMESPACE='u13-kanifous-wish-price-v20-2026-09-20'


def cases():
    for seat in (0,1):
        lords=['Gremory','Gremory'];lords[seat]='Kanifous'
        for variant in ('old','new'):
            yield dict(name=f'kanifous_gremory_p{seat}__{variant}',focal_seat=seat,variant=variant,
                setup=dict(seed=NAMESPACE,lords=lords,castles=[LOADOUT[:],LOADOUT[:]]))


class AuditPolicy:
    def __init__(self,directory,spec):
        old=load_package(Path(directory)/'baseline')
        self.old,self.new=old.CommonSmartCore(),CommonSmartCore()
        self.seat,self.variant=spec['focal_seat'],spec['variant']
        self.policy_ids=[old.VERSION]*2
        if self.variant=='new':self.policy_ids[self.seat]=VERSION
        self.trace=[]

    def decide(self,view,preview):
        old=self.old.decide(view,preview)
        if view['player_id']!=self.seat:return old
        new=self.new.decide(view,preview)
        self.trace.append(dict(view=view,old=old,new=new))
        return new if self.variant=='new' else old

    def choose_card(self,view,category):
        policy=self.new if view['player_id']==self.seat and self.variant=='new' else self.old
        return policy.choose_card(view,category)


class WishObserver(PlannerObserver):
    def __init__(self,spec,policy_ids):
        super().__init__(spec,policy_ids);self.seat=spec['focal_seat'];self.wishes=[]

    def event(self,index,event,current_round):
        super().event(index,event,current_round)
        if event['type'] in ('KANIFOUS_WISH_RESOLVED','KANIFOUS_PRICE_SCHEDULED','KANIFOUS_PRICE_RESOLVED','KANIFOUS_PRICE_DEFERRED'):
            data=event['data']
            if data.get('player_id',data.get('owner'))==self.seat:self.wishes.append(event)

    def report(self):
        result=super().report();result['wish_events']=self.wishes;return result


def run_one(args):
    directory,spec,manifest_hash=args;policy=AuditPolicy(directory,spec);start=time.perf_counter()
    semantic,timing,operations=run_case(spec,policy,policy.policy_ids,WishObserver)
    record=dict(spec=spec,manifest_sha256=manifest_hash,status='complete',semantic=semantic,
        timing=timing,operations=operations,trace=policy.trace,trace_sha256=fingerprint(policy.trace),
        wall_seconds=time.perf_counter()-start)
    atomic_json(Path(directory)/'games'/(spec['name']+'.json.gz'),record,compressed=True)
    return dict(name=spec['name'],rounds=semantic['rounds'],winner=semantic['outcome']['winner'],wall_seconds=record['wall_seconds'])


def summarize(records):
    totals={v:Counter(games=0,wins=0,decisions=0,wishes=0,successful=0,zero_effect=0,prices_resolved=0) for v in ('old','new')}
    same=Counter(boards=0,changed_plans=0,changed_wishes=0); selections={v:Counter() for v in ('old','new')};games=[]
    for r in records:
        spec=r['spec'];variant=spec['variant'];seat=spec['focal_seat'];semantic=r['semantic'];t=totals[variant]
        t.update(games=1,wins=int(semantic['outcome']['winner']==seat),decisions=len(r['trace']))
        for event in semantic['diagnostics']['wish_events']:
            d=event['data']
            if event['type']=='KANIFOUS_WISH_RESOLVED':
                t.update(wishes=1,successful=int(d['count']>0),zero_effect=int(d['count']==0))
                t['cast:'+d['power']]+=1
            elif event['type']=='KANIFOUS_PRICE_RESOLVED':
                t['prices_resolved']+=1;t['price:'+d['outcome']]+=1
        for item in r['trace']:
            powers={v:[s for s in item[v]['plan']['powers'] if s['power_id'] in WISHES] for v in ('old','new')}
            same.update(boards=1,changed_plans=int(item['old']['plan']!=item['new']['plan']),changed_wishes=int(powers['old']!=powers['new']))
            for v in ('old','new'):selections[v].update(s['power_id'] for s in powers[v])
        games.append(dict(name=spec['name'],variant=variant,seat=seat,rounds=semantic['rounds'],outcome=semantic['outcome'],
            rejected_previews=len(semantic['diagnostics']['rejected_previews'])))
    return dict(totals={v:dict(t) for v,t in totals.items()},same_board=dict(same),same_board_selections={v:dict(t) for v,t in selections.items()},games=games,
        scope='Four diagnostic games, one seed, two seats, frozen V19 Gremory. Same-board rows include both trajectories and repeated openings; not independent samples or win-rate evidence.')


def read_records(directory,manifest):
    records=[]
    for spec in manifest['cases']:
        path=Path(directory)/'games'/(spec['name']+'.json.gz')
        with gzip.open(path,'rt',encoding='utf-8') as stream:record=json.load(stream)
        if record['manifest_sha256']!=fingerprint(manifest) or record['spec']!=spec:
            raise ValueError('Different saved game identity: '+str(path))
        if record['trace_sha256']!=fingerprint(record['trace']):raise ValueError('Corrupt decision trace')
        if record['semantic']['decisions_sha256']!=fingerprint(record['operations']):raise ValueError('Corrupt operation stream')
        records.append(record)
    return records


def run(root,directory,workers=2):
    root,directory=Path(root),Path(directory).resolve();directory.mkdir(parents=True,exist_ok=True)
    baseline=freeze_baseline(root,BASELINE,directory/'baseline');revision,engine=source_identity(root)
    files={p.relative_to(root/'Scripts/Sim/u13_doctrine').as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted((root/'Scripts/Sim/u13_doctrine').rglob('*.py'))}
    manifest=dict(schema='U13_KANIFOUS_WISH_PRICE_AUDIT_V1',baseline=baseline,source_revision=revision,
        engine_sha256=engine,candidate_policy=VERSION,candidate_files=files,weights=asdict(Weights()),
        cases=list(cases()),implementation=platform.python_implementation(),namespace=NAMESPACE,round_cap=40)
    path=directory/'manifest.json'
    if path.exists() and json.loads(path.read_text())!=manifest:raise ValueError('Different audit identity')
    atomic_json(path,manifest)
    for name in files:
        dst=directory/'candidate'/name;dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(root/'Scripts/Sim/u13_doctrine'/name,dst)
    (directory/'games').mkdir(exist_ok=True)
    pending=[(str(directory),s,fingerprint(manifest)) for s in manifest['cases']
             if not (directory/'games'/(s['name']+'.json.gz')).exists()]
    with ProcessPoolExecutor(max_workers=workers) as pool:
        for result in pool.map(run_one,pending):print(json.dumps(result),flush=True)
    records=read_records(directory,manifest)
    result=summarize(records);atomic_json(directory/'summary.json',result)
    print(json.dumps(result,indent=2),flush=True)
    return result
