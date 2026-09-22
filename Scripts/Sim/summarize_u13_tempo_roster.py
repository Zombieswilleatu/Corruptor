#!/usr/bin/env python3
"""Validate and summarize a completed tempo roster screen; no new games."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
from statistics import mean, median

from run_u13_lord_balance import verify_frozen
from u13_doctrine.survey import read_record, atomic_json
from u13_doctrine.diagnostics import fingerprint


def summarize(output):
    verify_frozen(output)
    identity = json.loads((output/'manifest.json').read_text())
    config = json.loads((output/'split-config.json').read_text())
    rows, counts, seats, mirrors, methods = [], Counter(), Counter(), Counter(), Counter()
    pairs = defaultdict(list)
    for spec in config['cases']:
        record = read_record(output/'games'/(spec['name']+'.json.gz'), identity, spec)
        if record['status'] != 'complete': raise ValueError('Incomplete: '+spec['name'])
        game = record['semantic']; diagnostics = game['diagnostics']
        assert fingerprint(record['operations']) == game['decisions_sha256']
        winner, number = game['outcome']['winner'], game['rounds']
        left, right = spec['setup']['lords']; method = game['outcome']['win_by']
        assert winner in (0, 1) and number <= 25
        counts.update(diagnostics['split_trial'])
        counts['rejected_previews'] += len(diagnostics['rejected_previews'])
        counts['games'] += 1
        counts['under15' if number < 15 else '15to20' if number <= 20 else 'over20'] += 1
        methods[method] += 1
        boosted = any(int(k) > 0 for k in diagnostics['attack_escalation_first_round'])
        counts['early_without_attack_escalation'] += number < 15 and not boosted
        (mirrors if left == right else seats)[str(winner)] += 1
        finish = diagnostics['victory_race']
        row = dict(name=spec['name'], lords=[left,right], repeat=spec['repeat'],
                   seed=spec['setup']['seed'], rounds=number, winner=winner,
                   winner_lord=spec['setup']['lords'][winner], win_by=method,
                   finish=finish, attack_escalation_first_round=diagnostics['attack_escalation_first_round'],
                   rejected_previews=len(diagnostics['rejected_previews']))
        rows.append(row)
        if left != right: pairs[spec['setup']['seed']].append(row)
    paired = Counter()
    for pair in pairs.values():
        assert len(pair) == 2 and pair[0]['lords'] == list(reversed(pair[1]['lords']))
        if pair[0]['winner'] == pair[1]['winner']:
            paired['both_won_by_seat_'+str(pair[0]['winner'])] += 1
        else:
            assert pair[0]['winner_lord'] == pair[1]['winner_lord']
            paired['same_lord_won_both_seats'] += 1
    report = dict(scope='Current experimental tempo rules only; 162 games, two seeds per ordered matchup. Seat associations do not isolate causation.',
        counts=counts, endings=methods, non_mirror_seat_wins=seats, mirror_seat_wins=mirrors,
        paired_seat_results=paired, rounds=dict(mean=mean(r['rounds'] for r in rows),
            median=median(r['rounds'] for r in rows), minimum=min(r['rounds'] for r in rows),
            maximum=max(r['rounds'] for r in rows)), games=rows,
        manifest_sha256=fingerprint(identity), frozen_source_sha256=fingerprint(json.loads((output/'frozen-source.json').read_text())))
    atomic_json(output/'tempo-roster-summary.json',report)
    print(json.dumps({k:v for k,v in report.items() if k != 'games'},indent=2))
    return report


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output',type=Path)
    summarize(parser.parse_args().output.resolve())
