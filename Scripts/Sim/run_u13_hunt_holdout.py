#!/usr/bin/env python3
"""Fresh 64-pair holdout, fixed two-worker pool and prespecified ship screen."""
import argparse,gzip,hashlib,json,multiprocessing,subprocess
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor,as_completed
from collections import Counter
from u13_doctrine import planner_probe
from u13_doctrine.common import Weights
from u13_doctrine.survey import TracedPolicy
from u13_doctrine.diagnostics import fingerprint


def run_one(spec,arm,weights,output):
    if arm=='treatment':
        from run_u13_hunger_hunt_doctrine_sample import install_doctrine
        install_doctrine()
    policy=TracedPolicy(Weights(**weights))
    semantic,timing,ops=planner_probe.run_case(dict(spec,name=spec['name']+'_'+arm),policy)
    for op in ops:
        if op['kind']=='submit':
            for plan in op['plans']:
                for power in plan['powers']:
                    if power['power_id']=='Consume':assert power['target']=={'mode':'guard_bounce'}
    seat=spec['setup']['lords'].index('Kroni')
    groups=[g for g in semantic['diagnostics']['groups'] if g['seat']!=seat and g['term']=='Hunt']
    counts=Counter()
    for group in groups:
        counts['hunts']+=group['flags']['selected']['true']
        counts.update({k:group['metrics'].get(k,0) for k in ['banished','guards_defeated']})
    row=dict(name=spec['name'],arm=arm,setup=spec['setup'],kroni_seat=seat,opponent=spec['setup']['lords'][1-seat],outcome=semantic['outcome'],counts=dict(counts),rejected_previews=semantic['diagnostics']['rejected_previews'],timing=timing)
    with gzip.open(Path(output)/(spec['name']+'_'+arm+'.json.gz'),'wt') as f:
        json.dump(dict(result=row,semantic=semantic,semantic_sha256=fingerprint(semantic),operations=ops,trace=policy.trace),f)
    return row


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--baseline',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=True)
    assert not (a.output/'summary.json').exists(), 'Use a new output directory'
    weights=json.loads((a.baseline/'manifest.json').read_text())['weights']
    specs=[]
    for path in sorted((a.baseline/'games').glob('*_01_tempo.json.gz')):
        if path.name.split('_')[:2].count('kroni')!=1:continue
        with gzip.open(path,'rt') as f:template=json.load(f)['spec']
        for repeat in range(4):
            setup=dict(template['setup']);pair=':'.join(sorted(setup['lords']))
            setup['seed']=f'u13-kroni-hunt-holdout-20260922:{pair}:{repeat:02}'
            specs.append(dict(name='_'.join(x.lower() for x in setup['lords'])+f'_{repeat:02}',setup=setup))
    assert len(specs)==64 and len({x['setup']['seed'] for x in specs})==32
    source=Path(__file__).resolve().parent
    def hashes():return {str(x.relative_to(source)):hashlib.sha256(x.read_bytes()).hexdigest() for folder in ['u13_pysim','u13_doctrine'] for x in sorted((source/folder).rglob('*.py'))}
    before=hashes()
    report=dict(schema='U13_HUNT_HOLDOUT_V1',workers=2,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),source_sha256=before,runner_sha256={name:hashlib.sha256((source/name).read_bytes()).hexdigest() for name in ['run_u13_hunt_holdout.py','run_u13_hunger_hunt_doctrine_sample.py']},weights=weights,criteria=dict(min_kroni_win_rate=.4,max_kroni_win_rate=.65,min_win_rate_reduction=.1,max_extra_cutoff_games=4,functional_failures=0),specs=specs,games=[],failures=[])
    (a.output/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    # One task per child prevents treatment monkeypatches entering control games.
    with ProcessPoolExecutor(max_workers=2,mp_context=multiprocessing.get_context('spawn'),max_tasks_per_child=1) as pool:
        jobs={pool.submit(run_one,s,arm,weights,str(a.output)):(s['name'],arm) for s in specs for arm in ['control','treatment']}
        for future in as_completed(jobs):
            try:
                row=future.result();report['games'].append(row)
                print(json.dumps(dict(done=len(report['games']),name=row['name'],arm=row['arm'],outcome=row['outcome'])),flush=True)
            except Exception as exc:
                report['failures'].append(dict(case=jobs[future],error=repr(exc)));print('FAILED '+repr(jobs[future])+' '+repr(exc),flush=True)
            (a.output/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    assert hashes()==before
    assert not report['failures'] and len(report['games'])==128

if __name__=='__main__':main()
