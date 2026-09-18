"""Archive the HP follow-up without rewriting the preceding balance evidence."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

from . import monster_pair_balance as experiment
from .monster_pair_report import outcomes, metrics


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('directories', nargs='+', type=Path)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--baseline', required=True, type=Path)
    p.add_argument('--verification', required=True, type=Path)
    args = p.parse_args()
    baseline = json.loads(args.baseline.read_text())
    batches, manifests = {}, {}
    for directory in args.directories:
        name = directory.name.removeprefix('pair-')
        batches[name] = [json.loads(line) for line in (directory/'battles.jsonl').open()]
        manifests[name] = json.loads((directory/'manifest.json').read_text())
        assert len(batches[name]) == manifests[name]['tasks'], (name, 'incomplete batch')
    comparison = list(baseline['monster_benchmarks'])
    for name in experiment.audit.monsters.NAMES:
        for count in (1, 2):
            for variant in ('hp2', 'armor2x'):
                rows = [r for r in batches['hp-armor'] if r['spec']['focus'] == name and r['spec']['opponent'].startswith(f'{count}x') and r['spec']['variant'] == variant]
                comparison.append(dict(unit=name, opponents=count, variant=variant, **outcomes(rows), metrics=metrics(rows)))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    archive = args.output.with_suffix('.jsonl.gz')
    with archive.open('wb') as raw, gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as zipped:
        for name, rows in batches.items():
            for row in sorted(rows, key=lambda r: json.dumps(r['spec'], sort_keys=True)):
                zipped.write((json.dumps(dict(batch=name, **row), separators=(',', ':'))+'\n').encode())
    result = dict(schema='U13_MONSTER_HP_REPORT_V1', baseline_report=args.baseline.name,
                  manifests=manifests, trials=sum(map(len, batches.values())),
                  unique_fixtures=len({json.dumps(r['spec'], sort_keys=True) for rows in batches.values() for r in rows}),
                  comparison=comparison, summaries={name: experiment.summarize(rows) for name, rows in batches.items()},
                  verification=json.loads(args.verification.read_text()),
                  final_source_sha256={f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(Path(__file__).parent.glob('*.py'))},
                  raw_archive=dict(path=archive.name, bytes=archive.stat().st_size, sha256=hashlib.sha256(archive.read_bytes()).hexdigest()))
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: result[k] for k in ('trials', 'unique_fixtures', 'raw_archive')}))


if __name__ == '__main__': main()
