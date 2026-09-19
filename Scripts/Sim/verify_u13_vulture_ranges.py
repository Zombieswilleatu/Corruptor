#!/usr/bin/env python3
"""Replay the paired lane corpus in isolated native projects and compare all ticks.

The production .gd files are copied unchanged except the two explicit range
constants in temporary projects. The checkout and production defaults are intact.
"""
import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tempfile

import run_u13_vulture_range_balance as trial
from u13_pysim import codec, marching as m, recruitment as recruit

ROOT = Path(__file__).resolve().parents[2]
RUNNER = 'Scripts/Sim/U13RangeReplayRunner.gd'


def native_project(destination, vulture, tower):
    pending, seen, hashes = [RUNNER], set(), {}
    while pending:
        name = pending.pop()
        if name in seen: continue
        seen.add(name)
        raw = (ROOT/name).read_bytes()
        hashes[name] = hashlib.sha256(raw).hexdigest()
        if name.endswith('.gd'):
            source = raw.decode()
            pending.extend(re.findall(r'res://([A-Za-z0-9_./-]+\.(?:gd|tscn|gdshader))', source))
            if name.endswith('/U13RangedMarching.gd'):
                source, n = re.subn(r'const RANGE_FP: int = \d+', 'const RANGE_FP: int = '+str(vulture), source)
                assert n == 1
            elif name.endswith('/U13FieldFortifications.gd'):
                source, n = re.subn(r'const TOWER_RANGE: int = \d+', 'const TOWER_RANGE: int = '+str(tower), source)
                assert n == 1
            raw = source.encode()
        target = destination/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    (destination/'project.godot').write_text('[application]\nconfig/name="U13 range parity"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    return hashes


def boundary_contexts(vulture, tower):
    for owner in (0, 1):
        for structure in (False, True):
            reach = tower if structure else vulture
            for outside in (False, True):
                case = dict(teams=[[], []])
                if structure: case['structure_team'] = owner
                world, seed = trial.initial(case, 0, 0)
                start = trial.fort.site_point(owner, 2)['x_fp'] if structure else (200 if owner == 0 else 2200)
                if not structure:
                    a = recruit.profile('Vulture', 'Lord', owner, 0, 1)
                    # Deployment hold prevents movement from crossing the edge
                    # before volley selection; incoming fire can still wake it.
                    a.update(x_fp=start, ranged_next_tick=0, movement_ready_round=2)
                    recruit.create(world, 'range-boundary-source', 0, owner, a)
                a = recruit.profile('Butcher', 'Lord', 1-owner, 0, 1)
                a.update(x_fp=start+(reach+int(outside))*(1 if owner == 0 else -1),
                         step_fp=0, hp=1000, max_hp=1000, regen=0)
                recruit.create(world, 'range-boundary-target', 0, 1-owner, a)
                yield dict(name=f"boundary:{owner}:{structure}:{outside}",
                    boundary=dict(tower=structure, outside=outside, owner=owner),
                    context=dict(world=world, seed=seed, round=1, hook='marching', player_order=[0,1], persistent_effects=[]))


def run(godot, settings, output):
    version = subprocess.check_output([str(godot), '--version'], text=True).strip()
    results = []
    with tempfile.TemporaryDirectory(prefix='u13-vulture-native-') as temporary:
        temp = Path(temporary)
        for vulture, tower in settings:
            project = temp/f'{vulture}-{tower}'
            project.mkdir()
            sources = native_project(project, vulture, tower)
            inputs, native = project/'contexts.jsonl', project/'native.jsonl'
            boundaries = {}
            with trial.ranges(vulture,tower), inputs.open('w') as stream:
                for case in trial.scenarios():
                    for reflected in (0,1):
                        # One entire combat-heavy phase per case and owner.
                        # The balance run still resolves every round. This
                        # parity sample avoids replaying mostly empty travel.
                        captured = io.StringIO()
                        trial.battle(case, 0, reflected, 12, captured)
                        chosen, highest = None, -1
                        for line in captured.getvalue().splitlines():
                            record = codec.loads(line)
                            resolved = m.resolve(record['context'],capture_ticks=False,reaction=trial.no_reaction)
                            score = sum(e['event']['type'] in ('MARCHER_RANGED_ATTACK','MARCHER_MELEE_ATTACK','MONSTER_ATTACK') for e in resolved['events'])
                            if score > highest: chosen, highest = line, score
                        stream.write(chosen+'\n')
                for record in boundary_contexts(vulture,tower):
                    boundaries[record['name']] = record['boundary']
                    stream.write(codec.dumps(dict(name=record['name'],context=record['context']))+'\n')
            completed = subprocess.run([str(godot),'--headless','--path',str(project),'--script','res://'+RUNNER,
                '--',str(inputs),str(native),str(vulture),str(tower)],capture_output=True,text=True,timeout=180)
            log = completed.stdout+completed.stderr
            if completed.returncode or 'SCRIPT ERROR:' in log or 'ERROR:' in log:
                raise RuntimeError(log)
            counts = Counter(); phases = 0; checks = 0
            with trial.ranges(vulture,tower), native.open() as stream:
                for line in stream:
                    record = codec.loads(line)
                    actual = m.resolve(record['context'],capture_ticks=True,reaction=trial.no_reaction)
                    diff = codec.first_difference(record['result'],actual)
                    if diff: raise AssertionError(record['name']+': '+diff)
                    phases += 1
                    counts.update(e['event']['type'] for e in actual['events'])
                    if phases % 40 == 0: print(vulture,tower,'matched',phases,'phases',flush=True)
                    if record['name'] in boundaries:
                        spec = boundaries[record['name']]
                        shots = [e['event']['data'] for e in actual['events'] if e['event']['type']=='MARCHER_RANGED_ATTACK']
                        at_zero = any(s['tick']==0 for s in shots)
                        # An out-of-range Vulture walks closer before firing;
                        # a tower is fixed and must never acquire that target.
                        if at_zero == spec['outside']: raise AssertionError('range edge '+record['name'])
                        if spec['tower'] and spec['outside'] and shots: raise AssertionError('tower range '+record['name'])
                        checks += 1
            expected_phases = sum(1 for _ in inputs.open())
            if phases != expected_phases or checks != 8: raise AssertionError('incomplete replay')
            result = dict(vulture_range=vulture,tower_range=tower,phases=phases,
                ticks=counts['MARCHING_TICK'],boundary_checks=checks,event_types=dict(counts),
                contexts_sha256=hashlib.sha256(inputs.read_bytes()).hexdigest(),
                native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),native_sources_sha256=sources)
            results.append(result)
            print(vulture,tower,phases,'complete phases matched; eight boundary checks passed',flush=True)
    output.write_text(json.dumps(dict(schema='U13_VULTURE_RANGE_NATIVE_PARITY_V1',
        runtime=version,scope='One combat-heavy complete phase per scenario and mirrored owner, seed 0; eight exact boundary phases per setting.',
        settings=results,failures=0),indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--ranges',default='400:600,800:750,900:750,900:1125')
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    run(args.godot.resolve(),[tuple(map(int,s.split(':'))) for s in args.ranges.split(',')],args.output)
