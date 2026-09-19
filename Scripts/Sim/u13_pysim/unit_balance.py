"""Reproducible unit/squad balance experiments using the accepted Marching engine.

Variants are process-local experiments; this module never changes saved game
rules. Each task uses the same seed, identities and deployment for every variant.
Armor means consumable Armor, not damage reduction. Varn is one 3-5-body summon.
"""
import argparse
import concurrent.futures
import hashlib
import inspect
import json
import platform
import subprocess
import time
from collections import Counter, defaultdict
from pathlib import Path

from . import marching, monsters, monster_effects, recruitment
from .copying import copy_data
from .primitives import Entities, draw
from .unit_balance_variants import legacy_steer

NAMES = tuple(recruitment.SUITS) + monsters.NAMES
BASE_STEP = monster_effects.step
BASE_STEER = monster_effects.steer
VARIANTS = {
    'current': dict(armor=0, pursuit='current'),
    'armor3': dict(armor=3, pursuit='current'),
    'armor1': dict(armor=1, pursuit='direct'),
    'armor2': dict(armor=2, pursuit='direct'),
    'direct_hunt': dict(armor=0, pursuit='direct'),
    'direct_hunt_armor3': dict(armor=3, pursuit='direct'),
    'legacy_hunt': dict(armor=0, pursuit='legacy'),
    'legacy_hunt_armor3': dict(armor=3, pursuit='legacy'),
    'committed_hunt': dict(armor=0, pursuit='committed'),
    'committed_hunt_armor3': dict(armor=3, pursuit='committed'),
}
METRICS = (
    'bodies', 'hp_damage', 'structure_damage', 'friendly_damage', 'armor_damage',
    'hp_taken', 'armor_absorbed', 'blocked_damage', 'evaded_damage', 'attacks',
    'landed_hits', 'melee_hits', 'kills', 'regular_kills', 'monster_kills',
    'deaths', 'banished', 'goals', 'survivors', 'healing', 'regeneration',
    'charms', 'poisons', 'portals', 'enemy_banishments', 'friendly_banishments',
    'structures_built', 'tower_damage', 'retargets', 'first_hit_tick', 'hit_bodies',
)


def install_variant(name):
    """Apply explicit what-if tuning only to this experiment's worker process."""
    variant = VARIANTS[name]
    monster_effects.step = BASE_STEP
    monster_effects.steer = BASE_STEER
    if variant['armor']:
        # Sooge's conversion replaces Armor outright. Test the full proposal:
        # Extra starting Armor AND extra turret Armor, not a lost spawn buff.
        source = inspect.getsource(BASE_STEP)
        old = "a.update(sprite_form='turret',attack=3,armor=6,max_armor=6,step_fp=0)"
        if source.count(old) != 1:
            raise ValueError('Sooge conversion changed; review the experimental override')
        armor = 6+variant['armor']
        new = old.replace('armor=6,max_armor=6', f'armor={armor},max_armor={armor}')
        namespace = monster_effects.__dict__.copy()
        exec(compile(source.replace(old, new), '<unit-balance:armor3>', 'exec'), namespace)
        monster_effects.step = namespace['step']
    if variant['pursuit'] == 'direct':
        # Experimental comparison: keep pool avoidance, stop dodging bodies.
        monster_effects.steer = lambda unit, destination, rows, fields: BASE_STEER(unit, destination, [], fields)
    elif variant['pursuit'] == 'legacy':
        monster_effects.steer = legacy_steer
    elif variant['pursuit'] == 'committed':
        def committed(unit, destination, rows, fields):
            a = unit['attributes']
            if a.get('monster_id') != 'Tumler' or not destination: return destination
            pool = BASE_STEER(unit, destination, [], fields)
            if pool != destination: return pool
            if monster_effects.distance(a, destination) <= 360*360: return destination
            heading = legacy_steer(unit, destination, rows, [])
            return heading if monster_effects.distance(heading, destination) < monster_effects.distance(a, destination) else destination
        monster_effects.steer = committed
    return variant


def formation(spec):
    if 'teams' in spec: return spec['teams']
    name = spec['focus']
    if spec['mode'] == 'duel':
        return [name], [spec['opponent']]
    if spec['mode'] == 'squad':
        own = ['Butcher', 'Penitent', 'Vulture', 'Wright', name]
        enemies = {
            'balanced': ['Butcher', 'Penitent', 'Vulture', 'Wright', 'Butcher'],
            'ranged': ['Butcher', 'Penitent', 'Vulture', 'Vulture', 'Vulture'],
            'dense': ['Butcher', 'Penitent', 'Penitent', 'Vulture', 'Butcher'],
        }
        return own, enemies[spec['opponent']]
    if spec['mode'] == 'mixed':
        i = spec['sample']
        return (['Butcher', 'Penitent', 'Vulture', 'Wright', monsters.NAMES[i % 10], monsters.NAMES[(i + 3) % 10]],
                ['Butcher', 'Penitent', 'Vulture', 'Wright', monsters.NAMES[(i + 5) % 10], monsters.NAMES[(i + 8) % 10]])
    if spec['mode'] == 'hunt':
        if spec['opponent'] == 'open': return ['Tumler'], ['Vulture']
        if spec['opponent'] == 'screened': return ['Tumler'], ['Butcher', 'Penitent', 'Vulture']
        return ['Butcher', 'Penitent', 'Tumler'], ['Butcher', 'Penitent', 'Vulture', 'Vulture']
    raise ValueError(spec['mode'])


def initial(spec):
    variant = VARIANTS[spec['variant']]
    seed = f"unit-balance-20260918:{spec['mode']}:{spec['opponent']}:{spec['sample']}"
    world = dict(entities=Entities().snapshot(), data=dict(ranged_profile=marching.RANGED, kanifous_losses=[], kanifous_loss_round=1))
    monsters.configure(world)
    metadata = {}
    groups = formation(spec)
    for group, names in enumerate(groups):
        owner = spec['seat'] if group == 0 else 1 - spec['seat']
        for slot, name in enumerate(names):
            origin = f"unit-balance:{owner}:{slot}:{name}"
            size = 3 + draw(seed, origin, 'SWARM_COUNT', 0, 3) if name == 'Varn' else 1
            for ordinal in range(size):
                a = (monsters.profile(name, 'Lord', owner, 0, 1) if name in monsters.NAMES
                     else recruitment.profile(name, 'Lord', owner, 0, 1))
                if name in monsters.NAMES:
                    a['armor'] += variant['armor']; a['max_armor'] += variant['armor']
                row = recruitment.create(world, origin, ordinal, owner, a)
                recruitment.place_spawn(world, row, seed)
                if spec['mode'] in ('squad', 'mixed') and spec['opponent'] == 'dense':
                    a = row['attributes']; a['y_fp'] = 240 + draw(seed, row['id'], 'DENSE_Y', 0, 121)
                if spec['mode'] == 'hunt':
                    a = row['attributes']
                    x = 500 if group == 0 else (1000 if name == 'Vulture' else 880)
                    a['x_fp'] = x if spec['seat'] == 0 else 2400-x
                    a['y_fp'] = 300 + draw(seed, row['id'], 'HUNT_Y', 0, 61)-30
                    if name == 'Tumler': a['y_fp'] = 300
                metadata[row['id']] = dict(name=name, owner=owner, group=group, slot=slot, summon=origin,
                    focal=group == 0 and (spec['mode'] == 'duel' or name == spec['focus'] and slot == len(names)-1))
    return world, metadata, seed


def context(world, seed, number, hook='marching'):
    return dict(world=world, seed=seed, round=number, hook=hook, player_order=[0, 1], persistent_effects=[], full_roster=True)


def resolve_round(world, seed, number, capture_ticks=False):
    c = context(copy_data(world), seed, number, 'round_start_automatic')
    monster_effects.end_round(c['world'], number-1)
    c['world']['data'].update(kanifous_losses=[], kanifous_loss_round=number)
    regenerated = marching.regenerate(c)
    if regenerated['action'] != 'resolved': raise ValueError(regenerated)
    c.update(world=regenerated['world'], hook='marching')
    result = marching.resolve(c, capture_ticks=capture_ticks)
    if result['action'] != 'resolved': raise ValueError(result)
    return result, regenerated['events']


class Metrics:
    def __init__(self, world, metadata):
        self.meta = metadata
        self.units = {key: Counter(bodies=1) for key in metadata}
        self.hp = {r['id']: r['attributes']['hp'] for r in world['entities']['entities']}
        self.dead = set(); self.banished = set(); self.goals = set()
        self.goal_owners = Counter(); self.portal_sources = {}
        self.first_hit = {}; self.trace = []
        self.bases = {}

    def source_id(self, row):
        return row['attributes'].get('builder_id', '') if row.get('kind') == 'fortification' else row['id']

    def events(self, rows):
        for wrapped in rows:
            event = wrapped['event']; d = event['data']; kind = event['type']
            if kind in ('MARCHING_STARTED', 'MARCHING_FINISHED'):
                for unit in d['units']: self.hp[unit['id']] = unit['attributes']['hp']
                for unit in d.get('field_structures', []): self.hp[unit['id']] = unit['attributes']['hp']
                if kind == 'MARCHING_STARTED': self.bases = {u['id']: u['attributes'] for u in d['units']}
            elif kind == 'MARCHER_REGENERATED':
                if d['entity_id'] in self.units: self.units[d['entity_id']]['regeneration'] += d['after']-d['before']
                self.hp[d['entity_id']] = d['after']
            elif kind == 'MONSTER_PULSE':
                if d['unit_id'] in self.units: self.units[d['unit_id']]['healing'] += sum(r['amount'] for r in d['healed'])
                for row in d['healed']: self.hp[row['id']] = row['attributes']['hp']
            elif kind in ('MARCHER_MELEE_ATTACK', 'MARCHER_RANGED_ATTACK', 'MONSTER_ATTACK'):
                source, target = d['attacker'], d['target']
                sid, tid = self.source_id(source), target['id']
                if sid not in self.units: raise ValueError(('unknown attacker', sid))
                out = self.units[sid]; out['attacks'] += 1
                before = self.hp.get(tid, target['attributes']['hp'])
                if before <= 0: continue  # simultaneous overkill is not absorbed damage
                raw = source['attributes']['attack']
                ability = d.get('ability', '')
                if kind == 'MONSTER_ATTACK':
                    raw = {'Beam': 1 if source['owner'] == target['owner'] else 3,
                           'Poison': 1, 'Kopita': 1, 'Ambush': 5}.get(ability, raw)
                elif source['attributes'].get('blood_wish'): raw *= 2
                blocked, evaded = d.get('blocked', False), d.get('evaded', False)
                absorbed = 0 if blocked or evaded else raw-d['damage_dealt']-d.get('damage_reduced', 0)
                if absorbed < 0: raise ValueError(('negative absorption', event))
                lost = before-d['hp_after']
                if not 0 <= lost <= before: raise ValueError(('HP accounting mismatch', before, event))
                self.hp[tid] = d['hp_after']
                friendly = source['owner'] == target['owner']
                out['friendly_damage' if friendly else 'structure_damage' if target.get('kind') == 'fortification' else 'hp_damage'] += lost
                if not friendly: out['armor_damage'] += absorbed
                if not blocked and not evaded:
                    out['landed_hits'] += 1
                    if kind == 'MARCHER_MELEE_ATTACK': out['melee_hits'] += 1
                    self.first_hit.setdefault(sid, (d['round']-1)*200+d['tick']+1)
                if source.get('kind') == 'fortification' and not friendly: out['tower_damage'] += lost
                if tid in self.units:
                    self.units[tid]['hp_taken'] += lost
                    self.units[tid]['armor_absorbed'] += absorbed
                    self.units[tid]['blocked_damage'] += raw if blocked else 0
                    self.units[tid]['evaded_damage'] += raw if evaded else 0
            elif kind == 'MARCHER_DEFEATED':
                tid = d['victim']['id']; sid = self.source_id(d['attacker'])
                if tid in self.dead: continue
                self.dead.add(tid); self.hp[tid] = 0
                self.units[tid]['deaths'] += 1
                if d['attacker']['owner'] != d['victim']['owner']:
                    self.units[sid]['kills'] += 1
                    self.units[sid]['monster_kills' if d['victim']['attributes'].get('monster_id') else 'regular_kills'] += 1
            elif kind == 'MARCHER_WAITING':
                key = (d['entity_id'], 0 if d['x_fp'] == 2400 else 1)
                if key not in self.goals:
                    self.goals.add(key); self.units[key[0]]['goals'] += 1; self.goal_owners[key[1]] += 1
            elif kind in ('MONSTER_CHARMED', 'MONSTER_POISONED'):
                self.units[d['source_id']]['charms' if kind == 'MONSTER_CHARMED' else 'poisons'] += 1
            elif kind == 'MONSTER_FIELD_CREATED' and d['field']['kind'] == 'portal':
                field = d['field']
                matches = [key for key in self.meta if field['id'].startswith(key + ':')]
                if len(matches) != 1: raise ValueError(('portal credit', field))
                self.portal_sources[field['id']] = (matches[0], field['owner'])
                self.units[matches[0]]['portals'] += 1
            elif kind == 'MONSTER_BANISHED':
                tid = d['unit']['id']
                if tid in self.banished: continue
                self.banished.add(tid); self.units[tid]['banished'] += 1
                sid, owner = self.portal_sources[d['portal_id']]
                self.units[sid]['enemy_banishments' if d['unit']['owner'] != owner else 'friendly_banishments'] += 1
            elif kind == 'WRIGHT_STRUCTURE_BUILT':
                self.units[d['unit_id']]['structures_built'] += 1
                self.hp[d['structure']['id']] = d['structure']['attributes']['hp']
            elif kind == 'WRIGHT_STRUCTURE_REPAIRED':
                self.hp[d['structure']['id']] = d['hp_after']
            elif kind == 'MONSTER_HUNT_RETARGETED': self.units[d['unit_id']]['retargets'] += 1
            elif kind == 'MARCHING_TICK':
                for unit in d['units']:
                    if self.meta[unit['id']]['name'] != 'Tumler': continue
                    a = dict(self.bases.get(unit['id'], {}), **unit['attributes'])
                    self.trace.append(dict(round=d['round'], tick=d['tick'], id=unit['id'], owner=unit['owner'],
                        x=a['x_fp'], y=a['y_fp'], hp=a['hp'], target=a.get('hunt_target', '')))

    def finish(self, world):
        for unit in world['entities']['entities']:
            self.units[unit['id']]['survivors'] = 1
        for key, tick in self.first_hit.items():
            self.units[key]['first_hit_tick'] = tick
            self.units[key]['hit_bodies'] = 1
        return [dict(self.meta[key], id=key, **{m: int(stats[m]) for m in METRICS}) for key, stats in self.units.items()]


def run_case(spec, export=None, trace=False):
    install_variant(spec['variant'])
    world, meta, seed = initial(spec)
    metrics = Metrics(world, meta)
    for number in range(1, spec.get('rounds', 10)+1):
        before = copy_data(world) if export is not None else None
        result, regeneration = resolve_round(world, seed, number, capture_ticks=trace)
        if export is not None:
            export.append(dict(spec=spec, world=before, seed=seed, round=number,
                result=copy_data(dict(result, events=[r for r in result['events'] if r['event']['type'] != 'MARCHING_TICK']))))
        metrics.events(regeneration); metrics.events(result['events'])
        world = result['world']
        world['entities']['entities'] = [r for r in world['entities']['entities'] if not r['attributes']['waiting']]
        world['data']['kanifous_losses'] = []; world['data']['monsters']['death_ids'] = []
        if not world['entities']['entities']: break
    return dict(spec=spec, seed=seed, rounds=number, units=metrics.finish(world),
                team_goals=[metrics.goal_owners[0], metrics.goal_owners[1]], trace=metrics.trace)


def cases(samples, variants, modes, rounds):
    result = []
    for mode in modes:
        names = ['Tumler'] if mode == 'hunt' else ['mixed'] if mode == 'mixed' else NAMES
        opponents = recruitment.SUITS if mode == 'duel' else ['open', 'screened', 'cluster'] if mode == 'hunt' else ['balanced', 'ranged', 'dense'] if mode == 'squad' else ['balanced']
        repeats = max(20, samples*2) if mode == 'mixed' else samples
        for name in names:
            for opponent in opponents:
                for sample in range(repeats):
                    for seat in [0, 1]:
                        for variant in variants:
                            # These basic-only fixtures have no monster to tune;
                            # retain one control even when the baseline is legacy.
                            if mode in ('duel', 'squad') and name in recruitment.SUITS and variant != variants[0]: continue
                            result.append(dict(mode=mode, focus=name, opponent=opponent, sample=sample, seat=seat, variant=variant, rounds=rounds))
    return result


def aggregate(rows):
    groups = defaultdict(list)
    for row in rows:
        s = row['spec']
        if s['mode'] == 'mixed':
            for name in NAMES:
                found = [u for u in row['units'] if u['name'] == name]
                if found: groups[(s['mode'], s['variant'], name)].append(found)
        else:
            groups[(s['mode'], s['variant'], s['focus'])].append([u for u in row['units'] if u['focal']])
    output = []
    for key, samples in sorted(groups.items()):
        totals = Counter()
        summons = set()
        for i, sample in enumerate(samples):
            for unit in sample:
                totals.update({m: unit[m] for m in METRICS})
                summons.add((i, unit['summon']))
        count, bodies = len(summons), totals['bodies']
        output.append(dict(mode=key[0], variant=key[1], unit=key[2], battles=len(samples), summons=count,
            totals=dict(totals), per_summon={m: round(totals[m]/count, 4) for m in METRICS},
            per_body={m: round(totals[m]/bodies, 4) for m in METRICS},
            mean_first_hit_tick=round(totals['first_hit_tick']/totals['hit_bodies'], 2) if totals['hit_bodies'] else None))
    return output


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--samples', type=int, default=12)
    p.add_argument('--workers', type=int, default=6)
    p.add_argument('--rounds', type=int, default=10)
    p.add_argument('--modes', nargs='+', choices=['duel', 'squad', 'mixed', 'hunt'], default=['duel', 'squad', 'mixed'])
    p.add_argument('--variants', nargs='+', choices=list(VARIANTS), default=['current', 'armor3'])
    p.add_argument('--focus', nargs='+', choices=list(NAMES), help='Restrict duel/squad cases to these units')
    p.add_argument('--pilot', action='store_true')
    args = p.parse_args()
    if not 1 <= args.samples <= 1000 or not 1 <= args.workers <= 8 or not 1 <= args.rounds <= 30: p.error('bounds: samples 1-1000, workers 1-8, rounds 1-30')
    tasks = cases(args.samples, args.variants, args.modes, args.rounds)
    if args.focus: tasks = [s for s in tasks if s['mode'] == 'mixed' or s['focus'] in args.focus]
    if args.pilot: tasks = tasks[::max(1, len(tasks)//24)]
    args.output.mkdir(parents=True, exist_ok=True)
    start = time.monotonic(); rows = []
    manifest = dict(schema='U13_UNIT_BALANCE_V1', samples=args.samples, rounds=args.rounds, tasks=len(tasks),
        variants=args.variants, modes=args.modes, workers=args.workers, python=platform.python_version(),
        focus=args.focus,
        revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        source_sha256={f.name: hashlib.sha256(f.read_bytes()).hexdigest()
                       for f in sorted(Path(__file__).parent.glob('*.py'))},
        rules=dict(marching=marching.RANGED, monsters=monsters.VERSION))
    (args.output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    with (args.output/'battles.jsonl').open('w') as log:
        with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as pool:
            futures = [pool.submit(run_case, spec) for spec in tasks]
            for future in concurrent.futures.as_completed(futures):
                row = future.result(); row.pop('trace'); rows.append(row)
                log.write(json.dumps(row, separators=(',', ':'))+'\n'); log.flush()
                if len(rows) % 50 == 0 or len(rows) == len(tasks):
                    print(f'{len(rows)}/{len(tasks)} battles in {time.monotonic()-start:.1f}s', flush=True)
    summary = dict(manifest, elapsed_seconds=round(time.monotonic()-start, 3), results=aggregate(rows))
    (args.output/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print('Completed', args.output, flush=True)


if __name__ == '__main__': main()
