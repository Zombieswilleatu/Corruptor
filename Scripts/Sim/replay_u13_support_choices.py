#!/usr/bin/env python3
"""Controlled continuations from the saved V10/V11 support comparison.

Change one opening submission, preserve its ordinary order and opposing plan,
then let the original frozen policies respond normally. These selected examples
diagnose choices; they are not an independent strength evaluation.
"""
import argparse
from concurrent.futures import ProcessPoolExecutor, as_completed
import gzip
import hashlib
import importlib.util
import json
import multiprocessing
from pathlib import Path
import sys
import time
import traceback

from u13_doctrine.comparison import freeze_baseline
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.observation import observe, Preview
from u13_doctrine.survey import atomic_json
from u13_pysim import full_match_inputs
from u13_pysim.benchmark_full_match import digest
from u13_pysim.copying import copy_data
from u13_pysim.power_match import PowerMatch
from u13_pysim.power_rules import declaration
from u13_pysim.verify import source_identity

V11 = '5074b720d601339b8f6bf7bd0753e984aba765f9'
V10 = 'c0b2a76fdc1ae33239194a18f9477bbc58fc3d80'
CASES = (
    ('humbaba_valak_00', 0, 1, 'loss'),
    ('kalligan_humbaba_02', 1, 1, 'loss'),
    ('gremory_humbaba_00', 1, 1, 'win'),
    ('kalligan_humbaba_00', 1, 1, 'win'),
    ('deimos_deimos_00', 0, 2, 'loss'),
)


def load_policy(directory, name, weights):
    path = Path(directory)
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, path/'__init__.py', submodule_search_locations=[str(path)])
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
    module = __import__(name+'.common', fromlist=['CommonSmartCore'])
    return module.CommonSmartCore(module.Weights(**weights))


def specs():
    for pair, seat, number, result in CASES:
        choices = ([dict(muster=m, breath=b) for m in ('Lord', 'Castle') for b in ('hold', 'Lord', 'Castle')]
                   if 'humbaba' in pair else [dict(rout=r, work=w) for r in (False, True) for w in ('SiegeEngine', 'Bastion')])
        for choice in choices:
            yield dict(name=pair+'__'+'_'.join(str(v) for v in choice.values()),
                       source=pair+'__candidate_p'+str(seat), seat=seat, round=number,
                       selection=result, choice=choice)


def intervene(plan, view, choice):
    plan = copy_data(plan)
    seat, number = view['player_id'], view['round']
    if 'muster' in choice:
        plan['powers'] = [declaration(seat, number, 'MusterTheFaithful', dict(lane=choice['muster']))]
        if choice['breath'] != 'hold':
            plan['powers'].append(declaration(seat, number, 'BreathOfLife', dict(lane=choice['breath']), index=1))
    else:
        plan['powers'] = [declaration(seat, number, 'Rout', dict(lane='Castle'))] if choice['rout'] else []
        castle = next(r for r in view['board'] if r['kind'] == 'castle' and r['owner'] == seat
                      and r['attributes']['castle_type'] == choice['work'])
        plan['order']['castle_action']['target_id'] = castle['id']
    return plan


def board_summary(match):
    world = match._state['world']
    entities = world['entities']['entities']
    result = dict(round=match.clock.round, next_hook=match.clock.hook, players=copy_data(world['players']), lanes=[])
    for seat in (0, 1):
        for lane in ('Lord', 'Castle'):
            rows = [r for r in entities if r['kind'] == 'marcher' and r['owner'] == seat
                    and r['attributes']['lane'] == lane and r['attributes']['hp'] > 0]
            result['lanes'].append(dict(seat=seat, lane=lane, bodies=len(rows),
                hp=sum(r['attributes']['hp'] for r in rows),
                units=[dict(id=r['id'], **{k:r['attributes'][k] for k in ('hp', 'max_hp', 'x_fp', 'y_fp')}) for r in rows]))
    result['castles'] = [copy_data(r) for r in entities if r['kind'] == 'castle']
    return result


def run_one(spec, manifest, source, output):
    start = time.perf_counter()
    record = dict(spec=spec, manifest_sha256=fingerprint(manifest), status='failed', error=None)
    try:
        original = json.load(gzip.open(Path(source)/'games'/(spec['source']+'.json.gz'), 'rt'))
        game = PowerMatch(original['spec']['setup'])
        seat = spec['seat']; operations = []; checkpoints = []
        expected = next(t['view'] for t in original['trace'] if t['view']['player_id'] == seat
                        and t['view']['round'] == spec['round'])
        # Replay the exact shared prefix and preserve the opposing sealed plan.
        for op in original['operations']:
            if op['kind'] == 'submit' and game.clock.round == spec['round']:
                if observe(game, seat) != expected: raise ValueError('Intervention view differs from saved evidence')
                replacement = intervene(op['plans'][seat], expected, spec['choice'])
                is_control = replacement == op['plans'][seat]
                record.update(view_sha256=fingerprint(expected), prefix_sha256=fingerprint(operations),
                              original_plan=op['plans'][seat], intervention=replacement, control=is_control)
                op = copy_data(op); op['plans'][seat] = replacement
                result = game.apply(op)
                if result['action'] == 'invalid': raise ValueError(result)
                operations.append(op)
                break
            result = game.apply(op)
            if result['action'] == 'invalid': raise ValueError(result)
            operations.append(op)
        else: raise ValueError('Intervention submission not found')
        policies = [None, None]
        policies[seat] = load_policy(Path(output)/'v11', 'u13_ablation_v11', manifest['weights'])
        policies[1-seat] = load_policy(Path(output)/'v10', 'u13_ablation_v10', manifest['weights'])
        while game.outcome()['winner'] == -1:
            if game.clock.round > 40: raise ValueError('Round cap reached')
            number, hook = game.clock.round, game.clock.hook
            if hook == 'submission_lock' and game._state['submissions'] == [None, None]:
                decisions = [policies[p].decide(observe(game, p), Preview(game, p)) for p in (0, 1)]
                if any(d['rejected_previews'] for d in decisions): raise ValueError('Rejected policy preview')
                op = dict(kind='submit', plans=[d['plan'] for d in decisions])
            elif hook == 'present_public_state' and game._state['world']['data']['game_economy']['stockpile_pending']:
                p = game._state['world']['data']['game_economy']['stockpile_pending']['player_id']
                op = policies[p].choose_card(observe(game, p), 'stockpile')['operation']
            elif hook == 'present_public_state' and game._state['world']['data']['game_market']['seat'] != 2:
                p = game._state['world']['data']['game_market']['seat']
                op = policies[p].choose_card(observe(game, p), 'slaver')['operation']
            else: op = full_match_inputs.next_operation(game)
            result = game.apply(op)
            if result['action'] == 'invalid': raise ValueError(result)
            operations.append(op)
            if (op['kind'] == 'step' and number <= spec['round']+1
                    and hook in ('post_resolution_movement_state', 'marching', 'round_start_automatic')):
                checkpoints.append(dict(completed_hook=hook, board=board_summary(game)))
        final, stream = digest(game), fingerprint(operations)
        if is_control and (final != original['semantic']['final_state_sha256'] or stream != fingerprint(original['operations'])):
            raise ValueError('Original-choice continuation did not reproduce saved game')
        record.update(status='complete', outcome=game.outcome(), won=game.outcome()['winner'] == seat,
            operations=operations, operations_sha256=stream, final_state_sha256=final, checkpoints=checkpoints,
            breath_pulses=[r['event']['data'] for r in game._state['events']['rows'] if r['event']['type'] == 'BREATH_PULSED'])
    except Exception:
        record['error'] = traceback.format_exc()
    record['wall_seconds'] = time.perf_counter()-start
    atomic_json(Path(output)/'games'/(spec['name']+'.json.gz'), record, compressed=True)
    return {k:record[k] for k in ('spec', 'status', 'error', 'outcome', 'won', 'control', 'wall_seconds') if k in record}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=8)
    args = parser.parse_args()
    (args.output/'games').mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[2]
    source_manifest = json.loads((args.source/'manifest.json').read_text())
    revision, engine = source_identity(root)
    if engine != source_manifest['engine_source_sha256']: raise ValueError('Source engine differs')
    cases = list(specs())
    manifest = dict(schema='U13_SUPPORT_CHOICE_ABLATION_V1', source_revision=revision,
        engine_source_sha256=engine, runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        original_manifest_sha256=fingerprint(source_manifest), weights=source_manifest['weights'],
        frozen_v11=freeze_baseline(root, V11, args.output/'v11'),
        frozen_v10=freeze_baseline(root, V10, args.output/'v10'), cases=cases,
        source_records={s['source']:hashlib.sha256((args.source/'games'/(s['source']+'.json.gz')).read_bytes()).hexdigest() for s in cases},
        scope='Selected loss and win examples; one submission intervention, fixed opponent submission, original policies thereafter; diagnostic, not strength evidence.')
    manifest_path = args.output/'manifest.json'
    if manifest_path.exists() and json.loads(manifest_path.read_text()) != manifest: raise ValueError('Different replay identity')
    atomic_json(manifest_path, manifest)
    results, pending = [], []
    for spec in cases:
        path = args.output/'games'/(spec['name']+'.json.gz')
        if path.exists():
            row = json.load(gzip.open(path, 'rt'))
            if row['manifest_sha256'] != fingerprint(manifest) or row['spec'] != spec: raise ValueError('Different cached record')
            results.append({k:row[k] for k in ('spec', 'status', 'error', 'outcome', 'won', 'control', 'wall_seconds') if k in row})
        else: pending.append(spec)
    print(f'REPLAY {len(cases)} continuations; {len(results)} cached', flush=True)
    with ProcessPoolExecutor(max_workers=args.workers, mp_context=multiprocessing.get_context('spawn')) as pool:
        tasks = [pool.submit(run_one, s, manifest, str(args.source), str(args.output)) for s in pending]
        for task in as_completed(tasks):
            row = task.result(); results.append(row)
            print(json.dumps(row, sort_keys=True), flush=True)
    if source_identity(root)[1] != engine: raise ValueError('Engine changed during continuations')
    report = dict(manifest=manifest, results=sorted(results, key=lambda r:r['spec']['name']))
    atomic_json(args.output/'summary.json', report)
    return int(any(r['status'] != 'complete' for r in results))


if __name__ == '__main__': raise SystemExit(main())
