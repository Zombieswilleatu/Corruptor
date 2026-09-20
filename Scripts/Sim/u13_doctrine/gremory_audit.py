"""Compare V18/V19 on all distinct saved Gremory public boards, without rollouts."""
from collections import Counter
import json
from pathlib import Path

from u13_pysim.copying import copy_data
from u13_pysim.opening import LORDS
from .common import CommonSmartCore, VERSION
from .comparison import freeze_baseline
from .diagnostics import fingerprint
from .facts import Facts
from .lords.gremory import ruin_value
from .observation import observe, Preview
from .survey import atomic_json, read_record
from .test_common import planning
from .web_comparison import load_package

BASELINE = '3aea19d43d840d6ea3c05287d9f8dd4832b6965b'


def run(root, source, output):
    root, source, output = Path(root), Path(source), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    baseline = freeze_baseline(root, BASELINE, output/'baseline')
    old = load_package(output/'baseline')
    old_policy, new_policy = old.CommonSmartCore(), CommonSmartCore()
    manifest = json.loads((source/'manifest.json').read_text())
    counts, rows, seen = Counter(), [], set()
    for spec in manifest['cases']:
        if spec['opponent'] != 'Gremory': continue
        record = read_record(source/'games'/(spec['name']+'.json.gz'), manifest, spec)
        for item in record['trace']:
            v = item['view']
            if Facts(v).kind != 'Gremory': continue
            key = fingerprint(v)
            if key in seen: continue
            seen.add(key); before = copy_data(v)
            decisions = {'old':old_policy.decide(v,lambda p:{'action':'legal'}),
                         'new':new_policy.decide(v,lambda p:{'action':'legal'})}
            assert v == before
            counts['boards'] += 1
            counts['changed_plans'] += decisions['old']['plan'] != decisions['new']['plan']
            measured = {}
            for variant, decision in decisions.items():
                plan = decision['plan']; powers = [s for s in plan['powers'] if s['power_id']=='InevitableRuin']
                casts = [dict(discard_ids=s['cost']['discard_ids'],
                    **ruin_value(Facts(v),s['target']['entity_id'],plan)) for s in powers]
                counts[variant+'_ruin_casts'] += len(casts)
                counts[variant+'_conditional_zero_damage_casts'] += sum(c['damage']==0 for c in casts)
                counts[variant+'_forecast_damage'] += sum(c['damage'] for c in casts)
                counts[variant+'_recipe_orders'] += bool(plan['order'].get('monster_choice'))
                measured[variant] = dict(plan=plan, casts=casts, score=decision['score'], budget=decision['budget'])
            rows.append(dict(case=spec['name'],round=v['round'],seat=v['player_id'],view_sha256=key,**measured))
    unaffected=[]
    for lord in LORDS:
        if lord == 'Gremory': continue
        game=planning(lord); view=observe(game,0)
        before=old_policy.decide(view,Preview(game,0)); after=new_policy.decide(view,Preview(game,0))
        assert before['plan']==after['plan'] and before['score']==after['score'] and before['budget']==after['budget'],lord
        unaffected.append(lord)
    report=dict(schema='U13_GREMORY_RUIN_SAVED_AUDIT_V1',baseline=baseline,baseline_policy=old.VERSION,
        candidate_policy=VERSION,source_manifest_sha256=fingerprint(manifest),counts=dict(counts),
        unaffected_openings=unaffected,cases=rows,
        scope='All distinct Gremory public views from the preceding 16-game Snare cohort; same-board scoring-only previews, no counterfactual matches or win-rate claim. Other eight Lord openings use authoritative legality previews.')
    atomic_json(output/'saved-board-audit.json',report)
    return report


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    report=run(Path(__file__).resolve().parents[3],args.source,args.output)
    print(json.dumps(dict(counts=report['counts'],unaffected_openings=report['unaffected_openings']),sort_keys=True))
