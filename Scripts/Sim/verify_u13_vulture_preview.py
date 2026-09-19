#!/usr/bin/env python3
"""Directed goal-distance, range and complete native/Python replay checks."""
import argparse
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
            x = dict(outside=1499, arrival=1600, close_enemy_far_goal=1000).get(name, 1500)
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
                b.update(x_fp=1580 if name == 'contact' else x-(300 if name == 'taunt' else 400), y_fp=300,
                         step_fp=0, hp=1000, max_hp=1000, armor=0, regen=0)
                recruit.create(world, 'preview-target', 0, 1, b)
            if name == 'screen':
                b = recruit.profile('Penitent', 'Lord', 0, 0, 1)
                b.update(x_fp=1600, y_fp=300, step_fp=0)
                recruit.create(world, 'preview-screen', 0, 0, b)
            if owner:
                for row in world['entities']['entities'] + trial.fort.rows(world):
                    row['owner'] = 1-row['owner']
                    row['attributes']['x_fp'] = 2400-row['attributes']['x_fp']
                    if row['kind'] == 'marcher': row['attributes']['direction'] *= -1
            yield dict(name=f'{name}:{owner}', case=name, owner=owner, source=source['id'],
                context=dict(world=world, seed=seed, round=1, hook='marching',
                             player_order=[0, 1], persistent_effects=[]))
    for active, vulture, tower in ((False, 400, 600), (True, 900, 1125)):
        for record in boundary_contexts(vulture, tower):
            if active: preview(record['context']['world'])
            record['name'] = f'{active}:'+record['name']
            record['case'] = 'boundary'
            yield record


def check(record, result):
    events = [r['event'] for r in result['events']]
    shots = [e['data'] for e in events if e['type'] == 'MARCHER_RANGED_ATTACK']
    case = record['case']
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
    if case in ('edge', 'arrival', 'screen', 'wall'):
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
    assert spatial.vulture_range(result['world']) == (400 if case == 'current' else 900)
    assert spatial.tower_range(result['world']) == (600 if case == 'current' else 1125)


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
            '--', str(inputs), str(native), '400', '600'], capture_output=True, text=True, timeout=120)
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
        report = dict(schema='U13_VULTURE_PREVIEW_VERIFICATION_V1', runtime=version,
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
