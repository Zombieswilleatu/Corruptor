"""Native replay of isolated pair-balance experiments; never patches the game."""
import argparse
import json
from pathlib import Path

from . import codec, monster_pair_balance as pairs
from .copying import copy_data
from .primitives import draw
from .unit_balance_variants import native_project as base_project
from .verify_unit_balance import compare

PACING_GD = '''
static func speed(unit: Dictionary, rows: Array, step: int, clock: int, number: int, fleeing: Dictionary = {}) -> int:
	var a: Dictionary = unit.attributes
	if a.get("monster_id") or a.get("suit") not in ["Butcher", "Wright"]:
		return support_speed(unit, rows, step, clock, number, fleeing)
	if a.get("suit") == "Wright" and (not a.get("wright_built", false) or clock < a.get("wright_guard_until", 0)):
		return step
	var screen: Dictionary = {}
	var lead: int = -421
	for other in rows:
		var b: Dictionary = other.attributes
		if other.owner != unit.owner or b.lane != a.lane or b.get("suit") != "Penitent" or b.get("monster_id"): continue
		if b.waiting or b.movement_ready_round > number or b.get("hidden", false) or b.get("rout_round", -1) == number or fleeing.has(other.id): continue
		var dx: int = int(b.x_fp)-int(a.x_fp)
		var dy: int = int(b.y_fp)-int(a.y_fp)
		if absi(dy) > 180 or dx*dx+dy*dy > 420*420: continue
		var forward: int = dx*int(a.direction)
		if forward > lead:
			screen = other
			lead = forward
	if screen.is_empty() or screen.attributes.contact_tick >= 0: return step
	if lead >= FOLLOW_DISTANCE: return mini(step, lead-FOLLOW_DISTANCE)
	return (step >> 2)+(1 if (clock & 3) < (step & 3) else 0)
'''


def native_project(destination, variant):
    base_project(destination, variant)
    sim = Path(destination)/'Scripts/Sim'
    tuning = pairs.TUNING[variant]

    def change(name, old, new):
        file = sim/name
        text = file.read_text()
        if text.count(old) != 1: raise ValueError(('Review native experimental override', name, old))
        if file.is_symlink(): file.unlink()
        file.write_text(text.replace(old, new))

    if tuning.get('always'):
        change('U13MonsterEffects.gd',
               'if kind == "Poison" or fleeing.has(unit.id) or not hunting(unit, rows, context.round, structures): return false',
               'if kind == "Poison" or unit.attributes.get("monster_id") != "Tumler": return false')
        change('U13MonsterEffects.gd', 'var evaded: bool = not fleeing and evades(', 'var evaded: bool = evades(')
    if 'root_armor' in tuning:
        value = tuning['root_armor']
        change('U13MonsterEffects.gd', '"sprite_form": "turret", "attack": 3, "armor": 6, "max_armor": 6, "step_fp": 0',
               f'"sprite_form": "turret", "attack": 3, "armor": {value}, "max_armor": {value}, "step_fp": 0')
    if 'block' in tuning:
        change('U13PenitentDefense.gd', 'const CHANCE: int = 50', f"const CHANCE: int = {tuning['block']}")
    if 'vulture_interval' in tuning:
        change('U13RangedMarching.gd', 'attacker.attributes["ranged_next_tick"] = clock + RANGED_INTERVAL_TICKS',
               f"attacker.attributes[\"ranged_next_tick\"] = clock + {tuning['vulture_interval']}")
    if 'penitent_lead' in tuning:
        change('U13SupportPacing.gd', 'static func speed(', 'static func support_speed(')
        file = sim/'U13SupportPacing.gd'
        file.write_text(file.read_text()+PACING_GD.replace('FOLLOW_DISTANCE', str(tuning['penitent_lead'])))
    if tuning.get('mitigation'):
        pairs.damage_reduction_experiment.native(change, tuning['mitigation'])
    return str(destination)


def export(directory, variant):
    directory.mkdir(parents=True, exist_ok=False)
    # Both seats; ordinary duels, clustered target pursuit, fortifications,
    # ranged blocks, and Sooge's Armor-replacing transformation.
    cases = [
        ('benchmark', 'Tumler', 'two_butchers', [['Tumler'], ['Butcher', 'Butcher']]),
        ('benchmark', 'Lemek', 'two_butchers', [['Lemek'], ['Butcher', 'Butcher']]),
        ('benchmark', 'Sooge', 'two_vultures', [['Sooge'], ['Vulture', 'Vulture']]),
        ('counter', 'Vulture', 'penitent_melee', [['Vulture']*5, ['Penitent', 'Penitent', 'Butcher', 'Butcher', 'Butcher']]),
        ('counter', 'Vulture', 'penitent_wrights', [['Vulture']*5, ['Penitent', 'Penitent', 'Wright', 'Wright', 'Butcher']]),
        ('hunt', 'Tumler', 'cluster', [['Butcher', 'Penitent', 'Tumler'], ['Butcher', 'Penitent', 'Vulture', 'Vulture']]),
    ]
    records = []
    for i, (mode, name, label, teams) in enumerate(cases):
        spec = dict(mode=mode, focus=name, opponent=label, teams=teams, variant=variant, sample=i, seat=i % 2, layout='spawn')
        pairs.run(spec, export=records)
    # Guaranteed root checks Armor replacement; an ability during portal fear
    # checks the separate ability damage path used by permanent evasion.
    for special in ('root', 'fear'):
        teams = [['Sooge'], ['Wright', 'Wright']] if special == 'root' else [['Tumler'], ['Muno']]
        spec = dict(mode='benchmark', focus=teams[0][0], opponent=special, teams=teams,
                    variant=variant, sample=0, seat=0, layout='spawn')
        pairs.install(variant)
        world, meta, seed = pairs.initial(spec)
        own = next(r for r in world['entities']['entities'] if meta[r['id']]['group'] == 0)
        if special == 'root': own['attributes']['sooge_root_attempts'] = 5
        else:
            enemy = next(r for r in world['entities']['entities'] if meta[r['id']]['group'] == 1)
            own['attributes'].update(x_fp=1000, y_fp=300, hp=100, max_hp=100, armor=0)
            enemy['attributes'].update(x_fp=1120, y_fp=300, hp=100, max_hp=100, armor=0)
            world['data']['monsters']['fields'] = [dict(kind='portal', id='pair-fear-portal', owner=1, lane=own['attributes']['lane'], x_fp=800, y_fp=300, expires_round=2)]
            key = f"1:0:Muno:{enemy['id']}:{own['id']}"
            seed = next(f'pair-fear:{i}' for i in range(10000) if draw(f'pair-fear:{i}', key, 'TUMLER_HUNT_EVASION', 0, 100) == 49)
            own['attributes'].update(poison_until_round=1, poison_source=copy_data(enemy))
        before = copy_data(world)
        result, _ = pairs.audit.resolve_round(world, seed, 1)
        facts = [r['event'] for r in result['events']]
        if special == 'root': assert any(e['type'] == 'MONSTER_ROOTED' for e in facts)
        elif pairs.TUNING[variant].get('always'):
            hits = [e['data'] for e in facts if e['type'] == 'MONSTER_ATTACK']
            assert any(h['ability'] == 'Muno' and h.get('evaded') for h in hits), 'Fear ability fixture must actually dodge'
            assert any(h['ability'] == 'Poison' and not h.get('evaded') for h in hits), 'Poison must remain undodgeable'
        records.append(dict(world=before, seed=seed, round=1, result=result))
    with (directory/'inputs.jsonl').open('w') as inputs, (directory/'expected.jsonl').open('w') as expected:
        for row in records:
            inputs.write(json.dumps({key: row[key] for key in ('world', 'seed', 'round')})+'\n')
            expected.write(codec.dumps(row['result'])+'\n')
    print(json.dumps(dict(variant=variant, battles=len(cases), phases=len(records))))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['project', 'export', 'compare'])
    p.add_argument('directory', type=Path)
    p.add_argument('variant', nargs='?', choices=list(pairs.TUNING))
    args = p.parse_args()
    if args.action == 'compare': compare(args.directory)
    elif args.action == 'project': print(native_project(args.directory, args.variant))
    else: export(args.directory, args.variant)


if __name__ == '__main__': main()
