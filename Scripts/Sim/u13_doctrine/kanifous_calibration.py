"""Separate Power, Wealth and Resurrection changes against frozen V20.

The same 36 situations are used for diagnosis, not a fresh confirmation set.
An intact previous 72-game ZIP can supply the 36 V20 controls; its engine,
policies, settings, specifications and record hashes must match before reuse.
"""
from concurrent.futures import ProcessPoolExecutor, wait, FIRST_COMPLETED
from collections import Counter
from dataclasses import asdict
import gzip
import hashlib
import json
import multiprocessing
from pathlib import Path
import shutil
import time
import traceback
import zipfile

from u13_pysim.verify import source_identity
from .common import VERSION, Weights
from .comparison import freeze_baseline
from .diagnostics import fingerprint
from .kanifous_audit import WishObserver
from .kanifous_comparison import BASELINE as OPPONENT, CANDIDATE as CONTROL, cases as previous_cases, metrics
from .kanifous_tactics import PROFILES
from .planner_probe import run_case
from .reference_probe import harness_hash
from .survey import atomic_json, read_record
from .web_comparison import load_package


def cases():
    for base in previous_cases():
        if base['variant']!='new':continue
        for profile in PROFILES:
            yield dict(base,name=base['pair_id']+'__'+profile,variant=profile)


def controls(path,engine):
    if path is None:return {},None
    path=Path(path);records={}
    with zipfile.ZipFile(path) as archive:
        names={n.replace('\\','/'):n for n in archive.namelist()}
        def read(name):return archive.read(names[name])
        manifest=json.loads(read('manifest.json'))
        if (manifest['engine_sha256']!=engine or manifest['baseline']['revision']!=OPPONENT
            or manifest['candidate']['revision']!=CONTROL or manifest['cases']!=list(previous_cases())
            or manifest['weights']!=asdict(Weights()) or manifest['round_cap']!=40):
            raise ValueError('Control ZIP does not match the frozen policies, cases, engine or settings')
        for folder in ('baseline','candidate'):
            hashes=manifest[folder]['files']
            if fingerprint(hashes)!=manifest[folder]['package_sha256']:raise ValueError('Corrupt control policy identity')
            for name,sha in hashes.items():
                if hashlib.sha256(read(folder+'/'+name)).hexdigest()!=sha:raise ValueError('Modified control policy file')
        for spec in manifest['cases']:
            if spec['variant']!='new':continue
            record=json.loads(gzip.decompress(read('games/'+spec['name']+'.json.gz')))
            if (record['status']!='complete' or record['spec']!=spec
                or record['manifest_sha256']!=fingerprint(manifest)
                or record['trace_sha256']!=fingerprint(record['trace'])
                or record['semantic_sha256']!=fingerprint(record['semantic'])
                or record['semantic']['decisions_sha256']!=fingerprint(record['operations'])):
                raise ValueError('Incomplete or corrupt V20 control record: '+spec['name'])
            records[spec['pair_id']]=record
    return records,dict(zip_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),manifest=manifest)


class CalibrationPolicy:
    def __init__(self,directory,spec):
        directory=Path(directory);old=load_package(directory/'opponent')
        self.seat=spec['focal_seat'];self.trace=[]
        self.policies=[old.CommonSmartCore(),old.CommonSmartCore()]
        if spec['variant']=='v20':self.policies[self.seat]=load_package(directory/'control').CommonSmartCore()
        else:self.policies[self.seat]=load_package(directory/'candidate').CommonSmartCore(wish_profile=spec['variant'])
        self.policy_ids=[p.policy_id for p in self.policies]

    def decide(self,view,preview):
        decision=self.policies[view['player_id']].decide(view,preview)
        if decision['policy']!=self.policy_ids[view['player_id']]:raise ValueError('Wrong policy routing')
        if view['player_id']==self.seat:self.trace.append(dict(view=view,decision=decision))
        return decision

    def choose_card(self,view,category):return self.policies[view['player_id']].choose_card(view,category)


def run_one(args):
    directory,spec,manifest_hash=args;policy=CalibrationPolicy(directory,spec);start=time.perf_counter()
    try:
        semantic,timing,operations=run_case(spec,policy,policy.policy_ids,WishObserver)
        status,error='complete',None
    except Exception:
        semantic,timing,operations={},{},[];status,error='failed',traceback.format_exc()
    record=dict(spec=spec,manifest_sha256=manifest_hash,status=status,error=error,semantic=semantic,
        semantic_sha256=fingerprint(semantic),timing=timing,operations=operations,trace=policy.trace,
        trace_sha256=fingerprint(policy.trace),wall_seconds=time.perf_counter()-start)
    atomic_json(Path(directory)/'games'/(spec['name']+'.json.gz'),record,compressed=True)
    return dict(name=spec['name'],status=status,error=error,rounds=semantic.get('rounds'),wall_seconds=record['wall_seconds'])


def aggregate(records):
    totals={v:Counter(completed=0,failed=0,wins=0,rounds=0,rejected_previews=0) for v in PROFILES}
    pairs={};groups={};games=[]
    for record in records:
        spec=record['spec'];v=spec['variant'];t=totals[v]
        row=dict(spec=spec,status=record['status'],error=record['error'],reused=bool(record.get('imported_from')))
        if record['status']=='complete':
            s=record['semantic'];won=s['outcome']['winner']==spec['focal_seat'];observed=metrics(record)
            t.update(completed=1,wins=int(won),rounds=s['rounds'],rejected_previews=len(s['diagnostics']['rejected_previews']));t.update(observed)
            pairs.setdefault(spec['pair_id'],{})[v]=won
            for key in ('opponent:'+spec['opponent'],'seat:'+str(spec['focal_seat'])):
                group=groups.setdefault(key,{p:Counter(games=0,wins=0) for p in PROFILES})
                group[v].update(games=1,wins=int(won))
            row.update(outcome=s['outcome'],rounds=s['rounds'],metrics=observed)
        else:t['failed']+=1
        games.append(row)
    comparisons={}
    for variant in PROFILES[1:]:
        c=Counter(complete_pairs=0,gained=0,lost=0,both_win=0,both_lose=0)
        for p in pairs.values():
            if 'v20' not in p or variant not in p:continue
            a,b=p['v20'],p[variant];c['complete_pairs']+=1
            c['both_win' if a and b else 'both_lose' if not a and not b else 'gained' if b else 'lost']+=1
        c['net_wins']=c['gained']-c['lost'];comparisons[variant]=dict(c)
    return dict(totals={k:dict(v) for k,v in totals.items()},paired_vs_v20=comparisons,
        groups={k:{v:dict(c) for v,c in g.items()} for k,g in groups.items()},games=games,
        scope='Controlled recalibration on the previous 36 setups: one changed factor at a time and all three together. Seeds informed the changes, so this is diagnostic evidence; an independent seed set is needed for confirmation. Breach effects are included in event totals.')


def run(root,directory,workers=4,control_zip=None,prepare_only=False):
    root,directory=Path(root),Path(directory).resolve();directory.mkdir(parents=True,exist_ok=True)
    revision,engine=source_identity(root);harness=harness_hash(root)
    imported,provenance=controls(control_zip,engine)
    opponent=freeze_baseline(root,OPPONENT,directory/'opponent')
    control=freeze_baseline(root,CONTROL,directory/'control')
    if provenance and (provenance['manifest']['baseline']['package_sha256']!=opponent['package_sha256']
        or provenance['manifest']['candidate']['package_sha256']!=control['package_sha256']):
        raise ValueError('Control archive policy contents differ from the published commits')
    candidate=freeze_baseline(root,revision,directory/'candidate')
    frozen=load_package(directory/'candidate')
    if frozen.VERSION!=VERSION or 'V21_KANIFOUS_RECALIBRATION' not in frozen.VERSION:
        raise ValueError('Runner must use a committed V21 recalibration checkout')
    for name,sha in candidate['files'].items():
        path=root/'Scripts/Sim/u13_doctrine'/name
        if hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=sha:
            raise ValueError('Uncommitted candidate policy changes: '+name)
    specs=list(cases());runner_names=('Scripts/Sim/run_u13_kanifous_calibration.py','Scripts/Sim/run_u13_kanifous_calibration.sh')
    manifest=dict(schema='U13_KANIFOUS_CALIBRATION_V21_V1',source_revision=revision,engine_sha256=engine,
        harness_sha256=harness,opponent=opponent,control=control,candidate=candidate,profiles=PROFILES,
        cases=specs,weights=asdict(Weights()),round_cap=40,control_source=provenance,
        runner_sha256={n:hashlib.sha256((root/n).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for n in runner_names})
    # JSON round-trip keeps tuple/list identity consistent when resuming.
    manifest=json.loads(json.dumps(manifest));path=directory/'manifest.json'
    if path.exists() and json.loads(path.read_text())!=manifest:raise ValueError('Different calibration run identity')
    atomic_json(path,manifest);(directory/'games').mkdir(exist_ok=True)
    for name in runner_names:
        dst=directory/'source'/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(root/name,dst)
    pending=[]
    for spec in specs:
        path=directory/'games'/(spec['name']+'.json.gz')
        if not path.exists() and spec['variant']=='v20' and spec['pair_id'] in imported:
            original=imported[spec['pair_id']]
            record=dict(original,spec=spec,manifest_sha256=fingerprint(manifest),
                imported_from=dict(manifest_sha256=original['manifest_sha256'],spec=original['spec'],record_sha256=fingerprint(original)))
            atomic_json(path,record,compressed=True)
        if path.exists():read_record(path,manifest,spec)
        else:pending.append((str(directory),spec,fingerprint(manifest)))
    print(f'{len(specs)} results planned; {len(imported)} verified V20 controls reusable; {len(pending)} games to run.',flush=True)
    if prepare_only:
        print('PREPARED. No games started.',flush=True);return manifest
    start=time.perf_counter();done=len(specs)-len(pending)
    with ProcessPoolExecutor(max_workers=workers,mp_context=multiprocessing.get_context('spawn')) as pool:
        tasks={pool.submit(run_one,args) for args in pending}
        while tasks:
            finished,tasks=wait(tasks,timeout=20,return_when=FIRST_COMPLETED)
            for task in finished:
                result=task.result();done+=1
                print(json.dumps(dict(result,finished=done,total=len(specs),elapsed_seconds=time.perf_counter()-start)),flush=True)
            if not finished:print(f'RUNNING {done}/{len(specs)} elapsed={time.perf_counter()-start:.1f}s',flush=True)
    if source_identity(root)[1]!=engine or harness_hash(root)!=harness:raise ValueError('Source changed during run')
    summary=aggregate([read_record(directory/'games'/(s['name']+'.json.gz'),manifest,s) for s in specs])
    atomic_json(directory/'summary.json',dict(manifest_sha256=fingerprint(manifest),summary=summary,
        summary_sha256=fingerprint(summary),wall_seconds=time.perf_counter()-start))
    print(json.dumps(dict(totals=summary['totals'],paired_vs_v20=summary['paired_vs_v20']),indent=2),flush=True)
    if any(t['failed'] for t in summary['totals'].values()):raise RuntimeError('Failed cases retained; see summary.json')
    return summary
