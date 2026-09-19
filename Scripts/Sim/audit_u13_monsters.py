#!/usr/bin/env python3
"""Current lane roster audit; native staging inputs, production Python combat.

Controlled outcomes are lane results, not full-game wins. Recipe comparisons
use the same sampled printed cards on each side; ordinary bodies are what
those cards would produce without choosing the monster. No tuning overrides.
"""
import argparse
from collections import Counter, defaultdict
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor, as_completed
import gzip
import hashlib
import itertools
import json
from pathlib import Path
import platform
import subprocess
import time

from u13_pysim import codec, marching as m, monsters, monster_effects as fx
from u13_pysim import field_fortifications as fort
from u13_pysim.copying import copy_data

SUITS = ['Penitent', 'Butcher', 'Vulture', 'Wright']
ROOT = Path(__file__).resolve().parents[2]


def cases():
    result = []
    for a, b in itertools.combinations(SUITS + list(monsters.NAMES), 2):
        result.append(dict(name=f'single:{a}:{b}', group='single', teams=[[a], [b]]))
    for a, b in itertools.combinations(SUITS, 2):
        result.append(dict(name=f'squad:{a}:{b}', group='squad', teams=[[a]*4, [b]*4]))
    for name in monsters.NAMES:
        for core, group in (([], 'recipe'), (SUITS, 'recipe_supported')):
            result.append(dict(name=f'{group}:{name}', group=group, recipe=name, core=core, focus=name))
        for label, opponent in [('shock', ['Butcher']*6), ('screen', ['Penitent']*3+['Vulture']*3), ('mixed', SUITS+['Butcher']*2)]:
            result.append(dict(name=f'supported:{name}:{label}', group='supported', focus=name, teams=[SUITS+[name], opponent]))
    return result


def resolve(world, seed, number, capture_ticks=False):
    # Matches Sim.resolve_round(), including charm restoration BEFORE regen.
    world = copy_data(world)
    fx.end_round(world, number-1)
    world['data'].update(kanifous_losses=[], kanifous_loss_round=number)
    context = dict(world=world, seed=seed, round=number, hook='round_start_automatic', player_order=[0, 1], persistent_effects=[], full_roster=True)
    regen = m.regenerate(context)
    if regen['action'] != 'resolved': raise ValueError(regen)
    context.update(world=regen['world'], hook='marching')
    result = m.resolve(context, capture_ticks=capture_ticks, reaction=no_reaction)
    if result['action'] != 'resolved': raise ValueError(result)
    return result


def no_reaction(world, fact, seed, order):
    return dict(action='resolved', world=world, events=[])


def finish(result, goals, seen, reflected):
    world = result['world']
    for row in result['events']:
        event = row['event']; d = event['data']
        if event['type'] == 'MARCHER_WAITING':
            team = (0 if d['x_fp'] == 2400 else 1) ^ reflected
            if d['entity_id'] not in seen[team]:
                goals[team] += 1; seen[team].add(d['entity_id'])
    world['entities']['entities'] = [r for r in world['entities']['entities'] if not r['attributes']['waiting']]
    active = {r['id'] for r in world['entities']['entities']}
    for lane, duel in list(world['data'].get('marching_duels', {}).items()):
        if any(r['id'] not in active for r in duel['units']): del world['data']['marching_duels'][lane]
    world['data']['kanifous_losses'] = []
    world['data']['monsters']['death_ids'] = []
    fx.end_round(world, world['data']['marching_round'])
    return world


def name(row):
    return row.get('attributes', {}).get('monster_id', row.get('attributes', {}).get('suit', 'Tower' if row.get('kind') == 'fortification' else 'Unknown'))


class Metrics:
    def __init__(self):
        self.units = {}
        self.fields = {}
        self.charm_sources = set()
        self.metrics = defaultdict(Counter)

    def observe(self, rows, staged=False, number=1):
        for row in rows:
            identity = row['id']; who = name(row); a = row['attributes']
            if identity not in self.units:
                self.metrics[who]['bodies_seen'] += 1
                self.units[identity] = who
            if staged: self.metrics[who]['staged_body_rounds'] += 1
            elif a.get('movement_ready_round', 0) <= number and not a.get('waiting', False):
                self.metrics[who]['active_body_rounds'] += 1
                if a.get('monster_id') == 'Dotra' and a.get('hidden'): self.metrics[who]['hidden_at_round_start'] += 1

    def events(self, events):
        for event in events:
            d, kind = event['data'], event['type']
            if kind in ('MARCHER_MELEE_ATTACK', 'MARCHER_RANGED_ATTACK', 'MONSTER_ATTACK'):
                source, target = d['attacker'], d['target']
                out, incoming = self.metrics[name(source)], self.metrics[name(target)]
                ability = d.get('ability', 'Melee' if kind == 'MARCHER_MELEE_ATTACK' else 'Ranged')
                friendly = source['owner'] == target['owner']
                out['attacks'] += 1; incoming['incoming_attacks'] += 1
                out['recorded_hp_damage'] += d.get('damage_dealt', 0)
                if d.get('evaded'): incoming['evaded'] += 1
                if d.get('blocked'): incoming['blocked'] += 1
                if not d.get('evaded') and not d.get('blocked'):
                    out['landed_hits'] += 1
                    if d.get('damage_dealt', 0) > 0: out['damaging_hits'] += 1
                if kind == 'MONSTER_ATTACK':
                    out[ability+':hits'] += 1
                    out[ability+':hp_damage'] += d.get('damage_dealt', 0)
                    out[ability+(':ally_hits' if friendly else ':enemy_hits')] += 1
                    if friendly: out[ability+':ally_hp_damage'] += d.get('damage_dealt', 0)
                if name(source) == 'Tumler' and name(target) in ('Vulture', 'Kopita', 'Fyra', 'Sooge', 'Sinodek'):
                    out['support_target_hits'] += 1
            elif kind == 'MARCHER_DEFEATED':
                self.metrics[name(d['victim'])]['deaths'] += 1
                if d.get('attacker'): self.metrics[name(d['attacker'])]['kills'] += 1
            elif kind == 'MONSTER_POISONED': self.metrics['Varn']['poison_procs'] += 1
            elif kind == 'MONSTER_CHARMED':
                self.metrics['Fyra']['charm_procs'] += 1
                self.metrics[self.units.get(d['unit_id'], 'Unknown')]['times_charmed'] += 1
                if d['source_id'] not in self.charm_sources:
                    self.charm_sources.add(d['source_id'])
                    self.metrics['Fyra']['casters_who_charmed'] += 1
            elif kind == 'MONSTER_HUNT_RETARGETED': self.metrics['Tumler']['melee_intercepts'] += 1
            elif kind == 'MONSTER_ROOTED': self.metrics['Sooge']['rooted'] += 1
            elif kind == 'MONSTER_BEAM_FIRED': self.metrics['Sooge']['beams_fired'] += 1
            elif kind == 'MONSTER_BEAM_DETONATED': self.metrics['Sooge']['beams_detonated'] += 1
            elif kind == 'MONSTER_CONCEALMENT':
                self.metrics['Dotra']['concealment_rounds'] += 1
                self.metrics['Dotra']['hidden_rounds'] += bool(d['hidden'])
            elif kind == 'MONSTER_EXPOSURE_PULSE':
                self.metrics['Dotra']['exposure_pulses'] += 1
                self.metrics['Dotra']['enemies_exposed'] += len(d['affected'])
            elif kind == 'MONSTER_PULSE':
                metric = self.metrics['Kopita']
                metric['heal_pulses' if d['healing'] else 'harm_pulses'] += 1
                if d['healing']:
                    metric['useful_heal_pulses'] += bool(d['healed'])
                    metric['hp_healed'] += sum(r['amount'] for r in d['healed'])
                    metric['healed_bodies'] += len(d['healed'])
            elif kind == 'MONSTER_FIELD_CREATED':
                self.fields[d['field']['id']] = d['field']
                self.metrics['Lemek' if d['field']['kind'] == 'pool' else 'Sinodek']['pools' if d['field']['kind'] == 'pool' else 'portals'] += 1
            elif kind == 'MONSTER_BANISHED':
                self.metrics[name(d['unit'])]['banished'] += 1
                self.metrics['Sinodek']['banishments'] += 1
                portal = self.fields.get(d['portal_id'])
                if portal:
                    self.metrics['Sinodek']['ally_banishments' if portal['owner'] == d['unit']['owner'] else 'enemy_banishments'] += 1

    def export(self):
        return {key: dict(value) for key, value in sorted(self.metrics.items())}


def canonical_owner(row, reflected):
    # A charm is temporary, so it is not an elimination of the original army.
    return row['attributes'].get('charm_owner', row['owner']) ^ reflected


def controlled(task):
    record, max_rounds = task
    world, seed, reflected = record['world'], record['seed'], int(record['reflected'])
    initial = Counter((canonical_owner(r, reflected), name(r)) for r in world['entities']['entities'])
    goals, seen, metric = [0, 0], [set(), set()], Metrics()
    parity = []; capture = record['seed_index'] == 0 and not reflected and record['group'] == 'recipe_supported'
    for offset in range(max_rounds):
        number = record['round']+offset
        metric.observe(world['entities']['entities'], number=number)
        raw = copy_data(world) if capture else None
        result = resolve(world, seed, number, capture)
        metric.events([r['event'] for r in result['events'] if r['event']['type'] != 'MARCHING_TICK'])
        if capture:
            sample = dict(name=f"{record['case']}:{seed}:{number}", world=raw, seed=seed, round=number,
                          result_sha256=hashlib.sha256(codec.dumps(result).encode()).hexdigest())
            if not parity: parity.append(sample)
            elif len(parity) == 1: parity.append(sample)
            else: parity[-1] = sample
        world = finish(result, goals, seen, reflected)
        forces = [sum(canonical_owner(r, reflected) == pid for r in world['entities']['entities']+fort.rows(world)) for pid in (0, 1)]
        # Empty lanes with abandoned walls cannot produce another encounter.
        terminal = not all(forces) or not world['entities']['entities']
        if terminal and not world['data']['monsters']['pending_beams']: break
    winner = None
    if terminal:
        if goals[0] != goals[1]: winner = int(goals[1] > goals[0])
        elif bool(forces[0]) != bool(forces[1]): winner = int(bool(forces[1]))
    outcome = {key: record[key] for key in ('case', 'group', 'focus', 'teams', 'recipe_hand', 'seed_index', 'reflected')}
    outcome.update(winner=winner, round_cap=not terminal, rounds=offset+1, goals=goals, surviving_forces=forces,
                   initial=[{who: count for (owner, who), count in initial.items() if owner == pid} for pid in (0,1)],
                   metrics=metric.export(), final_sha256=hashlib.sha256(codec.dumps(world).encode()).hexdigest(), parity=parity)
    return outcome


def dump(path, data):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    raw = (json.dumps(data, indent=2)+'\n').encode()
    if path.suffix == '.gz': path.write_bytes(gzip.compress(raw, mtime=0))
    else: path.write_bytes(raw)


def run_controlled(args):
    started = time.monotonic()
    summary = defaultdict(Counter); metrics = defaultdict(Counter); reports = []
    def tasks():
        with args.initials.open() as source:
            for line in source: yield codec.loads(line), args.rounds
    with args.samples.open('w') as samples, ProcessPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(controlled, tasks(), chunksize=8):
            for sample in result.pop('parity'): samples.write(codec.dumps(sample)+'\n')
            reports.append(result)
            bucket = summary[result['case']]
            bucket.update(battles=1, wins=int(result['winner']==0), losses=int(result['winner']==1), draws=int(result['winner'] is None), round_cap=int(result['round_cap']), phases=result['rounds'])
            for who, values in result['metrics'].items(): metrics[who].update(values)
            if len(reports) % 32 == 0:
                print('CONTROLLED', len(reports), result['case'], dict(bucket), f'{time.monotonic()-started:.1f}s', flush=True)
    data = dict(schema='U13_MONSTER_AUDIT_V1', revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                python=platform.python_implementation()+' '+platform.python_version(), navigation_sha256=hashlib.sha256((ROOT/'Scripts/Sim/u13_pysim/marcher_navigation.py').read_bytes()).hexdigest(),
                movement_sha256=hashlib.sha256((ROOT/'Scripts/Sim/u13_pysim/marching.py').read_bytes()).hexdigest(),
                seeds=len({r['seed_index'] for r in reports}), paired_seats=True, rounds=args.rounds, elapsed_seconds=time.monotonic()-started,
                summary={k: dict(v) for k,v in summary.items()}, metrics={k: dict(v) for k,v in metrics.items()}, battles=reports)
    dump(args.output, data)
    print('Saved', len(reports), 'battles:', args.output, flush=True)


def read_rows(path):
    with (gzip.open(path, 'rt') if path.suffix == '.gz' else path.open()) as stream:
        for line in stream: yield codec.loads(line)


def run_native_waves(args):
    args.directory.mkdir(parents=True, exist_ok=True)
    def run(index, swapped):
        seed = ['lane-f881e7ec-e3aebe70', 'lane-30d27b94-0258ddb4'][index] if index < 2 else f'monster-mixed:{index}'
        stem = args.directory/f'waves-{index:02d}-{int(swapped)}'
        with stem.with_suffix('.log').open('w') as log:
            subprocess.run([str(args.godot), '--headless', '--path', str(ROOT), '--script', 'Scripts/Sim/U13MonsterAuditRunner.gd', '--', 'waves', seed, str(args.rounds), 'swap' if swapped else 'normal', str(stem.with_suffix('.jsonl'))], stdout=log, stderr=subprocess.STDOUT, check=True)
        text = stem.with_suffix('.log').read_text()
        if 'SCRIPT ERROR' in text or 'ERROR:' in text: raise ValueError(str(stem))
        print('NATIVE WAVES COMPLETE', seed, swapped, flush=True)
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(run, i, swapped) for i in range(args.seeds) for swapped in (False, True)]
        for future in as_completed(futures): future.result()


def summarize_waves(args):
    metric = Metrics(); games = []; parity = []; by_round = []
    for path in sorted(args.directory.glob('waves-*.jsonl')):
        game_metric = Metrics(); rows = list(read_rows(path)); meta = rows[0]
        assert rows[-1]['kind'] == 'finished', str(path)
        for record in rows[1:-1]:
            n = record['round']
            game_metric.observe(record['before'], number=n)
            game_metric.observe(record['staged'], staged=True, number=n)
            game_metric.events(record['events'])
            for wave in record['waves']:
                if wave.get('monster'): game_metric.metrics[wave['monster']]['summons'] += 1
            if 'parity' in record:
                parity.append(dict(record['parity'], name=f"{meta['seed']}:{meta['swapped']}:{n}"))
            by_round.append(dict(seed=meta['seed'], swapped=meta['swapped'], round=n, goals=[r['reached_goal'] for r in record['totals']], field=len(record['after']), staged=len(record['staged'])))
        for who, values in game_metric.metrics.items(): metric.metrics[who].update(values)
        games.append(dict(meta, totals=rows[-1]['totals'], metrics=game_metric.export()))
    with args.samples.open('w') as stream:
        for sample in parity: stream.write(codec.dumps(sample)+'\n')
    dump(args.output, dict(schema='U13_MONSTER_WAVES_V1', games=games, metrics=metric.export(), history=by_round))
    print('WAVES SUMMARY', len(games), 'games', len(by_round), 'rounds', metric.export(), flush=True)


def verify_samples(args):
    rows = list(read_rows(args.input))
    expected = None
    if args.native:
        expected = {r['name']: r['result_sha256'] for r in read_rows(args.native)}
        assert len(expected) == len(rows)
    for record in rows:
        digest = hashlib.sha256(codec.dumps(resolve(record['world'], record['seed'], record['round'], True)).encode()).hexdigest()
        reference = expected[record['name']] if expected else record['result_sha256']
        assert digest == reference, (record['name'], digest, reference)
        if expected: assert digest == record['result_sha256'], 'sampling changed the Python result'
        print('PARITY', record['name'], flush=True)
    print(json.dumps(dict(phases=len(rows), ticks=len(rows)*200, complete_world_and_events_match=True)), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('config'); p.add_argument('--seeds', type=int, default=16); p.add_argument('--output', type=Path, required=True)
    p = sub.add_parser('controlled'); p.add_argument('--initials', type=Path, required=True); p.add_argument('--workers', type=int, default=4); p.add_argument('--rounds', type=int, default=16); p.add_argument('--output', type=Path, required=True); p.add_argument('--samples', type=Path, required=True)
    p = sub.add_parser('waves'); p.add_argument('--directory', type=Path, required=True); p.add_argument('--output', type=Path, required=True); p.add_argument('--samples', type=Path, required=True)
    p = sub.add_parser('native-waves'); p.add_argument('--godot', type=Path, required=True); p.add_argument('--directory', type=Path, required=True); p.add_argument('--rounds', type=int, default=30); p.add_argument('--seeds', type=int, default=8); p.add_argument('--workers', type=int, default=4)
    p = sub.add_parser('verify'); p.add_argument('--input', type=Path, required=True); p.add_argument('--native', type=Path)
    args = parser.parse_args()
    if args.command == 'config': dump(args.output, dict(seeds=args.seeds, cases=cases()))
    elif args.command == 'controlled': run_controlled(args)
    elif args.command == 'waves': summarize_waves(args)
    elif args.command == 'native-waves': run_native_waves(args)
    else: verify_samples(args)


if __name__ == '__main__': main()
