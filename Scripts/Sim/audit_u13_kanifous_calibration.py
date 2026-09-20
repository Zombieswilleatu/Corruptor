#!/usr/bin/env python3
"""Saved-order score audit and legal opening decisions; no new full games."""
import argparse
from collections import Counter
import json
from pathlib import Path

from u13_pysim.power_match import PowerMatch
from u13_pysim.verify import source_identity
from u13_doctrine import lords
from u13_doctrine.common import CommonSmartCore
from u13_doctrine.comparison import freeze_baseline
from u13_doctrine.coordination import context
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.facts import Facts
from u13_doctrine.kanifous_calibration import controls,CONTROL
from u13_doctrine.kanifous_tactics import PROFILES, choices, wish_value
from u13_doctrine.observation import observe,Preview
from u13_doctrine.survey import atomic_json
from u13_doctrine.test_common import planning,CommonTests
from u13_doctrine.web_comparison import load_package


def run(root,source,directory):
    directory.mkdir(parents=True,exist_ok=True)
    records,provenance=controls(source,source_identity(root)[1])
    freeze_baseline(root,CONTROL,directory/'frozen-v20');old=load_package(directory/'frozen-v20')
    counts={p:Counter() for p in PROFILES};openings={p:Counter() for p in PROFILES};details=[]
    verified=0;boards=0
    for record in records.values():
        for item in record['trace']:
            f=Facts(item['view']);plan=item['decision']['plan'];ctx=context(f,plan);boards+=1
            source_choices=[(n,t) for n,t in choices(f) if f.available(n)[0]]
            for profile in PROFILES:
                f.wish_profile=profile
                scored=[(wish_value(f,n,t,plan,ctx)['score'],n) for n,t in source_choices]
                positive=[r for r in scored if r[0]>0]
                pick=max(positive,key=lambda r:r[0])[1] if positive else 'Hold'
                counts[profile][pick]+=1
                counts[profile]['positive_wealth']+=any(n=='WishWealth' and score>0 for score,n in scored)
                if profile=='v20':
                    for row in item['decision']['kanifous']['selected']:
                        value=wish_value(f,row['power'],row['target'],plan,ctx)
                        assert (value['score'],value['benefit'],value['price'])==(row['score'],row['benefit'],row['price'])
                        verified+=1
        game=PowerMatch(record['spec']['setup'])
        for op in record['operations']:
            if op['kind']=='submit':break
            assert game.apply(op)['action']!='invalid'
        seat=record['spec']['focal_seat'];view=observe(game,seat)
        assert fingerprint(view)==fingerprint(record['trace'][0]['view'])
        reference=old.CommonSmartCore().decide(view,Preview(game,seat))
        for profile in PROFILES:
            decision=CommonSmartCore(wish_profile=profile).decide(view,Preview(game,seat))
            assert Preview(game,seat)(decision['plan'])['action']=='legal'
            if profile=='v20':
                assert all(decision[k]==reference[k] for k in ('plan','score','budget'))
            names=[s['power_id'] for s in decision['plan']['powers']]
            assert len(names)<=1
            openings[profile][','.join(names) if names else 'Hold']+=1
            details.append(dict(case=record['spec']['pair_id'],profile=profile,powers=names,score=decision['score']))
    unaffected=[]
    games=[(name,planning(name)) for name in lords.MODULES if name!='Kanifous']
    games.append(('BreachWish',CommonTests().breach_planning()[0]))
    for name,game in games:
        v=observe(game,0);a=old.CommonSmartCore().decide(v,Preview(game,0));b=CommonSmartCore().decide(v,Preview(game,0))
        assert all(a[k]==b[k] for k in ('plan','score','budget')),name
        unaffected.append(name)
    result=dict(source_zip_sha256=provenance['zip_sha256'],boards=boards,v20_native_scores_reproduced=verified,
        fixed_order_wish_ranking={p:dict(c) for p,c in counts.items()},legal_opening_choices={p:dict(c) for p,c in openings.items()},
        opening_details=details,unchanged_non_native_cases=unaffected,
        scope='Fixed saved V20 orders ranked under each profile, not whole-plan counterfactuals. Opening decisions used reconstructed authority and legal Preview. V20 compatibility verified. No new full games or strength claim.')
    atomic_json(directory/'saved-board-check.json',result)
    print(json.dumps({k:v for k,v in result.items() if k!='opening_details'},indent=2),flush=True)
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
    a=p.parse_args();run(Path(__file__).resolve().parents[2],a.source,a.output)
