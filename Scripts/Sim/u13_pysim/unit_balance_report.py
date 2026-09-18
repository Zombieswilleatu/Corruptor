"""Combine completed balance batches, preserving every per-unit trial record.

python -m u13_pysim.unit_balance_report --output docs/evidence/U13_UNIT_BALANCE_2026-09-18 --inputs /scratch/balance-main /scratch/balance-hunt ...
"""
import argparse
import csv
import gzip
import hashlib
import json
import random
from collections import Counter, defaultdict
from pathlib import Path

from .unit_balance import METRICS
from .monsters import NAMES


def focal(row, metric):
    if metric == 'team_goal_edge':
        seat = row['spec']['seat']
        return row['team_goals'][seat]-row['team_goals'][1-seat]
    return sum(u[metric] for u in row['units'] if u['focal'])


def paired_armor(rows, baseline='current', armor3='armor3'):
    """Stratified paired bootstrap: keep both seats of each seed together."""
    result = []
    keys = ('hp_damage', 'kills', 'team_goal_edge')
    rng = random.Random(20260918)
    for name in NAMES:
        paired = defaultdict(dict)
        for row in rows:
            s = row['spec']
            if s['mode'] == 'squad' and s['focus'] == name:
                paired[(s['opponent'], s['sample'], s['seat'])][s['variant']] = row
        seeds = defaultdict(list)
        for (opponent, sample, seat), pair in paired.items():
            assert set(pair) == {baseline, armor3}
            seeds[(opponent, sample)].append([focal(pair[armor3], k)-focal(pair[baseline], k) for k in keys])
        strata = defaultdict(list)
        for (opponent, _), seats in sorted(seeds.items()):
            assert len(seats) == 2
            strata[opponent].append([(a+b)/2 for a, b in zip(*seats)])
        size = len(seeds)
        means = [sum(v[j] for group in strata.values() for v in group)/size for j in range(len(keys))]
        samples = [[] for _ in keys]
        for _ in range(2000):
            picked = [rng.choice(group) for group in strata.values() for _ in group]
            for j in range(len(keys)): samples[j].append(sum(v[j] for v in picked)/size)
        intervals = [sorted(v) for v in samples]
        result.append(dict(unit=name, paired_battles=len(paired), paired_seeds=size,
            differences={key: dict(mean=round(means[j], 4), bootstrap_95=[round(intervals[j][50], 4), round(intervals[j][1949], 4)])
                         for j, key in enumerate(keys)}))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inputs', nargs='+', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    batches = []; all_rows = []
    for directory in args.inputs:
        summary = json.loads((directory/'summary.json').read_text())
        rows = [json.loads(line) for line in (directory/'battles.jsonl').read_text().splitlines()]
        assert len(rows) == summary['tasks'], (directory, 'incomplete batch')
        assert len({json.dumps(r['spec'], sort_keys=True) for r in rows}) == len(rows), 'duplicate trials'
        for row in rows:
            for unit in row['units']:
                assert unit['kills'] == unit['regular_kills']+unit['monster_kills']
                assert all(unit[k] >= 0 for k in METRICS)
        batch = directory.name.removeprefix('balance-')
        batches.append(dict(batch=batch, **summary))
        all_rows.extend(dict(batch=batch, **r) for r in rows)
    all_rows.sort(key=lambda r: (r['batch'], json.dumps(r['spec'], sort_keys=True)))
    archive = args.output.with_suffix('.jsonl.gz')
    with archive.open('wb') as output:
        with gzip.GzipFile(filename='', fileobj=output, mode='wb', mtime=0, compresslevel=9) as compressed:
            for row in all_rows: compressed.write((json.dumps(row, separators=(',', ':'))+'\n').encode())
    original = [r for r in all_rows if r['batch'] == batches[0]['batch']]
    baseline, armor3 = batches[0]['variants']
    control = [r for r in original if r['spec']['variant'] == baseline and r['spec']['seat'] == 0 and
               ((r['spec']['mode'] == 'duel' and r['spec']['focus'] == r['spec']['opponent']) or
                (r['spec']['mode'] == 'squad' and r['spec']['focus'] == 'Butcher' and r['spec']['opponent'] == 'balanced'))]
    leads = Counter('player' if r['team_goals'][0] > r['team_goals'][1] else 'enemy' if r['team_goals'][1] > r['team_goals'][0] else 'tie' for r in control)
    evidence = dict(schema='U13_UNIT_BALANCE_REPORT_V1', battles=len(all_rows),
        phase_rounds=sum(r['rounds'] for r in all_rows), mode_counts=dict(Counter(r['spec']['mode'] for r in all_rows)),
        raw_archive=dict(file=archive.name, sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), bytes=archive.stat().st_size),
        batches=batches, paired_armor3=paired_armor(original, baseline, armor3),
        symmetric_controls=dict(battles=len(control), goal_leads=dict(leads), goals=[sum(r['team_goals'][i] for r in control) for i in (0, 1)]))
    args.output.with_suffix('.json').write_text(json.dumps(evidence, indent=2)+'\n')
    with args.output.with_suffix('.csv').open('w', newline='') as output:
        writer = csv.DictWriter(output, fieldnames=['batch', 'mode', 'variant', 'unit', 'battles', 'summons', *METRICS, 'mean_first_hit_tick'])
        writer.writeheader()
        for batch in batches:
            for row in batch['results']:
                writer.writerow(dict(batch=batch['batch'], **{k: row[k] for k in ('mode', 'variant', 'unit', 'battles', 'summons', 'mean_first_hit_tick')}, **row['per_summon']))
    print(json.dumps({k: v for k, v in evidence.items() if k not in ('batches', 'paired_armor3')}, indent=2))


if __name__ == '__main__': main()
