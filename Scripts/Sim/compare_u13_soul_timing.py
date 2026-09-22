#!/usr/bin/env python3
"""Paired round-18 soul bonus trial; reuse only provably unaffected endings."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from statistics import mean

from run_u13_lord_balance import freeze, verify_frozen, package
from run_u13_split_ward_experiment import worker
from u13_doctrine.common import Weights
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.survey import atomic_json, manifest, pooled_results, read_record
from u13_pysim.split_ward import TEMPO_SOUL_START_ROUND


def source_proof(baseline, candidate):
    """Fail closed unless the only engine/policy change is the round gate.

    Before round 18 both guards return immediately. Observation and all policy
    code are identical, so no earlier state, decision, or ending can change.
    """
    verify_frozen(baseline)
    source=baseline/'source'
    changed=[]
    for folder in ('u13_pysim','u13_doctrine'):
        for old in (source/'Scripts/Sim'/folder).rglob('*.py'):
            if old.name.startswith('test_'): continue
            relative=old.relative_to(source)
            before=old.read_bytes(); after=(candidate/relative).read_bytes()
            if before==after: continue
            if relative.as_posix()!='Scripts/Sim/u13_pysim/split_ward.py':
                raise ValueError('Additional behavior change prevents reuse: '+str(relative))
            expected=before.decode().replace("TEMPO = 'U13_VEIL_ATTACK_ROUND25_V1'",
                "TEMPO = 'U13_VEIL_ATTACK_ROUND25_V1'\nTEMPO_SOUL_START_ROUND = 18").replace(
                'if rules.number < 20: return','if rules.number < TEMPO_SOUL_START_ROUND: return')
            if expected.encode()!=after: raise ValueError('Unexpected soul rule change')
            changed.append(str(relative))
    if changed!=['Scripts/Sim/u13_pysim/split_ward.py']:
        raise ValueError('Expected exactly one behavior change')
    return dict(changed=changed, before_round=20, after_round=18,
        justification='Before round 18 both reward guards return; all observation/policy and other engine source is byte-identical.')


def compact(record):
    game=record['semantic']; d=game['diagnostics']
    return dict(rounds=game['rounds'],outcome=game['outcome'],finish=d['victory_race'],
        decisive_souls=d['split_trial'].get('decisive_souls',0),
        rejected_previews=len(d['rejected_previews']),
        semantic_sha256=record['semantic_sha256'], trace_sha256=record['trace_sha256'],
        decisions_sha256=game['decisions_sha256'], final_state_sha256=game['final_state_sha256'])


def totals(rows):
    return dict(games=len(rows),mean_rounds=mean(r['rounds'] for r in rows),
        total_rounds=sum(r['rounds'] for r in rows),
        bands=dict(Counter('under15' if r['rounds']<15 else '15to20' if r['rounds']<=20 else 'over20' for r in rows)),
        endings=dict(Counter(r['outcome']['win_by'] for r in rows)),
        decisive_souls=sum(r['decisive_souls'] for r in rows))


def execute(output, baseline):
    verify_frozen(output)
    proof=source_proof(baseline,output/'source')
    control_id=json.loads((baseline/'manifest.json').read_text())
    specs=json.loads((baseline/'split-config.json').read_text())['cases']
    if len(specs)!=162 or not all(s['arm']=='tempo' for s in specs): raise ValueError('Expected complete 162-game tempo baseline')
    identity=manifest(Path(__file__).resolve().parents[2],control_id['namespace'],Weights(**control_id['weights']))
    identity.update(soul_start_round=TEMPO_SOUL_START_ROUND,baseline_manifest_sha256=fingerprint(control_id),
        frozen_source=fingerprint(json.loads((output/'frozen-source.json').read_text())))
    atomic_json(output/'manifest.json',identity)
    control=output/'control'; (control/'games').mkdir(parents=True)
    atomic_json(control/'manifest.json',control_id)
    shutil.copyfile(baseline/'frozen-source.json',control/'frozen-source.json')
    shutil.copyfile(baseline/'source/Scripts/Sim/u13_pysim/split_ward.py',control/'split_ward_round20.py')
    before={}; eligible=[]
    for spec in specs:
        path=baseline/'games'/(spec['name']+'.json.gz')
        record=read_record(path,control_id,spec)
        if record['status']!='complete': raise ValueError('Baseline failure')
        before[spec['name']]=compact(record)
        shutil.copyfile(path,control/'games'/path.name)
        if record['semantic']['rounds']>=18: eligible.append(spec)
    atomic_json(output/'comparison-config.json',dict(cases=specs,fresh_cases=eligible,
        workers=2,worker_batch_size=4,baseline=str(baseline),source_proof=proof))
    games=output/'games';games.mkdir()
    for result in pooled_results(eligible,identity,str(games),2,4,task=worker):
        if result is None: print('Two workers still running.',flush=True);continue
        atomic_json(output/(result['name']+'-performance.json'),result)
        print(json.dumps(result),flush=True)
        if result['status']!='complete': raise RuntimeError(result['error'])
    pairs=[]
    fresh_names={s['name'] for s in eligible}
    for spec in specs:
        name=spec['name'];old=before[name]
        if name in fresh_names:
            record=read_record(games/(name+'.json.gz'),identity,spec)
            new=compact(record)
            old_record=read_record(control/'games'/(name+'.json.gz'),control_id,spec)
            prior=[t for t in old_record['trace'] if t['view']['round']<18]
            now=[t for t in record['trace'] if t['view']['round']<18]
            if prior!=now: raise ValueError('Pre-round18 decisions changed: '+name)
            route='fresh'
        else:
            new=old; route='unchanged_by_source_proof'
        pairs.append(dict(name=name,lords=spec['setup']['lords'],route=route,before=old,after=new,
            round_delta=new['rounds']-old['rounds'],winner_changed=new['outcome']['winner']!=old['outcome']['winner'],
            ending_changed=new['outcome']['win_by']!=old['outcome']['win_by']))
    report=dict(before=totals([p['before'] for p in pairs]),after=totals([p['after'] for p in pairs]),
        fresh_games=len(eligible),reused_unaffected_games=len(specs)-len(eligible),source_proof=proof,
        baseline_manifest_sha256=fingerprint(control_id),candidate_manifest_sha256=fingerprint(identity),
        changed_duration=sum(p['round_delta']!=0 for p in pairs),winner_changes=sum(p['winner_changed'] for p in pairs),
        ending_changes=sum(p['ending_changed'] for p in pairs),pairs=pairs)
    report['mean_round_delta']=report['after']['mean_rounds']-report['before']['mean_rounds']
    atomic_json(output/'soul-timing-comparison.json',report)
    print(json.dumps({k:v for k,v in report.items() if k!='pairs'},indent=2),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--frozen',action='store_true')
    args=parser.parse_args();baseline=args.baseline.resolve();output=args.output.resolve()
    if args.frozen: execute(output,baseline);return 0
    root=Path(__file__).resolve().parents[2]
    source_proof(baseline,root)
    output.mkdir(parents=True,exist_ok=False)
    frozen=freeze(root,output)
    env=dict(os.environ);env.pop('PYTHONPATH',None)
    checks=subprocess.run([sys.executable,'-m','unittest','u13_doctrine.test_split_ward',
        'u13_doctrine.test_ward_recipes','u13_doctrine.test_reserved_recipes',
        'u13_doctrine.test_diagnostics','u13_doctrine.test_recipes_veil'],cwd=frozen/'Scripts/Sim',env=env,
        stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    (output/'focused-python.log').write_text(checks.stdout);print(checks.stdout,flush=True)
    if checks.returncode: return checks.returncode
    code=1
    try:
        with (output/'run.log').open('w') as log:
            proc=subprocess.Popen([sys.executable,'-u',str(frozen/'Scripts/Sim/compare_u13_soul_timing.py'),
                '--frozen','--baseline',str(baseline),'--output',str(output)],cwd=frozen,env=env,
                stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
            for line in proc.stdout: print(line,end='',flush=True);log.write(line);log.flush()
            code=proc.wait()
        return code
    finally:
        atomic_json(output/'run-status.json',dict(status='complete' if code==0 else 'failed_or_interrupted',exit_code=code))
        package(output)


if __name__=='__main__':raise SystemExit(main())
