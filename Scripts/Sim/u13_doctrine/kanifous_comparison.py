"""Fixed paired Kanifous V19/V20 screen: nine Lords, two seeds, both seats.

Only the focal policy changes. Both complete policy packages are frozen from
published commits; the opponent always uses V19, including the mirror matchup.
No tuning or case selection occurs during the campaign.
"""
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, wait, FIRST_COMPLETED
from dataclasses import asdict
import hashlib
import json
import multiprocessing
from pathlib import Path
import platform
import shutil
import time
import traceback

from u13_pysim.opening import LORDS
from u13_pysim.verify import source_identity
from .common import Weights
from .comparison import freeze_baseline
from .diagnostics import fingerprint
from .kanifous_audit import WishObserver
from .planner_probe import run_case
from .reference_probe import harness_hash
from .survey import LOADOUT, atomic_json, read_record
from .web_comparison import load_package

BASELINE='3324566936834d42a52c8ff0173f3b612a709616'
CANDIDATE='99ac1997b75215fdb0cfe937cf098989bcf88e49'
NAMESPACE='u13-kanifous-v19-v20-broad-2026-09-20'


def cases():
    for opponent in LORDS:
        for repeat in range(2):
            seed=f'{NAMESPACE}:{opponent}:{repeat:02d}'
            for seat in (0,1):
                pair=f'kanifous_{opponent.lower()}_{repeat:02d}_p{seat}'
                lords=[opponent,opponent];lords[seat]='Kanifous'
                for variant in ('old','new'):
                    yield dict(name=pair+'__'+variant,pair_id=pair,variant=variant,
                        focal_seat=seat,opponent=opponent,repeat=repeat,
                        setup=dict(seed=seed,lords=lords[:],castles=[LOADOUT[:],LOADOUT[:]]))


class PairedPolicy:
    def __init__(self,directory,spec):
        old=load_package(Path(directory)/'baseline');new=load_package(Path(directory)/'candidate')
        self.seat=spec['focal_seat'];self.trace=[]
        self.policies=[old.CommonSmartCore(),old.CommonSmartCore()]
        self.policy_ids=[old.VERSION,old.VERSION]
        if spec['variant']=='new':
            self.policies[self.seat]=new.CommonSmartCore();self.policy_ids[self.seat]=new.VERSION

    def decide(self,view,preview):
        decision=self.policies[view['player_id']].decide(view,preview)
        if decision['policy']!=self.policy_ids[view['player_id']]:raise ValueError('Wrong policy routed to seat')
        if view['player_id']==self.seat:self.trace.append(dict(view=view,decision=decision))
        return decision

    def choose_card(self,view,category):
        return self.policies[view['player_id']].choose_card(view,category)


def run_one(args):
    directory,spec,manifest_hash=args;policy=PairedPolicy(directory,spec);start=time.perf_counter()
    try:
        semantic,timing,operations=run_case(spec,policy,policy.policy_ids,WishObserver)
        status,error='complete',None
    except Exception:
        semantic,timing,operations={},{},[];status,error='failed',traceback.format_exc()
    record=dict(spec=spec,manifest_sha256=manifest_hash,status=status,error=error,
        semantic=semantic,semantic_sha256=fingerprint(semantic),timing=timing,operations=operations,
        trace=policy.trace,trace_sha256=fingerprint(policy.trace),wall_seconds=time.perf_counter()-start)
    atomic_json(Path(directory)/'games'/(spec['name']+'.json.gz'),record,compressed=True)
    return dict(name=spec['name'],status=status,error=error,rounds=semantic.get('rounds'),wall_seconds=record['wall_seconds'])


def metrics(record):
    seat=record['spec']['focal_seat'];result=Counter(decisions=len(record['trace']),wishes=0,successful=0,
        zero_effect=0,prices_scheduled=0,prices_resolved=0,death_casts=0,death_friendly=0,death_enemy=0,
        resurrected_bodies=0,resurrection_casts=0,power_bodies=0,breach_casts=0)
    for event in record['semantic']['diagnostics']['wish_events']:
        kind,d=event['type'],event['data']
        if kind=='KANIFOUS_WISH_RESOLVED':
            result.update(wishes=1,successful=int(d['count']>0),zero_effect=int(d['count']==0),breach_casts=int(d.get('breach',False)))
            result['cast:'+d['power']]+=1
            if not d['count']:result['zero_effect:'+d['power']]+=1
            if d['power']=='WishDeath':
                result['death_casts']+=1
                for unit in d['victims']:
                    label='friendly' if unit['owner']==seat else 'enemy' if unit['owner']==1-seat else 'neutral'
                    result['death_'+label]+=1
            elif d['power']=='WishResurrection':result.update(resurrection_casts=1,resurrected_bodies=d['count'])
            elif d['power']=='WishPower':result['power_bodies']+=d['count']
        elif kind=='KANIFOUS_PRICE_SCHEDULED':result['prices_scheduled']+=1
        elif kind=='KANIFOUS_PRICE_RESOLVED':
            result['prices_resolved']+=1;result['price:'+d['outcome']]+=1
        elif kind=='KANIFOUS_PRICE_DEFERRED':result['prices_deferred']+=1
    return dict(result)


def aggregate(records):
    totals={v:Counter(requested=0,completed=0,failed=0,wins=0,rounds=0,rejected_previews=0) for v in ('old','new')}
    groups={};pairs={};games=[]
    for record in records:
        spec=record['spec'];variant=spec['variant'];t=totals[variant];t['requested']+=1
        row={k:spec[k] for k in ('name','pair_id','variant','opponent','repeat','focal_seat')}
        row.update(status=record['status'],error=record['error'],wall_seconds=record['wall_seconds'])
        if record['status']=='complete':
            game=record['semantic'];won=game['outcome']['winner']==spec['focal_seat']
            observed=metrics(record);rejected=len(game['diagnostics']['rejected_previews'])
            t.update(completed=1,wins=int(won),rounds=game['rounds'],rejected_previews=rejected);t.update(observed)
            pairs.setdefault(spec['pair_id'],{})[variant]=dict(won=won,rounds=game['rounds'])
            for key in ('opponent:'+spec['opponent'],'seat:'+str(spec['focal_seat'])):
                group=groups.setdefault(key,{v:Counter(games=0,wins=0,rounds=0) for v in ('old','new')})
                group[variant].update(games=1,wins=int(won),rounds=game['rounds']);group[variant].update(observed)
            row.update(won=won,rounds=game['rounds'],outcome=game['outcome'],metrics=observed,rejected_previews=rejected)
        else:t['failed']+=1
        games.append(row)
    paired=Counter(complete_pairs=0,new_only_wins=0,old_only_wins=0,both_win=0,both_lose=0)
    for pair in pairs.values():
        if set(pair)!= {'old','new'}:continue
        old,new=pair['old']['won'],pair['new']['won'];paired['complete_pairs']+=1
        paired['both_win' if old and new else 'both_lose' if not old and not new else 'new_only_wins' if new else 'old_only_wins']+=1
    paired['net_wins']=paired['new_only_wins']-paired['old_only_wins']
    return dict(totals={v:dict(t) for v,t in totals.items()},paired=dict(paired),
        groups={k:{v:dict(t) for v,t in g.items()} for k,g in sorted(groups.items())},games=games,
        scope='Predeclared 72-game screen: nine fixed V19 opponents, two fresh seeds per matchup, both seats. 36 matched old/new pairs; 18 seed blocks because seats share a seed. Default castle loadout and deterministic selection. Behavioral totals include Breach Wishes and come from different trajectories; no causal attribution or general non-regression proof.')


def run(root,directory,workers=4,prepare_only=False):
    root,directory=Path(root),Path(directory).resolve();directory.mkdir(parents=True,exist_ok=True)
    baseline=freeze_baseline(root,BASELINE,directory/'baseline')
    candidate=freeze_baseline(root,CANDIDATE,directory/'candidate')
    revision,engine=source_identity(root);harness=harness_hash(root)
    specs=list(cases());old=load_package(directory/'baseline');new=load_package(directory/'candidate')
    runner_files=['Scripts/Sim/u13_doctrine/kanifous_comparison.py','Scripts/Sim/run_u13_kanifous_comparison.py']
    runner_hashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in runner_files}
    manifest=dict(schema='U13_KANIFOUS_PAIRED_SCREEN_V1',baseline=baseline,candidate=candidate,
        source_revision=revision,engine_sha256=engine,harness_sha256=harness,runner_sha256=runner_hashes,
        baseline_policy=old.VERSION,candidate_policy=new.VERSION,opponent_policy=old.VERSION,
        weights=asdict(Weights()),namespace=NAMESPACE,planned_games=len(specs),cases=specs,
        implementation=platform.python_implementation(),round_cap=40,
        scope='All cases fixed before execution. No tuning or dropping failed/censored games. Previously run four-game seed excluded.')
    path=directory/'manifest.json'
    if path.exists() and json.loads(path.read_text())!=manifest:raise ValueError('Different campaign identity')
    atomic_json(path,manifest);(directory/'games').mkdir(exist_ok=True)
    for name in runner_files:
        dst=directory/'source'/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(root/name,dst)
    if prepare_only:
        print(f'PREPARED {len(specs)} games; policies frozen; no games started. Reports: {directory}',flush=True)
        return manifest
    pending=[]
    for spec in specs:
        path=directory/'games'/(spec['name']+'.json.gz')
        if path.exists():read_record(path,manifest,spec)
        else:pending.append((str(directory),spec,fingerprint(manifest)))
    done=len(specs)-len(pending);start=time.perf_counter()
    with ProcessPoolExecutor(max_workers=workers,mp_context=multiprocessing.get_context('spawn')) as pool:
        tasks={pool.submit(run_one,args) for args in pending}
        while tasks:
            finished,tasks=wait(tasks,timeout=20,return_when=FIRST_COMPLETED)
            for task in finished:
                result=task.result();done+=1
                print(json.dumps(dict(result,finished=done,total=len(specs),elapsed_seconds=time.perf_counter()-start)),flush=True)
            if not finished:print(f'RUNNING {done}/{len(specs)} elapsed={time.perf_counter()-start:.1f}s',flush=True)
    if source_identity(root)[1]!=engine or harness_hash(root)!=harness:raise ValueError('Source changed during campaign')
    records=[read_record(directory/'games'/(s['name']+'.json.gz'),manifest,s) for s in specs]
    summary=aggregate(records);report=dict(manifest_sha256=fingerprint(manifest),summary=summary,
        summary_sha256=fingerprint(summary),wall_seconds=time.perf_counter()-start)
    atomic_json(directory/'summary.json',report)
    print(json.dumps(dict(totals=summary['totals'],paired=summary['paired']),indent=2),flush=True)
    if any(t['failed'] for t in summary['totals'].values()):raise RuntimeError('One or more games failed; see summary.json and saved records')
    return report
