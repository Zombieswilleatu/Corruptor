"""Monster-versus-one/two benchmarks and isolated Tumler/counter experiments.

Never changes production rules. Fights stop after the first phase in which
one original force is eliminated, or after ten phases. Varn is one summon.
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

from . import unit_balance as audit, monster_effects as fx, field_combat, penitent_defense, support_pacing
from .copying import copy_data
from .primitives import draw
from . import damage_reduction_experiment

BASE_EVADE = fx.evades
BASE_VOLLEY = field_combat.volley
BASE_BLOCK = penitent_defense.CHANCE
BASE_PACING = support_pacing.speed
BASE_DAMAGE = fx.damage
BASE_MELEE = field_combat.melee
TUNING = {
    'current': {},
    'armor3': {'armor': 3},
    'hp2': {'hp_multiplier': 2},
    'armor2x': {'armor_multiplier': 2, 'root_armor': 12},
    'always50': {'always': True},
    'always50_armor3': {'always': True, 'armor': 3},
    'always50_attack3': {'always': True, 'tumler_attack': 3},
    'always50_attack3_armor3': {'always': True, 'tumler_attack': 3, 'armor': 3},
    'always50_hp2': {'always': True, 'hp_multiplier': 2},
    'always50_attack3_hp2': {'always': True, 'tumler_attack': 3, 'hp_multiplier': 2},
    'penitent0': {'block': 0},
    'penitent75': {'block': 75},
    'vulture40': {'vulture_interval': 40},
    'penitent_lead90': {'penitent_lead': 90},
    'penitent_lead180': {'penitent_lead': 180},
    'penitent_lead90_block0': {'penitent_lead': 90, 'block': 0},
    'lem_attack4_armor3': {'armor': 3, 'lemek_attack': 4},
    'lem_attack4_armor5': {'armor': 5, 'lemek_attack': 4},
    'lem_attack3_armor6': {'armor': 6},
    'lem_attack4_hp2': {'hp_multiplier': 2, 'lemek_attack': 4},
    'kurchin20': {'kurchin_hp': 20},
    'kurchin30': {'kurchin_hp': 30},
    'kurchin40': {'kurchin_hp': 40},
    'kurchin10_mitigation1': {'kurchin_hp': 10, 'mitigation': 1},
}
for key, tuning in TUNING.items():
    audit.VARIANTS[key] = dict(armor=tuning.get('armor', 0), pursuit='current')


def always_evades(unit, source, rows, context, tick, kind, structures=(), fleeing=()):
    # Permanent protection from direct attacks, including melee contact, hold,
    # retreat and fear. Ongoing poison remains damage, not a dodgeable attack.
    if unit['attributes'].get('monster_id') != 'Tumler' or kind == 'Poison': return False
    key = f"{context['round']}:{tick}:{kind}:{source['id']}:{unit['id']}"
    return draw(context['seed'], key, 'TUMLER_HUNT_EVASION', 0, 100) < 50


def penitent_pacing(unit, rows, step, clock, number, fleeing, trail):
    a = unit['attributes']
    if a.get('monster_id') or a.get('suit') not in ('Butcher', 'Wright'):
        return BASE_PACING(unit, rows, step, clock, number, fleeing)
    # Building and guarding remain independent of the advance formation.
    if a.get('suit') == 'Wright' and (not a.get('wright_built', False) or clock < a.get('wright_guard_until', 0)):
        return step
    screen, lead = None, -421
    for other in rows:
        b = other['attributes']
        if other['owner'] != unit['owner'] or b['lane'] != a['lane'] or b.get('suit') != 'Penitent' or b.get('monster_id'):
            continue
        if b['waiting'] or b['movement_ready_round'] > number or b.get('hidden', False) or b.get('rout_round', -1) == number or other['id'] in fleeing:
            continue
        dx, dy = b['x_fp']-a['x_fp'], b['y_fp']-a['y_fp']
        if abs(dy) > 180 or dx*dx+dy*dy > 420*420: continue
        forward = dx*a['direction']
        if forward > lead: screen, lead = other, forward
    # Once the leader engages, followers close normally to contribute damage.
    if screen is None or screen['attributes']['contact_tick'] >= 0: return step
    if lead >= trail: return min(step, lead-trail)
    return (step >> 2)+int((clock & 3) < (step & 3))


def install(name):
    tuning = TUNING[name]
    fx.evades = always_evades if tuning.get('always') else BASE_EVADE
    fx.damage = BASE_DAMAGE
    if tuning.get('always'):
        source = inspect.getsource(BASE_DAMAGE)
        old = 'evaded=not fleeing and evades('
        assert source.count(old) == 1, 'Review permanent evasion for monster abilities during fear'
        namespace = fx.__dict__.copy()
        exec(compile(source.replace(old, 'evaded=evades('), '<pair-audit:permanent-evasion>', 'exec'), namespace)
        fx.damage = namespace['damage']
    penitent_defense.CHANCE = tuning.get('block', BASE_BLOCK)
    field_combat.melee = BASE_MELEE
    field_combat.volley = BASE_VOLLEY
    support_pacing.speed = BASE_PACING
    if tuning.get('penitent_lead'):
        support_pacing.speed = lambda unit, rows, step, clock, number, fleeing=(): penitent_pacing(unit, rows, step, clock, number, fleeing, tuning['penitent_lead'])
    if tuning.get('vulture_interval'):
        source = inspect.getsource(BASE_VOLLEY)
        old = "aa.update(ranged_next_tick=clock+32, melee_next_tick=clock+8)"
        assert source.count(old) == 1, 'Review Vulture-only interval override'
        source = source.replace(old, old.replace('clock+32', f"clock+{tuning['vulture_interval']}"))
        namespace = field_combat.__dict__.copy()
        exec(compile(source, '<pair-audit:vulture-interval>', 'exec'), namespace)
        field_combat.volley = namespace['volley']
    if tuning.get('mitigation'):
        damage_reduction_experiment.install(tuning['mitigation'])
    # Armor experiments copy step's globals. Install hit handling first so that
    # the copied function cannot inherit the previous case's ability override.
    audit.install_variant(name)
    if 'root_armor' in tuning:
        source = inspect.getsource(audit.BASE_STEP)
        old = "a.update(sprite_form='turret',attack=3,armor=6,max_armor=6,step_fp=0)"
        assert source.count(old) == 1, 'Review doubled turret Armor override'
        value = tuning['root_armor']
        namespace = fx.__dict__.copy()
        exec(compile(source.replace(old, old.replace('armor=6,max_armor=6', f'armor={value},max_armor={value}')), '<pair-audit:double-armor>', 'exec'), namespace)
        fx.step = namespace['step']


class DetailedMetrics(audit.Metrics):
    def __init__(self, world, metadata):
        super().__init__(world, metadata)
        self.ranged = Counter()
        self.first_melee = {}
        self.first_incoming = {}
        self.last_incoming = {}
        self.death_ticks = {}
        self.prevented = Counter()

    def events(self, events):
        for wrapped in events:
            e = wrapped['event']; d = e['data']
            if e['type'] == 'MARCHER_RANGED_ATTACK' and d['attacker']['attributes'].get('suit') == 'Vulture':
                name = d['target']['attributes'].get('monster_id', d['target']['attributes'].get('suit', 'structure'))
                self.ranged[f'shots_at_{name}'] += 1
                if d.get('blocked'): self.ranged[f'blocked_at_{name}'] += 1
                target_meta = self.meta.get(d['target']['id'])
                if target_meta:
                    self.ranged[f"group{target_meta['group']}_shots_at_{name}"] += 1
                    if d.get('blocked'): self.ranged[f"group{target_meta['group']}_blocked_at_{name}"] += 1
            if e['type'] == 'MARCHER_MELEE_ATTACK':
                self.first_melee.setdefault(d['attacker']['id'], (d['round']-1)*200+d['tick'])
            if e['type'] in ('MARCHER_MELEE_ATTACK', 'MARCHER_RANGED_ATTACK', 'MONSTER_ATTACK'):
                self.prevented[d['target']['id']] += d.get('damage_reduced', 0)
                if d['attacker']['owner'] != d['target']['owner'] and not d.get('blocked') and not d.get('evaded'):
                    tick = (d['round']-1)*200+d['tick']
                    self.first_incoming.setdefault(d['target']['id'], tick)
                    self.last_incoming[d['target']['id']] = tick
            if e['type'] == 'MARCHER_DEFEATED':
                self.death_ticks.setdefault(d['victim']['id'], (d['round']-1)*200+d['tick'])
        super().events(events)


def initial(spec):
    world, meta, seed = audit.initial(spec)
    tuning = TUNING[spec['variant']]
    for row in world['entities']['entities']:
        name = meta[row['id']]['name']
        if name in audit.monsters.NAMES:
            for field in ('hp', 'max_hp'): row['attributes'][field] *= tuning.get('hp_multiplier', 1)
            for field in ('armor', 'max_armor'): row['attributes'][field] *= tuning.get('armor_multiplier', 1)
        if name == 'Tumler' and 'tumler_attack' in tuning: row['attributes']['attack'] = tuning['tumler_attack']
        if name == 'Lemek' and 'lemek_attack' in tuning: row['attributes']['attack'] = tuning['lemek_attack']
        if name == 'Kurchin' and 'kurchin_hp' in tuning:
            row['attributes'].update(hp=tuning['kurchin_hp'], max_hp=tuning['kurchin_hp'])
    if spec.get('layout') == 'tight':
        for group in (0, 1):
            rows = [r for r in world['entities']['entities'] if meta[r['id']]['group'] == group]
            shift = draw(seed, str(group), 'TIGHT_Y', 0, 31)-15
            for i, row in enumerate(rows):
                x = (900 if group == 0 else 1500)
                row['attributes']['x_fp'] = x if spec['seat'] == 0 else 2400-x
                row['attributes']['y_fp'] = 300 + shift + 90*i-45*(len(rows)-1)
    if spec.get('layout') == 'contact':
        for group in (0, 1):
            rows = [r for r in world['entities']['entities'] if meta[r['id']]['group'] == group]
            for i, row in enumerate(rows):
                x = 1200 if group == 0 else 1260
                row['attributes']['x_fp'] = x if spec['seat'] == 0 else 2400-x
                row['attributes']['y_fp'] = 300 + 30*i-15*(len(rows)-1)
    return world, meta, seed


def run(spec, export=None):
    install(spec['variant'])
    world, meta, seed = initial(spec)
    stats = DetailedMetrics(world, meta)
    escaped = {}; converted = set(); outcome = 'unresolved'
    groups = [{key for key, m in meta.items() if m['group'] == g} for g in (0, 1)]
    for number in range(1, 11):
        before = copy_data(world) if export is not None else None
        result, regen = audit.resolve_round(world, seed, number)
        if export is not None:
            export.append(dict(spec=spec, world=before, seed=seed, round=number, result=copy_data(result)))
        stats.events(regen); stats.events(result['events'])
        world = result['world']
        for row in world['entities']['entities']:
            if row['attributes']['waiting']:
                escaped[row['id']] = copy_data(row)
                if row['owner'] != meta[row['id']]['owner']: converted.add(row['id'])
        lost = stats.dead | stats.banished | converted
        left = [ids-lost for ids in groups]
        living = {r['id']: r for r in world['entities']['entities']}
        living.update(escaped)
        remaining = [[living[key] for key in ids if key in living] for ids in left]
        if not left[0] or not left[1]:
            outcome = 'win' if left[0] else 'loss' if left[1] else 'mutual'
            break
        world['entities']['entities'] = [r for r in world['entities']['entities'] if not r['attributes']['waiting']]
        world['data']['kanifous_losses'] = []; world['data']['monsters']['death_ids'] = []
        if not world['entities']['entities']: break
    hp = [sum(r['attributes']['hp'] for r in rows) for rows in remaining]
    armor = [sum(r['attributes']['armor'] for r in rows) for rows in remaining]
    enemy_left = hp[1]+armor[1]
    near = outcome == 'loss' and len(left[1]) == 1 and enemy_left <= 2
    # As with ordinary audit records, survivors here mean active field bodies;
    # goal arrivals and the fight outcome are separate metrics.
    world['entities']['entities'] = [r for r in world['entities']['entities'] if not r['attributes']['waiting']]
    record = dict(spec=spec, seed=seed, rounds=number, outcome=outcome, near_even=near,
                remaining_hp=hp, remaining_armor=armor, remaining_bodies=[len(x) for x in left],
                units=stats.finish(world), team_goals=[stats.goal_owners[i] for i in (0, 1)],
                converted_goal_bodies=len(converted), ranged=dict(stats.ranged), first_melee=stats.first_melee)
    if spec['mode'] in ('tank', 'escort'):
        key = next(key for key, m in meta.items() if m['group'] == 0 and m['name'] == 'Kurchin')
        first, death = stats.first_incoming.get(key), stats.death_ticks.get(key)
        allies = [u for u in record['units'] if u['group'] == 0 and u['name'] != 'Kurchin']
        record['tank'] = dict(first_incoming_tick=first, death_tick=death,
            ticks_to_death=None if first is None or death is None else death-first,
            last_incoming_tick=stats.last_incoming.get(key), alive=key not in lost,
            ally_deaths=sum(u['deaths'] for u in allies), ally_kills=sum(u['kills'] for u in allies),
            ally_hp_taken=sum(u['hp_taken'] for u in allies), ally_hp_damage=sum(u['hp_damage'] for u in allies))
        if TUNING[spec['variant']].get('mitigation'):
            record['tank']['damage_prevented'] = stats.prevented[key]
    return record


def tasks(suite, samples, layouts, selected_variants=None):
    result = []
    def add(mode, focus, label, teams, variants, layout='spawn'):
        for sample in range(samples):
            for seat in (0, 1):
                for variant in selected_variants or variants:
                    result.append(dict(mode=mode, focus=focus, opponent=label, sample=sample, seat=seat,
                                       variant=variant, teams=teams, layout=layout))
    if suite == 'monsters':
        for name in audit.monsters.NAMES:
            for opponent in audit.recruitment.SUITS:
                for count in (1, 2):
                    for layout in layouts:
                        add('benchmark', name, f'{count}x{opponent}:{layout}', [[name], [opponent]*count], ['current', 'armor3'], layout)
    elif suite == 'tumler':
        for opponent in audit.recruitment.SUITS:
            for count in (1, 2):
                for layout in layouts:
                    add('benchmark', 'Tumler', f'{count}x{opponent}:{layout}', [['Tumler'], [opponent]*count],
                        ['current', 'always50', 'armor3', 'always50_armor3'], layout)
        for label in ('balanced', 'ranged', 'dense'):
            old = dict(mode='squad', focus='Tumler', opponent=label)
            add('squad', 'Tumler', label, audit.formation(old), ['current', 'always50', 'armor3', 'always50_armor3'])
        for label in ('open', 'screened', 'cluster'):
            old = dict(mode='hunt', focus='Tumler', opponent=label)
            add('hunt', 'Tumler', label, audit.formation(old), ['current', 'always50', 'armor3', 'always50_armor3'])
    elif suite == 'vultures':
        variants = ['current', 'penitent0', 'penitent75', 'vulture40', 'penitent_lead90', 'penitent_lead180', 'penitent_lead90_block0']
        for opponent in ('Butcher', 'Penitent', 'Wright'):
            for count in (1, 2, 4):
                add('counter', 'Vulture', f'{count}v{count}:{opponent}', [['Vulture']*count, [opponent]*count], variants[:4])
        shooters = ['Butcher', 'Penitent', 'Vulture', 'Vulture', 'Vulture']
        for label, defenders in {
            'balanced': ['Butcher', 'Penitent', 'Vulture', 'Wright', 'Butcher'],
            'penitent_heavy': ['Penitent', 'Penitent', 'Penitent', 'Vulture', 'Wright'],
            'penitent_butcher': ['Penitent', 'Penitent', 'Butcher', 'Butcher', 'Vulture'],
        }.items(): add('counter', 'Vulture', label, [shooters, defenders], variants)
        for label, defenders in {
            'pure_vs_balanced': ['Butcher', 'Penitent', 'Vulture', 'Wright', 'Butcher'],
            'pure_vs_melee': ['Penitent', 'Penitent', 'Butcher', 'Butcher', 'Butcher'],
            'pure_vs_wrights': ['Penitent', 'Penitent', 'Wright', 'Wright', 'Butcher'],
        }.items(): add('counter', 'Vulture', label, [['Vulture']*5, defenders], variants)
        for label, army in {
            'balanced_vs_butchers': ['Butcher', 'Penitent', 'Vulture', 'Wright', 'Butcher'],
            'melee_vs_butchers': ['Penitent', 'Penitent', 'Butcher', 'Butcher', 'Butcher'],
            'wrights_vs_butchers': ['Penitent', 'Penitent', 'Wright', 'Wright', 'Butcher'],
        }.items(): add('formation', 'Butcher', label, [army, ['Butcher']*5], ['current', 'penitent_lead90', 'penitent_lead180'])
    elif suite == 'lemek':
        for count in (1, 2):
            for layout in layouts:
                add('benchmark', 'Lemek', f'{count}xButcher:{layout}', [['Lemek'], ['Butcher']*count],
                    ['current', 'armor3', 'lem_attack4_armor3', 'lem_attack4_armor5', 'lem_attack3_armor6'], layout)
    elif suite == 'kurchin':
        variants = ['current', 'armor3', 'hp2', 'kurchin20', 'kurchin30', 'kurchin40', 'kurchin10_mitigation1']
        for label, opponents in [('three_butchers', ['Butcher']*3), ('mixed_three', ['Butcher', 'Penitent', 'Vulture']), ('three_vultures', ['Vulture']*3)]:
            for layout in ('spawn', 'contact'):
                add('tank', 'Kurchin', f'{label}:{layout}', [['Kurchin'], opponents], variants, layout)
        for label, allies in [('vulture_escort', ['Vulture', 'Vulture', 'Kurchin']), ('butcher_escort', ['Butcher', 'Butcher', 'Kurchin'])]:
            add('escort', 'Kurchin', label, [allies, ['Butcher']*3], variants)
    return result


def summarize(rows):
    groups = defaultdict(list)
    for r in rows:
        s = r['spec']; groups[(s['mode'], s['focus'], s['opponent'], s['layout'], s['variant'])].append(r)
    result = []
    for key, group in sorted(groups.items()):
        count = len(group); outcomes = Counter(r['outcome'] for r in group)
        units = [u for r in group for u in r['units'] if u['focal']]
        counters = Counter()
        for r in group: counters.update(r['ranged'])
        result.append(dict(mode=key[0], unit=key[1], opponent=key[2], layout=key[3], variant=key[4], trials=count,
            outcomes=dict(outcomes), near_even=sum(r['near_even'] for r in group),
            win_rate=outcomes['win']/count, nonloss_rate=(outcomes['win']+outcomes['mutual'])/count,
            mean_hp_damage=sum(u['hp_damage'] for u in units)/count, mean_kills=sum(u['kills'] for u in units)/count,
            mean_evaded_damage=sum(u['evaded_damage'] for u in units)/count,
            mean_own_hp=sum(r['remaining_hp'][0] for r in group)/count,
            mean_enemy_hp=sum(r['remaining_hp'][1] for r in group)/count,
            mean_enemy_armor=sum(r['remaining_armor'][1] for r in group)/count,
            ranged=dict(counters)))
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--suite', choices=['monsters', 'tumler', 'vultures', 'lemek', 'kurchin'], required=True)
    p.add_argument('--samples', type=int, default=32)
    p.add_argument('--workers', type=int, default=6)
    p.add_argument('--layouts', nargs='+', choices=['spawn', 'tight'], default=['spawn'])
    p.add_argument('--variants', nargs='+', choices=list(TUNING))
    p.add_argument('--pilot', action='store_true')
    args = p.parse_args()
    if not 1 <= args.samples <= 1000 or not 1 <= args.workers <= 8: p.error('samples 1-1000, workers 1-8')
    specs = tasks(args.suite, args.samples, args.layouts, args.variants)
    if args.pilot: specs = specs[::max(1, len(specs)//24)]
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = dict(schema='U13_MONSTER_PAIR_BALANCE_V1', suite=args.suite, samples=args.samples, layouts=args.layouts,
                    variants=args.variants, tasks=len(specs), python=platform.python_version(),
                    revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                    source_sha256={f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(Path(__file__).parent.glob('*.py'))})
    (args.output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    start = time.monotonic(); rows = []
    with (args.output/'battles.jsonl').open('w') as out, concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as pool:
        pending = [pool.submit(run, s) for s in specs]
        for future in concurrent.futures.as_completed(pending):
            r = future.result(); rows.append(r)
            out.write(json.dumps(r, separators=(',', ':'))+'\n'); out.flush()
            if len(rows) % 100 == 0 or len(rows) == len(specs): print(f'{len(rows)}/{len(specs)} in {time.monotonic()-start:.1f}s', flush=True)
    (args.output/'summary.json').write_text(json.dumps(dict(manifest, elapsed_seconds=time.monotonic()-start, results=summarize(rows)), indent=2)+'\n')


if __name__ == '__main__': main()
