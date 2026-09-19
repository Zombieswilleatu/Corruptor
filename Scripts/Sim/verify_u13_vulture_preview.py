#!/usr/bin/env python3
"""Directed goal-distance, range and complete native/Python replay checks."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

import run_u13_vulture_range_balance as trial
from verify_u13_vulture_ranges import ROOT, RUNNER, boundary_contexts, native_project
from u13_pysim import codec, marching as m, marching_spatial as spatial
from u13_pysim import recruitment as recruit, monsters
from u13_pysim.primitives import instance_id


def preview(world, advance=True):
    world['data']['lane_balance_preview'] = dict(version=spatial.PREVIEW_VERSION, goal_advance=advance)


def contexts():
    for owner in (0, 1):
        for name in ('outside', 'edge', 'arrival', 'toggle_off', 'current', 'contact',
                     'wall', 'screen', 'taunt', 'rout', 'deployment_hold', 'close_enemy_far_goal'):
            world, seed = trial.initial(dict(teams=[[], []]), 0, 0)
            if name != 'current': preview(world, name != 'toggle_off')
            x = dict(outside=1999, arrival=2100, wall=1648, close_enemy_far_goal=1000).get(name, 2000)
            a = recruit.profile('Vulture', 'Lord', 0, 0, 1)
            a.update(x_fp=x, y_fp=150 if name == 'wall' else 300, hp=1000, max_hp=1000, armor=0, regen=0)
            if name == 'rout':
                world['data']['rout_profile'] = m.ROUT
                a.update(rout_round=1, rout_effect_id='preview-rout')
            if name == 'deployment_hold': a['movement_ready_round'] = 2
            source = recruit.create(world, 'preview-vulture', 0, 0, a)
            if name == 'wall':
                builder = 'preview-wall-builder'
                world['entities']['used_ids'].append(builder)
                world['entities']['used_ids'].sort()
                world['data']['field_structures'] = [dict(id=instance_id('wright_structure', builder, '0'),
                    kind='fortification', owner=1, attributes=dict(structure='Wall', site=0, lane='Lord',
                    hp=6, max_hp=6, armor=2, max_armor=2, attack=0, ranged_next_tick=0,
                    builder_id=builder, **trial.fort.site_point(1, 0)))]
            else:
                name_b = 'Kurchin' if name == 'taunt' else 'Butcher'
                b = (monsters.profile if name_b == 'Kurchin' else recruit.profile)(name_b, 'Lord', 1, 0, 1)
                b.update(x_fp=x+80 if name == 'contact' else x-300, y_fp=300,
                         step_fp=0, hp=1000, max_hp=1000, armor=0, regen=0)
                recruit.create(world, 'preview-target', 0, 1, b)
            if name == 'screen':
                b = recruit.profile('Penitent', 'Lord', 0, 0, 1)
                b.update(x_fp=x+100, y_fp=300, step_fp=0)
                recruit.create(world, 'preview-screen', 0, 0, b)
            if owner:
                for row in world['entities']['entities'] + trial.fort.rows(world):
                    row['owner'] = 1-row['owner']
                    row['attributes']['x_fp'] = 2400-row['attributes']['x_fp']
                    if row['kind'] == 'marcher': row['attributes']['direction'] *= -1
            yield dict(name=f'{name}:{owner}', case=name, owner=owner, source=source['id'],
                context=dict(world=world, seed=seed, round=1, hook='marching',
                             player_order=[0, 1], persistent_effects=[]))
    for active, vulture, tower in ((False, 400, 600), (True, 400, 600)):
        for record in boundary_contexts(vulture, tower):
            if active: preview(record['context']['world'])
            record['name'] = f'{active}:'+record['name']
            record['case'] = 'boundary'
            yield record
    yield from counter_contexts()
    yield from spacing_contexts()
    yield from navigation_contexts()


def navigation_contexts():
    fixture = ROOT/'docs/evidence/U13_NAVIGATION_CROWD_FIXTURE_2026-09-19.json.gz'
    for owner in (0, 1):
        captured = json.loads(gzip.decompress(fixture.read_bytes()))
        if owner: captured['world'] = reflect_world(captured['world'])
        context = dict(world=captured['world'], seed=captured['seed'], round=25,
                       hook='marching', player_order=[0, 1], persistent_effects=[], full_roster=True)
        for phase in (0, 1):
            yield dict(name=f'navigation:crowded-seed:{owner}:{phase}', case='navigation_crowd',
                       ids=captured['tracked'], initial=captured['world'], minimum=4 if phase == 0 else 7, context=context)
            if phase == 0:
                first = m.resolve(context, capture_ticks=False, reaction=trial.no_reaction)
                context = dict(context, world=first['world'], round=26)
        world, seed = trial.initial(dict(teams=[[], []]), 0, 0)
        for index, (suit, pid, x, y) in enumerate([
            ('Butcher', 0, 1200, 300), ('Butcher', 0, 1248, 300),
            ('Butcher', 0, 1152, 300), ('Butcher', 0, 1200, 348), ('Butcher', 0, 1200, 252),
            ('Penitent', 1, 1500, 300), ('Penitent', 1, 1200, 600)]):
            a = recruit.profile(suit, 'Lord', pid, 0, 1)
            a.update(x_fp=x, y_fp=y, hp=1000, max_hp=1000, regen=0)
            if index: a['step_fp'] = 0
            unit = recruit.create(world, 'navigation-cage', index, pid, a)
            if index == 0: identity = unit['id']
        orient(world, owner)
        yield dict(name=f'navigation:unreachable-target:{owner}', case='navigation_retarget', source=identity,
                   context=dict(world=world, seed=seed, round=1, hook='marching', player_order=[0, 1], persistent_effects=[]))


def reflect_world(value):
    # Match U13LaneSandbox.mirror, including ownership in Wright assignments,
    # charm restoration, hazards and navigation waypoints.
    if isinstance(value, list): return [reflect_world(v) for v in value]
    if not isinstance(value, dict): return value
    result = {}
    for key, item in value.items():
        if key in ('owner', 'charm_owner', 'wright_owner', 'player_id', 'source_owner', 'target_owner') and item in (0, 1): result[key] = 1-item
        elif key == 'x_fp': result[key] = 2400-item
        elif key == 'direction': result[key] = -item
        else: result[key] = reflect_world(item)
    return result


def orient(world, owner):
    if not owner: return
    for row in world['entities']['entities'] + trial.fort.rows(world):
        row['owner'] = 1-row['owner']
        row['attributes']['x_fp'] = 2400-row['attributes']['x_fp']
        if row['kind'] == 'marcher': row['attributes']['direction'] *= -1


def counter_contexts():
    for owner in (0, 1):
        for melee in (False, True):
            for suit, armor in (('Butcher', 0), ('Butcher', 1), ('Butcher', 3), ('Penitent', 0), ('Vulture', 0), ('Wright', 0), ('Lemek', 0)):
                world, seed = trial.initial(dict(teams=[[], []]), 0, 0)
                a = recruit.profile('Vulture', 'Lord', 0, 0, 1)
                a.update(x_fp=1000, y_fp=300, hp=1000, max_hp=1000, regen=0)
                source = recruit.create(world, 'counter-vulture', 0, 0, a)
                b = (monsters.profile if suit in monsters.NAMES else recruit.profile)(suit, 'Lord', 1, 0, 1)
                b.update(x_fp=1080 if melee else 1300, y_fp=300, hp=1000, max_hp=1000, step_fp=0, armor=armor, regen=0)
                recruit.create(world, 'counter-target', 0, 1, b)
                orient(world, owner)
                yield dict(name=f'counter:{owner}:{melee}:{suit}:{armor}', case='counter', owner=owner,
                    source=source['id'], target_suit=suit, melee=melee, armor=armor,
                    context=dict(world=world, seed=seed, round=1, hook='marching', player_order=[0, 1], persistent_effects=[]))


def spacing_contexts():
    for owner in (0, 1):
        # Captured from a crowded Butcher/Penitent fight that oscillated forever
        # when blocked fighters could only sidestep on the lateral axis.
        world, seed = trial.initial(dict(teams=[['Butcher']*4, ['Penitent']*4]), 1, 0)
        positions = [(1357, 553, 1), (1374, 461, 0), (1352, 503, 1), (1334, 448, 0)]
        ids = []
        for row in world['entities']['entities'][:]:
            if row['owner'] == 1 and row['ordinal'] != 3:
                world['entities']['entities'].remove(row)
                continue
            x, y, armor = positions[row['ordinal']] if row['owner'] == 0 else (1339, 402, 3)
            row['attributes'].update(x_fp=x, y_fp=y, armor=armor)
            if row['owner'] == 0: ids.append(row['id'])
        orient(world, owner)
        yield dict(name=f'spacing:{owner}:side_chase', case='spacing', spacing='side_chase', owner=owner, ids=ids,
            context=dict(world=world, seed=seed, round=1, hook='marching', player_order=[0, 1], persistent_effects=[]))
        for name in ('stacked_ranged', 'stacked_melee', 'gate_corner', 'half_footprint', 'friendly_guard', 'converging'):
            world, seed = trial.initial(dict(teams=[[], []]), 0, 0)
            count = 2 if name in ('half_footprint', 'friendly_guard') else 4
            ids = []
            for index in range(count):
                suit = 'Butcher' if name in ('stacked_melee', 'converging', 'friendly_guard') else 'Vulture'
                a = recruit.profile(suit, 'Lord', 0, 0, 1)
                a.update(x_fp=1000, y_fp=300, hp=1000, max_hp=1000, regen=0)
                if name == 'gate_corner': a.update(x_fp=0, y_fp=0)
                if name == 'half_footprint': a['y_fp'] += index*42
                if name == 'friendly_guard' and index: a.update(x_fp=1042, step_fp=0)
                if name == 'converging': a.update(x_fp=800+(index%2)*84, y_fp=258+(index//2)*84)
                ids.append(recruit.create(world, 'spacing-unit', index, 0, a)['id'])
            if name != 'friendly_guard':
                b = recruit.profile('Butcher', 'Lord', 1, 0, 1)
                b.update(x_fp=300 if name == 'gate_corner' else 1300, y_fp=0 if name == 'gate_corner' else 300,
                         hp=1000, max_hp=1000, step_fp=0, regen=0)
                recruit.create(world, 'spacing-enemy', 0, 1, b)
            orient(world, owner)
            yield dict(name=f'spacing:{owner}:{name}', case='spacing', spacing=name, owner=owner, ids=ids,
                context=dict(world=world, seed=seed, round=1, hook='marching', player_order=[0, 1], persistent_effects=[]))


def check(record, result):
    events = [r['event'] for r in result['events']]
    shots = [e['data'] for e in events if e['type'] == 'MARCHER_RANGED_ATTACK']
    case = record['case']
    if case == 'navigation_retarget':
        states = [u['attributes'].get('navigation', {}) for e in events if e['type'] == 'MARCHING_TICK'
                  for u in e['data']['units'] if u['id'] == record['source']]
        assert any(s.get('avoid') for s in states), record['name']
        assert len({s.get('target') for s in states if s.get('target')}) >= 2, record['name']
        return
    if case == 'navigation_crowd':
        before = {u['id']: u for u in record['initial']['entities']['entities']}
        attackers = {e['data']['attacker']['id'] for e in events if e['type'] in ('MARCHER_MELEE_ATTACK', 'MARCHER_RANGED_ATTACK')}
        moved = {u['id'] for e in events if e['type'] == 'MARCHING_TICK' for u in e['data']['units']
                 if u['id'] in record['ids'] and trial.fort.distance(before[u['id']]['attributes'], u['attributes']) > 42**2}
        freed = set(record['ids']) & (moved | attackers)
        assert len(freed) >= record['minimum'], (record['name'], len(freed), len(record['ids']))
        print(record['name'], len(freed), 'of', len(record['ids']), 'previously jammed units moved or fought', flush=True)
        return
    if case == 'counter':
        kind = 'MARCHER_MELEE_ATTACK' if record['melee'] else 'MARCHER_RANGED_ATTACK'
        hits = [e['data'] for e in events if e['type'] == kind and e['data']['attacker']['id'] == record['source']]
        assert hits and hits[0]['tick'] == 0, record['name']
        hit = hits[0]
        amount = 2 if record['target_suit'] == 'Butcher' else 1
        expected = 0 if hit.get('blocked') or hit.get('evaded') else max(0, amount-record['armor'])
        assert hit['damage_dealt'] == expected, (record['name'], hit['damage_dealt'], expected)
        assert hit['attacker']['attributes']['attack'] == 1, record['name']
        return
    if case == 'spacing':
        for event in events:
            if event['type'] != 'MARCHING_TICK': continue
            rows = [r for r in event['data']['units'] if r['id'] in record['ids']]
            for index, row in enumerate(rows):
                for other in rows[index+1:]:
                    assert trial.fort.distance(row['attributes'], other['attributes']) >= 42**2, (record['name'], event['data']['tick'])
        if record['spacing'] == 'friendly_guard':
            before = next(r for r in record['context']['world']['entities']['entities'] if r['id'] == record['ids'][0])
            end = next(r for r in result['world']['entities']['entities'] if r['id'] == record['ids'][0])
            assert (end['attributes']['x_fp']-before['attributes']['x_fp'])*(1 if record['owner'] == 0 else -1) > 42, record['name']
        if record['spacing'] == 'side_chase':
            assert any(e['type'] == 'MARCHER_MELEE_ATTACK' for e in events), record['name']
        return
    if case == 'boundary':
        spec = record['boundary']
        assert any(s['tick'] == 0 for s in shots) != spec['outside'], record['name']
        if spec['tower'] and spec['outside']: assert not shots, record['name']
        return
    identity, owner = record['source'], record['owner']
    before = next(r['attributes'] for r in record['context']['world']['entities']['entities'] if r['id'] == identity)
    ticks = [e['data'] for e in events if e['type'] == 'MARCHING_TICK']
    first = next(r['attributes'] for r in ticks[0]['units'] if r['id'] == identity)
    end = next(r['attributes'] for r in result['world']['entities']['entities'] if r['id'] == identity)
    progress = (first['x_fp']-before['x_fp'])*(1 if owner == 0 else -1)
    if case in ('edge', 'arrival', 'screen'):
        assert progress == 4, (record['name'], progress)
        assert any(s['tick'] == 0 and s['attacker']['id'] == identity for s in shots), record['name']
    elif case == 'rout':
        assert progress < 0 and not any(s['attacker']['id'] == identity for s in shots), record['name']
    else:
        assert progress == 0, (record['name'], progress)
    if case == 'arrival':
        assert end['waiting'] and end['x_fp'] == (2400 if owner == 0 else 0), record['name']
        assert sum(e['type'] == 'MARCHER_WAITING' and e['data']['entity_id'] == identity for e in events) == 1
    if case == 'wall':
        wall_x = 1760 if owner == 0 else 640
        assert (wall_x-end['x_fp'])*(1 if owner == 0 else -1) >= 24, record['name']
        assert trial.fort.rows(result['world']), record['name']
    if case in ('outside', 'toggle_off', 'current', 'contact', 'taunt', 'close_enemy_far_goal'):
        assert end['x_fp'] == before['x_fp'], record['name']
    assert spatial.vulture_range(result['world']) == 400
    assert spatial.tower_range(result['world']) == 600


def run(godot, output):
    records = list(contexts())
    expected = {r['name']: r for r in records}
    version = subprocess.check_output([str(godot), '--version'], text=True).strip()
    with tempfile.TemporaryDirectory(prefix='u13-vulture-preview-') as temporary:
        project = Path(temporary)
        sources = native_project(project, 400, 600)
        inputs, native = project/'contexts.jsonl', project/'native.jsonl'
        inputs.write_text(''.join(codec.dumps(dict(name=r['name'], context=r['context']))+'\n' for r in records))
        completed = subprocess.run([str(godot), '--headless', '--path', str(project), '--script', 'res://'+RUNNER,
            '--', str(inputs), str(native), '400', '600'], capture_output=True, text=True, timeout=240)
        log = completed.stdout + completed.stderr
        if completed.returncode or 'ERROR:' in log: raise RuntimeError(log)
        names = []
        for line in native.read_text().splitlines():
            record = codec.loads(line)
            result = m.resolve(record['context'], capture_ticks=True, reaction=trial.no_reaction)
            diff = codec.first_difference(record['result'], result)
            assert not diff, record['name']+': '+str(diff)
            check(expected[record['name']], result)
            names.append(record['name'])
        assert names == [r['name'] for r in records]
        report = dict(schema='U13_MARCHER_NAVIGATION_VERIFICATION_V1', runtime=version,
                      phases=len(names), ticks=200*len(names), failures=0, cases=names,
                      contexts_sha256=hashlib.sha256(inputs.read_bytes()).hexdigest(),
                      native_sources_sha256=sources)
    output.write_text(json.dumps(report, indent=2)+'\n')
    print(f'{len(names)} complete native/Python phases matched; goal-distance and range checks passed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    run(args.godot.resolve(), args.output)
