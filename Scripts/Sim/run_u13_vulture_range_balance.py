#!/usr/bin/env python3
"""Paired isolated lane battles using the production Marching kernel.

Range overrides exist only in this process. Identical seeds, immutable unit IDs,
and spawns are reused for each range setting and reflected owner assignment.
No Lords, card costs, reinforcement waves, or full-game win claims are included.
"""
import argparse
from collections import Counter, defaultdict
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import time

from u13_pysim import codec, field_fortifications as fort, marching as m
from u13_pysim import marching_spatial as spatial, monsters, recruitment as recruit
from u13_pysim.copying import copy_data
from u13_pysim.primitives import Entities, instance_id


@contextmanager
def ranges(vulture, tower):
    before = spatial.VULTURE_RANGE, spatial.RANGE2, m.RANGE2, fort.TOWER_RANGE
    spatial.VULTURE_RANGE, spatial.RANGE2, m.RANGE2, fort.TOWER_RANGE = vulture, vulture**2, vulture**2, tower
    try:
        yield
    finally:
        spatial.VULTURE_RANGE, spatial.RANGE2, m.RANGE2, fort.TOWER_RANGE = before


def scenarios():
    cases = []
    for size in (1, 4):
        for a, b in (("Vulture", "Butcher"), ("Penitent", "Vulture"), ("Butcher", "Penitent")):
            cases.append(dict(name=f"{a}_vs_{b}_{size}v{size}", group="counters", teams=[[a]*size, [b]*size]))
    cases.append(dict(name="Vulture_vs_Wright_3v3", group="wrights", teams=[["Vulture"]*3, ["Wright"]*3]))
    for name, left, right in (
        ("PV_vs_BBBB", ["Penitent"]*2+["Vulture"]*2, ["Butcher"]*4),
        ("BV_vs_PPPP", ["Butcher"]*2+["Vulture"]*2, ["Penitent"]*4),
        ("PV_vs_BP", ["Penitent"]*2+["Vulture"]*2, ["Butcher"]*2+["Penitent"]*2),
        ("WV_vs_BBBB", ["Wright"]*2+["Vulture"]*2, ["Butcher"]*4),
        ("PV_vs_VVVV", ["Penitent"]*2+["Vulture"]*2, ["Vulture"]*4),
        ("mixed_vs_BBBB", list(recruit.SUITS), ["Butcher"]*4),
    ):
        cases.append(dict(name=name, group="squads", teams=[left, right]))
    for name in monsters.NAMES:
        # Four Varn is an explicit middle-size swarm, not a recipe-cost equivalence.
        cases.append(dict(name="Vulture4_vs_"+name, group="monsters", teams=[["Vulture"]*4, [name]*(4 if name == "Varn" else 1)]))
    for n in (1, 3):
        cases.append(dict(name=f"Vulture{n}_vs_tower", group="tower", teams=[["Vulture"]*n, []], structure_team=1))
    cases.append(dict(name="Vulture3_vs_fortified_Wrights", group="tower", teams=[["Vulture"]*3, ["Wright"]*3], structure_team=1, walls=True))
    return cases


def initial(case, seed_index, reflected):
    seed = f"vulture-range-paired:{seed_index}"
    w = dict(entities=Entities().snapshot(), data=dict(ranged_profile=m.RANGED,
             marching_round=0, marching_regen_round=0, kanifous_losses=[], kanifous_loss_round=1))
    monsters.configure(w)
    for team, names in enumerate(case['teams']):
        for index, name in enumerate(names):
            attrs = (monsters.profile if name in monsters.NAMES else recruit.profile)(name, "Lord", team, 0, 1)
            row = recruit.create(w, "range-team:"+str(team), index, team, attrs)
            recruit.place_spawn(w, row, seed)
    if 'structure_team' in case:
        team = case['structure_team']
        w['data']['field_structures'] = []
        for site in ([0, 1, 2] if case.get('walls') else [2]):
            builder_id = f"range-builder:{team}:{site}"
            if case.get('walls'):
                builder = next(r for r in w['entities']['entities'] if r['owner'] == team and r['ordinal'] == site)
                builder_id = builder['id']
                builder['attributes'].update(fort.anchor(team, site))
                builder['attributes'].update(wright_site=site, wright_owner=team, wright_built=True,
                    wright_guard_until=400, wright_repair_round=0, wright_released=False, wright_progress=32)
            elif builder_id not in w['entities']['used_ids']:
                w['entities']['used_ids'].append(builder_id)
                w['entities']['used_ids'].sort()
            tower = site == 2
            attrs = dict(structure='Tower' if tower else 'Wall', site=site, lane='Lord',
                         hp=6, max_hp=6, armor=4 if tower else 2, max_armor=4 if tower else 2,
                         attack=1 if tower else 0, ranged_next_tick=0, builder_id=builder_id, **fort.site_point(team, site))
            w['data']['field_structures'].append(dict(id=instance_id('wright_structure', builder_id, str(site)), kind='fortification', owner=team, attributes=attrs))
        w['data']['field_structures'].sort(key=lambda r:r['id'])
    if reflected:
        for row in w['entities']['entities'] + fort.rows(w):
            row['owner'] = 1-row['owner']
            attrs = row['attributes']
            attrs['x_fp'] = 2400-attrs['x_fp']
            if row['kind'] == 'marcher':
                attrs['direction'] *= -1
                if 'wright_owner' in attrs:
                    attrs['wright_owner'] = 1-attrs['wright_owner']
    return w, seed


def no_reaction(world, fact, seed, order):
    return dict(action="resolved", world=world, events=[])


def battle(case, seed_index, reflected, max_rounds, export=None):
    world, seed = initial(case, seed_index, reflected)
    start_hash = hashlib.sha256(codec.dumps(world).encode()).hexdigest()
    goals = [0, 0]
    metrics = [Counter(), Counter()]
    winner, reason = None, "round_cap"
    phases = 0
    for number in range(1, max_rounds+1):
        world['data']['kanifous_losses'] = []
        world['data']['kanifous_loss_round'] = number
        context = dict(world=world, seed=seed, round=number, hook='round_start_automatic',
                       player_order=[1, 0] if reflected else [0, 1], persistent_effects=[])
        regen = m.regenerate(context)
        if regen['action'] != 'resolved': raise ValueError(regen)
        context.update(world=regen['world'], hook='marching')
        if export is not None:
            export.write(codec.dumps(dict(name=f"{case['name']}:{seed_index}:{reflected}:{number}", context=context))+"\n")
        result = m.resolve(context, capture_ticks=False, reaction=no_reaction)
        if result['action'] != 'resolved': raise ValueError(result)
        phases += 1
        world = result['world']
        for record in result['events']:
            event = record['event']; data = event['data']
            if event['type'] in ('MARCHER_RANGED_ATTACK', 'MARCHER_MELEE_ATTACK'):
                pid = data['attacker']['owner'] ^ reflected
                metrics[pid]['ranged' if event['type']=='MARCHER_RANGED_ATTACK' else 'melee'] += 1
                metrics[pid]['hp_damage'] += data['damage_dealt']
                metrics[pid]['blocked'] += bool(data.get('blocked'))
                metrics[pid]['evaded'] += bool(data.get('evaded'))
                if data['attacker']['kind'] == 'fortification':
                    metrics[pid]['tower_shots'] += 1
                    metrics[pid]['tower_hp_damage'] += data['damage_dealt']
            elif event['type'] == 'MARCHER_DEFEATED':
                attacker = data.get('attacker', {})
                if 'owner' in attacker: metrics[attacker['owner'] ^ reflected]['kills'] += 1
        rows = world['entities']['entities']
        # Same arena escape rule: bodies at the far gate score and leave alive.
        for row in rows[:]:
            if row['attributes']['waiting']:
                goals[row['owner'] ^ reflected] += 1
                rows.remove(row)
        forces = [sum(r['owner'] == (team ^ reflected) for r in rows+fort.rows(world)) for team in (0, 1)]
        if not all(forces) or not rows:
            reason = 'resolved'
            break
    if goals[0] != goals[1]:
        winner = int(goals[1] > goals[0])
        reason = 'goals'
    elif not forces[0] and forces[1]: winner = 1
    elif not forces[1] and forces[0]: winner = 0
    elif not any(forces): reason = 'mutual_clear'
    living = [sum(r['owner'] == (team ^ reflected) for r in world['entities']['entities']) for team in (0,1)]
    return dict(winner=winner, reason=reason, rounds=phases, goals=goals, living=living,
                metrics=[dict(met) for met in metrics], initial_sha256=start_hash,
                final_sha256=hashlib.sha256(codec.dumps(world).encode()).hexdigest())


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--seeds', type=int, default=32)
    p.add_argument('--ranges', default='400:600,800:750,900:750')
    p.add_argument('--rounds', type=int, default=12)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--export-dir', type=Path)
    p.add_argument('--groups', default='counters,wrights,squads,monsters,tower')
    args = p.parse_args()
    settings = [tuple(map(int, x.split(':'))) for x in args.ranges.split(',')]
    selected = [c for c in scenarios() if c['group'] in args.groups.split(',')]
    if args.seeds < 1 or args.rounds < 1: p.error('seeds and rounds must be positive')
    reports, summary = [], {}
    begun = time.monotonic()
    identity = dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
                    python=platform.python_implementation()+' '+platform.python_version(),
                    script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    for vr, tr in settings:
        setting = f'{vr}/{tr}'
        summary[setting] = {}
        export = None
        if args.export_dir:
            args.export_dir.mkdir(parents=True, exist_ok=True)
            export = (args.export_dir/f'{vr}-{tr}.contexts.jsonl').open('w')
        with ranges(vr, tr):
            for case in selected:
                tally = Counter(); totals = [Counter(), Counter()]
                for seed_index in range(args.seeds):
                    for reflected in (0,1):
                        result = battle(case, seed_index, reflected, args.rounds, export)
                        tally['battles'] += 1
                        tally['wins' if result['winner'] == 0 else 'losses' if result['winner'] == 1 else 'draws'] += 1
                        tally['round_cap'] += result['reason'] == 'round_cap'
                        tally['phases'] += result['rounds']
                        for pid in (0,1): totals[pid].update(result['metrics'][pid])
                        reports.append(dict(setting=setting, case=case['name'], seed=seed_index, reflected=reflected, **result))
                summary[setting][case['name']] = dict(tally, metrics=[dict(t) for t in totals])
                print(setting, case['name'], dict(tally), f'{time.monotonic()-begun:.1f}s', flush=True)
        if export is not None: export.close()
    paired = defaultdict(dict)
    for r in reports: paired[(r['case'],r['seed'],r['reflected'])][r['setting']] = r
    for values in paired.values():
        if len({v['initial_sha256'] for v in values.values()}) != 1: raise AssertionError('unpaired initial state')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(dict(schema='U13_VULTURE_RANGE_PAIRED_V1', identity=identity,
        seeds=args.seeds, settings=settings, max_rounds=args.rounds, scenarios=selected,
        elapsed_seconds=time.monotonic()-begun, summary=summary, battles=reports), indent=2)+'\n')
    print('Saved',len(reports),'battles to',args.output,flush=True)


if __name__ == '__main__': main()
