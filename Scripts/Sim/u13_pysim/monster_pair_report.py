"""Summarize paired monster and formation experiments and archive every trial."""
import argparse
import gzip
import hashlib
import json
import random
from collections import Counter, defaultdict
from pathlib import Path

from . import monster_pair_balance as experiment


def outcomes(rows):
    counts = Counter(r['outcome'] for r in rows)
    return dict(trials=len(rows), **{k: counts[k] for k in ('win', 'mutual', 'loss', 'unresolved')},
                near_even=sum(r['near_even'] for r in rows))


def metrics(rows, group=0):
    totals = Counter()
    for r in rows:
        for unit in r['units']:
            if unit['group'] == group:
                totals.update({k: unit[k] for k in experiment.audit.METRICS})
    return {k: v/len(rows) for k, v in totals.items()}


def paired_interval(before, after):
    # Both seats use the same seed. Resample seeds, keeping their seats paired.
    index = {(r['spec']['sample'], r['spec']['seat']): r for r in before}
    clusters = defaultdict(list)
    for r in after:
        s = r['spec']; b = index[s['sample'], s['seat']]
        clusters[s['sample']].append(int(r['outcome'] == 'loss')-int(b['outcome'] == 'loss'))
    values = [sum(v)/len(v) for v in clusters.values()]
    rng = random.Random(20260918)
    estimates = sorted(sum(rng.choice(values) for _ in values)/len(values) for _ in range(4000))
    return dict(defender_win_change=sum(values)/len(values), cluster_bootstrap_95=[estimates[99], estimates[3899]], seeds=len(values))


def formation_details(rows):
    ranged = Counter(); first = []; butchers = 0; goals = [0, 0]
    for r in rows:
        ranged.update(r['ranged'])
        for u in r['units']:
            if u['group'] == 1 and u['name'] == 'Butcher':
                butchers += 1
                if u['id'] in r['first_melee']: first.append(r['first_melee'][u['id']])
        goals[0] += r['team_goals'][r['spec']['seat']]
        goals[1] += r['team_goals'][1-r['spec']['seat']]
    shots = sum(n for k, n in ranged.items() if k.startswith('group1_shots_at_'))
    return dict(outcomes=outcomes(rows), ranged=dict(ranged),
                penitent_share_of_shots_at_defending_marchers=ranged['group1_shots_at_Penitent']/shots if shots else None,
                defender_butchers=butchers, defender_butchers_attacking=len(first),
                mean_first_butcher_melee_tick=sum(first)/len(first) if first else None,
                goals_before_combat_cutoff=goals,
                attacking_metrics=metrics(rows), defending_metrics=metrics(rows, 1))


def build(directories, output, verification):
    batches = {}; manifests = {}
    for directory in directories:
        name = directory.name.removeprefix('pair-')
        batches[name] = [json.loads(line) for line in (directory/'battles.jsonl').open()]
        manifests[name] = json.loads((directory/'manifest.json').read_text())
        assert len(batches[name]) == manifests[name]['tasks'], (name, 'incomplete batch')
    result = dict(schema='U13_MONSTER_PAIR_REPORT_V1', manifests=manifests,
                  trials=sum(map(len, batches.values())),
                  unique_fixtures=len({json.dumps(r['spec'], sort_keys=True) for rows in batches.values() for r in rows}),
                  verification=verification,
                  summaries={name: experiment.summarize(rows) for name, rows in batches.items()})
    bench = []
    for name in experiment.audit.monsters.NAMES:
        for count in (1, 2):
            for variant in ('current', 'armor3'):
                rows = [r for r in batches['monsters'] if r['spec']['focus'] == name and r['spec']['opponent'].startswith(f'{count}x') and r['spec']['variant'] == variant]
                bench.append(dict(unit=name, opponents=count, variant=variant, **outcomes(rows), metrics=metrics(rows)))
    result['monster_benchmarks'] = bench
    counter = defaultdict(dict)
    for row in batches['vultures']:
        s = row['spec']; counter[s['opponent']].setdefault(s['variant'], []).append(row)
    result['counter_details'] = {name: {v: formation_details(rows) for v, rows in variants.items()} for name, variants in counter.items()}
    result['formation_intervals'] = {name: paired_interval(variants['current'], variants['penitent_lead90'])
                                     for name, variants in counter.items() if 'penitent_lead90' in variants and not name.endswith('vs_butchers')}
    output.parent.mkdir(parents=True, exist_ok=True)
    archive = output.with_suffix('.jsonl.gz')
    with archive.open('wb') as raw, gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as zipped:
        for name, rows in batches.items():
            for row in sorted(rows, key=lambda r: json.dumps(r['spec'], sort_keys=True)):
                zipped.write((json.dumps(dict(batch=name, **row), separators=(',', ':'))+'\n').encode())
    result['raw_archive'] = dict(path=archive.name, bytes=archive.stat().st_size, sha256=hashlib.sha256(archive.read_bytes()).hexdigest())
    result['final_source_sha256'] = {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(Path(__file__).parent.glob('*.py'))}
    output.write_text(json.dumps(result, indent=2)+'\n')
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('directories', nargs='+', type=Path)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--verification', required=True, type=Path)
    args = p.parse_args()
    result = build(args.directories, args.output, json.loads(args.verification.read_text()))
    print(json.dumps({k: result[k] for k in ('trials', 'unique_fixtures', 'raw_archive')}))


if __name__ == '__main__': main()
