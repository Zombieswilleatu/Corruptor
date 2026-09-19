#!/usr/bin/env python3
"""Bounded charm calibration and lifetime counts from native continuous tapes."""
import argparse
from collections import Counter, defaultdict
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import json
import hashlib
import time

import audit_u13_monsters as audit


def trial(task):
    record, chance = task
    audit.monsters.TUNING['fyra_charm_chance'] = chance
    result = audit.controlled((record, 16))
    return dict(chance=chance, case=result['case'], seed_index=result['seed_index'],
                reflected=result['reflected'], winner=result['winner'], rounds=result['rounds'],
                charms=result['metrics'].get('Fyra', {}).get('charm_procs', 0))


def grid(args):
    records = list(audit.read_rows(args.initials))
    assert records and all(sum(row['attributes'].get('monster_id') == 'Fyra'
                              for row in r['world']['entities']['entities']) == 1 for r in records)
    started = time.monotonic()
    results = []
    totals = defaultdict(Counter)
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        tasks = ((r, chance) for chance in args.chances for r in records)
        for r in pool.map(trial, tasks, chunksize=8):
            results.append(r)
            totals[r['chance']].update(summons=1, charms=r['charms'],
                wins=int(r['winner'] == 0), losses=int(r['winner'] == 1), draws=int(r['winner'] is None))
            if len(results) % len(records) == 0:
                print('CHARM GRID', r['chance'], dict(totals[r['chance']]), flush=True)
    audit.dump(args.output, dict(chances=args.chances, paired_seats=True, scenarios=len(records),
                                monster_version=audit.monsters.VERSION,
                                initials_sha256=hashlib.sha256(args.initials.read_bytes()).hexdigest(),
                                totals={k: dict(v) for k,v in totals.items()}, battles=results,
                                elapsed_seconds=time.monotonic()-started))


def cohorts(args):
    games = []
    for path in sorted(args.directory.glob('waves-[0-9][0-9]-[01].jsonl')):
        rows = list(audit.read_rows(path))
        assert rows[-1]['kind'] == 'finished', str(path)
        born, deployed, charms = {}, set(), Counter()
        for record in rows[1:-1]:
            for row in record['before']+record['staged']:
                if audit.name(row) == 'Fyra': born.setdefault(row['id'], record['round'])
            deployed.update(row['id'] for row in record['before'] if audit.name(row) == 'Fyra')
            for event in record['events']:
                if event['type'] == 'MONSTER_CHARMED': charms[event['data']['source_id']] += 1
        final = rows[-1]['world']
        # The native final world contains protected reserves separately.
        active = {row['id'] for row in final['entities']['entities']}
        # Last-before reserves can have been released; a never-deployed unit
        # is censored regardless of the staging storage's internal shape.
        completed = deployed-active
        games.append(dict(seed=rows[0]['seed'], swapped=rows[0]['swapped'],
            summons=len(born), deployed=len(deployed), completed_lifetimes=len(completed),
            charms=sum(charms.values()), completed_charms=sum(charms[x] for x in completed),
            charmed_at_least_once=sum(charms[x] > 0 for x in born),
            lifetimes=[dict(id=x, first_seen_round=born[x], deployed=x in deployed,
                            completed=x in completed, charms=charms[x]) for x in sorted(born)]))
    assert games, 'No native continuous battle tapes found'
    counts = Counter()
    for game in games: counts.update({k:v for k,v in game.items() if k not in ('seed', 'swapped', 'lifetimes')})
    result = dict(games=games, totals=dict(counts),
                  charms_per_summon=counts['charms']/max(1, counts['summons']),
                  charms_per_completed_lifetime=counts['completed_charms']/max(1, counts['completed_lifetimes']))
    audit.dump(args.output, result)
    print(json.dumps({k:v for k,v in result.items() if k != 'games'}, indent=2), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    p = sub.add_parser('charm-grid')
    p.add_argument('--initials', type=Path, required=True)
    p.add_argument('--chances', type=int, nargs='+', default=[45, 60, 75, 90, 100])
    p.add_argument('--workers', type=int, default=4)
    p.add_argument('--output', type=Path, required=True)
    p = sub.add_parser('cohorts')
    p.add_argument('--directory', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.mode == 'charm-grid': grid(args)
    else: cohorts(args)


if __name__ == '__main__': main()
