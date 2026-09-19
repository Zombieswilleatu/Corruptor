"""Paired Kurchin Armor/deflection sweep, keeping HP 15 and cadence 6/4.

Run with --output DIRECTORY; --samples and --start-sample select seed ranges.
All overrides are process local. No saved production stats are changed.
"""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import time

from . import monster_pair_balance as pairs
from . import kurchin_armor_experiment as defense

ARMORS = (2, 4, 6, 8, 10)
CHANCES = (0, 50, 75)
VARIANTS = {f'a{armor}_d{chance}': dict(armor=armor, chance=chance)
            for armor in ARMORS for chance in CHANCES}
VARIANTS['penitent_control'] = dict(armor=0, chance=0)
for name, tuning in VARIANTS.items():
    pairs.TUNING[name] = dict(kurchin_hp=15, kurchin_armor=tuning['armor'],
                              deflection=tuning['chance'], melee_interval=34, ranged_interval=50)
    pairs.audit.VARIANTS[name] = dict(armor=0, pursuit='current')

BASE_INSTALL, BASE_INITIAL = pairs.install, pairs.initial


def install(name):
    BASE_INSTALL(name)
    defense.install(pairs.TUNING[name]['deflection'])


def initial(spec):
    world, meta, seed = BASE_INITIAL(spec)
    for unit in world['entities']['entities']:
        if unit['attributes'].get('monster_id') == 'Kurchin':
            armor = pairs.TUNING[spec['variant']]['kurchin_armor']
            unit['attributes'].update(armor=armor, max_armor=armor)
    return world, meta, seed


class Metrics(pairs.DetailedMetrics):
    """Count attacks from the first attempt, including successful deflections."""
    def __init__(self, world, meta):
        super().__init__(world, meta)
        self.incoming = {key: Counter() for key in meta}
        self.first_attempt, self.last_attempt, self.armor_break = {}, {}, {}
        self.armor_left = {u['id']: u['attributes']['armor'] for u in world['entities']['entities']}

    def events(self, events):
        for wrapped in events:
            event = wrapped['event']; d = event['data']
            target_id = None
            if event['type'] in ('MARCHER_MELEE_ATTACK', 'MARCHER_RANGED_ATTACK', 'MONSTER_ATTACK'):
                target_id = d['target']['id']
                if target_id in self.meta and self.hp.get(target_id, 0) > 0:
                    if d['attacker']['owner'] != d['target']['owner']:
                        clock = (d['round']-1)*200+d['tick']
                        self.first_attempt.setdefault(target_id, clock)
                        self.last_attempt[target_id] = clock
                        self.incoming[target_id]['attempts'] += 1
                        if self.armor_left[target_id] > 0:
                            self.incoming[target_id]['armored_attempts'] += 1
                        if d.get('evaded'):
                            self.incoming[target_id]['deflections'] += 1
                else:
                    target_id = None
            before = self.units[target_id]['armor_absorbed'] if target_id else 0
            super().events([wrapped])
            if target_id:
                previous = self.armor_left[target_id]
                self.armor_left[target_id] -= self.units[target_id]['armor_absorbed']-before
                assert self.armor_left[target_id] >= 0
                if previous > 0 and self.armor_left[target_id] == 0:
                    self.armor_break[target_id] = (d['round']-1)*200+d['tick']

    def finish(self, world):
        rows = super().finish(world)
        for u in rows:
            key = u['id']
            u['incoming'] = dict(self.incoming[key])
            u['first_incoming_attempt'] = self.first_attempt.get(key)
            u['last_incoming_attempt'] = self.last_attempt.get(key)
            u['armor_break_tick'] = self.armor_break.get(key)
            u['death_tick'] = self.death_ticks.get(key)
        return rows


pairs.install, pairs.initial, pairs.DetailedMetrics = install, initial, Metrics


def roster(size):
    return {4: ['Butcher', 'Vulture', 'Wright', 'Penitent'],
            6: ['Butcher', 'Vulture', 'Wright', 'Butcher', 'Penitent', 'Penitent'],
            8: ['Butcher', 'Vulture', 'Wright', 'Butcher', 'Penitent', 'Vulture', 'Wright', 'Penitent']}[size]


def specs(samples=16, start_sample=0, variants=None, category=None):
    selected = list(VARIANTS) if variants is None else variants
    result = []

    def add(label, own, enemy, names, kind):
        if category and category != kind: return
        for variant in names:
            if variant not in selected: continue
            team = own[:-1]+['Penitent'] if variant == 'penitent_control' else own
            for sample in range(start_sample, start_sample+samples):
                for seat in (0, 1):
                    result.append(dict(mode='armor_sweep', category=kind, focus=team[-1], opponent=label,
                        teams=[team, enemy], variant=variant, sample=sample, seat=seat,
                        layout='spawn', cadence_metrics=True))

    candidates = [v for v in VARIANTS if v != 'penitent_control']
    for basic in pairs.audit.recruitment.SUITS:
        for count in (1, 2, 3):
            add(f'{count}_{basic}', ['Kurchin'], [basic]*count, candidates, 'solo')
    for size in (4, 6, 8):
        balanced = roster(size)
        add(f'mixed{size}', ['Kurchin'], balanced, candidates, 'solo')
        own = balanced[:-1]+['Kurchin']
        for label, enemy in [('balanced', balanced),
                            ('melee', ['Butcher']*round(size*.6)+['Penitent']*(size-round(size*.6))),
                            ('ranged', ['Vulture']*round(size*.65)+['Penitent']*(size-round(size*.65)))]:
            add(f'{size}_{label}', own, enemy, list(VARIANTS), 'squad')
    return result


def run(spec, export=None):
    record = pairs.run(spec, export)
    focal = next(u for u in record['units'] if u['focal'])
    first, death = focal['first_incoming_attempt'], focal['death_tick']
    allies = [u for u in record['units'] if u['group'] == 0 and not u['focal']]
    alive = focal['deaths'] == 0 and focal['banished'] == 0
    # Survivors are tracked separately; conditional death times never imply
    # that a surviving tank lived for only the average time of tanks that died.
    record['defense'] = dict(first_attempt_tick=first, death_tick=death,
        combat_survival_rounds=None if first is None or death is None else (death-first)/200,
        alive=alive, exposed=first is not None, ally_bodies=len(allies),
        ally_deaths=sum(u['deaths'] for u in allies), ally_kills=sum(u['kills'] for u in allies),
        ally_hp_taken=sum(u['hp_taken'] for u in allies), ally_armor_absorbed=sum(u['armor_absorbed'] for u in allies),
        took_first_own_hit=first is not None and first == min((u['first_incoming_attempt'] for u in record['units']
            if u['group'] == 0 and u['first_incoming_attempt'] is not None), default=first))
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--samples', type=int, default=16)
    parser.add_argument('--start-sample', type=int, default=0)
    parser.add_argument('--workers', type=int, default=6)
    parser.add_argument('--variants', nargs='+', choices=list(VARIANTS))
    parser.add_argument('--category', choices=['solo', 'squad'])
    args = parser.parse_args()
    jobs = specs(args.samples, args.start_sample, args.variants, args.category)
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = dict(schema='U13_KURCHIN_ARMOR_SWEEP_V1', trials=len(jobs), samples=args.samples,
        start_sample=args.start_sample, selected_variants=args.variants, category=args.category,
        hp=15, melee_interval=34, ranged_interval=50, variants=VARIANTS,
        base='d853e23af35aa6f42ddb4f884a5cefc5e5941b88',
        revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        source_sha256={f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(Path(__file__).parent.glob('*.py'))})
    (args.output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    started = time.monotonic()
    with (args.output/'battles.jsonl').open('w') as stream, ProcessPoolExecutor(max_workers=args.workers) as pool:
        for i, record in enumerate(pool.map(run, jobs, chunksize=4), 1):
            stream.write(json.dumps(record, separators=(',', ':'))+'\n')
            if i % 500 == 0 or i == len(jobs):
                stream.flush()
                print(f'{i}/{len(jobs)} in {time.monotonic()-started:.1f}s', flush=True)


if __name__ == '__main__': main()
