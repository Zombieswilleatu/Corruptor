"""Archive paired Kurchin survival trials, separating prevention from Armor."""
import argparse
import gzip
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path
from statistics import mean


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directories', nargs='+', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--verification', required=True, type=Path)
    args = parser.parse_args()
    rows, manifests = [], {}
    for directory in args.directories:
        batch = [json.loads(line) for line in (directory/'battles.jsonl').open()]
        manifest = json.loads((directory/'manifest.json').read_text())
        assert len(batch) == manifest['tasks'], (directory, 'incomplete batch')
        manifests[directory.name] = manifest
        rows.extend(batch)
    rows.sort(key=lambda row: json.dumps(row['spec'], sort_keys=True))
    groups = defaultdict(list)
    for row in rows:
        groups[(row['spec']['opponent'], row['spec']['variant'])].append(row)
    summaries = []
    for (opponent, variant), group in sorted(groups.items()):
        tanks = [unit for row in group for unit in row['units'] if unit['focal']]
        dead = [row['tank']['ticks_to_death'] for row in group if row['tank']['ticks_to_death'] is not None]
        summaries.append(dict(opponent=opponent, variant=variant, trials=len(group),
            outcomes=dict(Counter(row['outcome'] for row in group)),
            alive=sum(row['tank']['alive'] for row in group),
            mean_ticks_to_death_when_dead=mean(dead) if dead else None,
            mean_hp_taken=mean(unit['hp_taken'] for unit in tanks),
            mean_armor_absorbed=mean(unit['armor_absorbed'] for unit in tanks),
            mean_damage_prevented=mean(row['tank'].get('damage_prevented', 0) for row in group),
            mean_hp_damage=mean(unit['hp_damage'] for unit in tanks),
            mean_kills=mean(unit['kills'] for unit in tanks),
            goal_arrivals=sum(unit['goals'] for unit in tanks),
            ally_deaths=sum(row['tank']['ally_deaths'] for row in group),
            mean_ally_hp_taken=mean(row['tank']['ally_hp_taken'] for row in group),
            mean_ally_hp_damage=mean(row['tank']['ally_hp_damage'] for row in group)))
    archive = args.output.with_suffix('.jsonl.gz')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with archive.open('wb') as raw, gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as zipped:
        for row in rows: zipped.write((json.dumps(row, separators=(',', ':'))+'\n').encode())
    result = dict(schema='U13_KURCHIN_TANK_REPORT_V1', trials=len(rows),
        unique_fixtures=len({json.dumps(row['spec'], sort_keys=True) for row in rows}),
        definitions=dict(ticks_to_death='Death tick minus first landed hostile attack tick; conditional on death, not survivor lifetime.',
            damage_prevented='Incoming positive attack reduction before Armor, minimum one. Excludes blocked/evaded hits and shots against already-dead targets.',
            goals='Arrivals before combat cutoff only; not a complete-game goal rate.'),
        manifests=manifests, summaries=summaries, verification=json.loads(args.verification.read_text()),
        source_sha256={file.name: hashlib.sha256(file.read_bytes()).hexdigest() for file in sorted(Path(__file__).parent.glob('*.py'))},
        raw_archive=dict(path=archive.name, bytes=archive.stat().st_size, sha256=hashlib.sha256(archive.read_bytes()).hexdigest()))
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({key:result[key] for key in ('trials','unique_fixtures','raw_archive')}))


if __name__ == '__main__': main()
