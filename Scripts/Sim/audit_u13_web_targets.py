#!/usr/bin/env python3
"""Same-board target audit from prior V16 traces; not a full-game strength test."""
import argparse
import gzip
import importlib
import json
from pathlib import Path
from u13_doctrine import orias_tactics as new
from u13_doctrine.comparison import freeze_baseline
from u13_doctrine.coordination import context
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.facts import Facts, LANES
from u13_doctrine.survey import atomic_json
from u13_doctrine.web_comparison import BASELINE, load_package, snare_identity

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--records',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();root=Path(__file__).resolve().parents[2]
    args.output.mkdir(parents=True,exist_ok=True)
    frozen=freeze_baseline(root,BASELINE,args.output/'baseline')
    package=load_package(args.output/'baseline').__package__
    old=importlib.import_module(package+'.orias_tactics')
    rows=[]
    for path in sorted((args.records/'games').glob('*__new.json.gz')):
        record=json.load(gzip.open(path,'rt'))
        if record['status']!='complete':continue
        choices=[]
        for t in record['trace']:
            if t['view']['player_id']!=record['spec']['focal_seat']:continue
            for web in t['decision'].get('orias',{}).get('selected',[]):
                if web['power']=='Web':choices.append((len(web['initial_hits']),-t['view']['round'],t))
        if not choices:continue
        # One dense saved decision per game, chosen by the original trace only.
        _,_,t=max(choices,key=lambda x:x[:2]);v=t['view'];before=fingerprint(v);f=Facts(v)
        values={}
        for label,module in [('previous',old),('revised',new)]:
            options=[]
            for lane in LANES:
                for target in module.web_targets(f,lane):
                    score=module.web_value(f,target)
                    options.append(dict(target=target,**score))
            values[label]=min(options,key=lambda o:(-o['score'],fingerprint(o['target'])))
        actual=t['decision']['plan'];ctx=context(f,actual)
        snare_equal=old.snare_value(f,actual,ctx)==new.snare_value(f,actual,ctx)
        if not snare_equal or fingerprint(v)!=before:raise ValueError('Changed Snare result or mutated saved view')
        rows.append(dict(game=record['spec']['name'],round=v['round'],view_sha256=before,
            source_record_sha256=__import__('hashlib').sha256(path.read_bytes()).hexdigest(),snare_identical=True,
            previous=values['previous'],revised=values['revised']))
    result=dict(scope='Largest-original-hit Web decision from each completed V16 game. Compare standalone target rankings on identical public boards; not admitted complete-plan choices or match outcomes.',
        baseline=frozen,snare_functions_sha256=snare_identity(root/'Scripts/Sim/u13_doctrine/orias_tactics.py'),boards=len(rows),
        more_hits=sum(len(r['revised']['initial_hits'])>len(r['previous']['initial_hits']) for r in rows),
        fewer_hits=sum(len(r['revised']['initial_hits'])<len(r['previous']['initial_hits']) for r in rows),
        same_hits=sum(len(r['revised']['initial_hits'])==len(r['previous']['initial_hits']) for r in rows),
        previous_hits=sum(len(r['previous']['initial_hits']) for r in rows),
        revised_hits=sum(len(r['revised']['initial_hits']) for r in rows),rows=rows)
    atomic_json(args.output/'saved-board-audit.json',result)
    print(json.dumps({k:v for k,v in result.items() if k not in ('rows','baseline')},indent=2))
