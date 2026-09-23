#!/usr/bin/env python3
"""Replay the native printed-value corpus independently in Python."""
import argparse
import json
from pathlib import Path
from u13_pysim.codec import loads, first_difference
from u13_pysim.resolution import resolve
from u13_doctrine.facts import Facts


def verify(path):
    suite = loads(Path(path).read_text())
    assert suite['schema'] == 'U13_PRINTED_COMMITMENTS_V1'
    assert len(suite['cases']) == 46
    checks = 0
    for i, case in enumerate(suite['cases']):
        w, c = case['world'], case['context']
        actual = resolve(w, c['round'], c['seed'], c['player_order'], c['hook'], c['combat_orders'])
        difference = first_difference(dict(result=case['result'], world=case['after']), actual)
        if difference: raise AssertionError(f'case {i}: {difference}')
        checks += 1
        for pid, expected in [(0, case['expected_attack']), (1, case['expected_ward'])]:
            ids = c['combat_orders'][pid]['card_ids']
            rows = w['entities']['entities']
            view = dict(player_id=pid, players=w['players'], data=w['data'],
                        board=[r for r in rows if r['kind'] != 'card' or r['attributes'].get('role') == 'guard'],
                        hand=[r for r in rows if r['id'] in ids])
            facts = Facts(view)
            assert facts.strength(ids, c['combat_orders'][pid]['action']) == expected, (i, pid, 'bot strength')
            # The same printed total must fund an exact-value payment, even
            # for a formerly penalized suit; one more must be unaffordable.
            for exempt in [None, 'Butcher', 'Penitent']:
                assert set(facts.payment(expected, exempt)) == set(ids), (i, pid, exempt, 'payment')
                assert facts.payment(expected + 1, exempt) == [], (i, pid, exempt, 'over-budget')
            checks += 7
    return dict(native_cases_matched=46, python_checks=checks,
                scope='Exact world and public/private event parity through combat resolution, plus bot strength and payment thresholds')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('native_cases', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = verify(args.native_cases)
    if args.report: args.report.write_text(json.dumps(result, indent=2)+'\n')
    print('PASS', json.dumps(result, sort_keys=True))

if __name__ == '__main__': main()
