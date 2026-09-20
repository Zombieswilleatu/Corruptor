"""Re-score saved V17 Snare casts on identical public boards before new games."""
from collections import Counter
import json
from pathlib import Path

from .common import CommonSmartCore, VERSION
from .coordination import context
from .diagnostics import fingerprint
from .facts import Facts
from .orias_tactics import snare_value
from .survey import atomic_json, read_record


def run(source, output):
    source = Path(source)
    manifest = json.loads((source/'manifest.json').read_text())
    rows, counts = [], Counter()
    for spec in manifest['cases']:
        if spec['variant'] != 'new': continue
        record = read_record(source/'games'/(spec['name']+'.json.gz'), manifest, spec)
        orders = {r['round']: r['action'] for r in record['semantic']['diagnostics']['orias_observed']['orders']}
        for item in record['trace']:
            v, d = item['view'], item['decision']
            if v['player_id'] != spec['focal_seat']: continue
            old = next((s for s in d.get('orias', {}).get('selected', []) if s['power'] == 'Snare'), None)
            if old is None: continue
            f = Facts(v); p = d['plan']
            value = snare_value(f, p, context(f, p))
            # Saved views do not contain an authoritative mutable game. This
            # isolates scoring; legality is checked separately in full games.
            new = CommonSmartCore().decide(v, lambda plan: {'action': 'legal'})
            selected = next((s for s in new['orias']['selected'] if s['power'] == 'Snare'), None)
            risk = 'above_two' if value['cost']['selective'] else 'at_most_two'
            counts['saved_casts'] += 1
            counts[risk] += 1
            counts['positive_fixed_plan'] += value['score'] > 0
            counts['new_selected'] += selected is not None
            counts['new_selected_'+risk] += selected is not None
            counts['old_next_'+orders.get(v['round']+1, 'unobserved')] += 1
            rows.append(dict(case=spec['name'], round=v['round'], view_sha256=fingerprint(v),
                old=old, old_next_action=orders.get(v['round']+1), new_same_plan=value,
                new_selected=selected, new_order=new['plan']['order'], new_budget=new['budget']))
    report = dict(source_manifest_sha256=fingerprint(manifest), source_policy=manifest['candidate_policy'],
        candidate_policy=VERSION, counts=dict(counts), cases=rows,
        scope='All saved V17 Snare casts from the fixed 16-game Web campaign. Same public boards; no simulated future draws. Re-decisions use scoring-only preview, not authority admission or counterfactual match outcomes.')
    atomic_json(Path(output), report)
    return report


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(run(args.source, args.output)['counts'], sort_keys=True))
