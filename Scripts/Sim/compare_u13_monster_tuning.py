#!/usr/bin/env python3
"""Bounded tuning comparisons on the published additive/monster-army inputs."""
import argparse
from concurrent.futures import ProcessPoolExecutor
import json
from pathlib import Path
import time

import audit_u13_monsters as audit
from u13_pysim.copying import copy_data

DEFAULT_TUNING = dict(audit.monsters.TUNING)


def trial(task):
    record, variant = task
    audit.monsters.TUNING.clear()
    audit.monsters.TUNING.update(DEFAULT_TUNING)
    audit.monsters.TUNING.update(variant.get('tuning', {}))
    record = copy_data(record)
    record['world']['data']['monsters']['version'] = audit.monsters.VERSION
    for unit in record['world']['entities']['entities']:
        if audit.name(unit) == variant['monster']:
            unit['attributes'].update(variant.get('attributes', {}))
    result = audit.controlled((record, 16))
    result.pop('parity')
    result['variant_name'] = variant['name']
    result['subject'] = variant['monster']
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--initials', type=Path, nargs='+', required=True)
    p.add_argument('--variants', type=Path, required=True)
    p.add_argument('--workers', type=int, default=6)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    variants = json.loads(args.variants.read_text())
    records = [r for path in args.initials for r in audit.read_rows(path) if not r['reflected']]
    tasks = [(r, v) for v in variants for r in records
             if (r['group'] == 'additive' and r['focus'] == v['monster'] and r['variant'] == 'with')
             or (r['group'] == 'monster_army' and v['monster'] in r['case'].split(':')[1:])]
    results = []
    start = time.monotonic()
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(trial, tasks, chunksize=8):
            results.append(result)
            if len(results) % 240 == 0:
                print('GRID', len(results), '/', len(tasks), result['variant_name'], f'{time.monotonic()-start:.1f}s', flush=True)
    audit.dump(args.output, dict(variants=variants, rules_version=audit.monsters.VERSION,
                                seats='normal; reflections validated separately', battles=results))
    print('Saved', len(results), 'fights', flush=True)


if __name__ == '__main__':
    main()
