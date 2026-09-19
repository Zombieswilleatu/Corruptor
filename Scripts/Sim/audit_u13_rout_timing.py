#!/usr/bin/env python3
"""Fixed current-rule Rout diagnostics, with one-submission interventions.

Collect nine V12 games, select up to six held and six fired examples without
looking at outcomes, then compare hold/cast with identical ordinary orders.
The original policies respond normally after that one changed submission.
"""
import argparse
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import asdict
import gzip
import json
import multiprocessing
from pathlib import Path
import time
import traceback

from u13_doctrine.common import Weights
from u13_doctrine.comparison import freeze_baseline, load_baseline
from u13_doctrine.coordination import context
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.facts import Facts, LANES
from u13_doctrine.lane_support import mobile
from u13_doctrine.lords.deimos import rout_value
from u13_doctrine.observation import observe, Preview
from u13_doctrine.planner_probe import run_case
from u13_doctrine.survey import atomic_json, cases, read_record
from u13_pysim import full_match_inputs
from u13_pysim.benchmark_full_match import digest
from u13_pysim.copying import copy_data
from u13_pysim.power_match import PowerMatch
from u13_pysim.power_rules import declaration
from u13_pysim.verify import source_identity

BASELINE = '2cf3bbb0f8405f8ff82f2c2e14abf6a8da15b2d9'
NAMESPACE = 'u13-rout-current-rule-diagnostics-2026-09-19'
OPPONENTS = {'Deimos', 'Gremory', 'Humbaba', 'Kalligan', 'Valak'}


class Policy:
    def __init__(self, directory, weights):
        module = load_baseline(Path(directory)/'policy')
        self.policy = module.CommonSmartCore(module.Weights(**weights))
        self.trace = []

    def decide(self, view, preview):
        decision = self.policy.decide(view, preview)
        if decision['rejected_previews']:
            raise ValueError('Rejected policy preview')
        self.trace.append(dict(view=view, decision=decision))
        return decision

    def choose_card(self, view, category):
        return self.policy.choose_card(view, category)


def load(path):
    with gzip.open(path, 'rt', encoding='utf-8') as stream:
        return json.load(stream)


def collect_one(spec, manifest, output):
    start = time.perf_counter()
    policy = Policy(output, manifest['weights'])
    row = dict(spec=spec, manifest_sha256=fingerprint(manifest), status='failed', error=None)
    try:
        semantic, timing, operations = run_case(spec, policy)
        row.update(status='complete', semantic=semantic, semantic_sha256=fingerprint(semantic),
                   timing=timing, operations=operations)
    except Exception:
        row.update(error=traceback.format_exc(), semantic={}, semantic_sha256=fingerprint({}),
                   timing={}, operations=[])
    row.update(trace=policy.trace, trace_sha256=fingerprint(policy.trace), wall_seconds=time.perf_counter()-start)
    atomic_json(Path(output)/'games'/(spec['name']+'.json.gz'), row, compressed=True)
    return dict(name=spec['name'], status=row['status'], error=row['error'], seconds=row['wall_seconds'])


def positions(records):
    pools = dict(held=[], fired=[])
    for record in records:
        found = dict(held=None, fired=None)
        for item in record['trace']:
            view, decision = item['view'], item['decision']
            f = Facts(view)
            if f.kind != 'Deimos' or not f.available('Rout')[0]:
                continue
            values = {lane:rout_value(f, lane) for lane in LANES}
            rout = next((p for p in decision['plan']['powers'] if p['power_id']=='Rout'), None)
            group = 'fired' if rout else 'held'
            if found[group] is not None:
                continue
            if rout:
                lane = rout['target']['lane']
            else:
                lanes = [lane for lane in LANES if values[lane]['threats'] or values[lane]['distant']]
                if not lanes:
                    continue
                lane = min(lanes, key=lambda k:(-values[k]['score'], -len(values[k]['distant']), k))
            found[group] = dict(source=record['spec']['name'], seat=f.pid, round=view['round'],
                lane=lane, original=group, public_values=values,
                view_sha256=fingerprint(view), plan_sha256=fingerprint(decision['plan']))
        for group, spec in found.items():
            if spec:
                pools[group].append(spec)
    selected = []
    for group, choices in pools.items():
        choices.sort(key=lambda s:fingerprint([s['source'], s['seat'], s['round']]))
        for spec in choices[:6]:
            spec = dict(spec)
            spec['name'] = f"{spec['source']}__r{spec['round']}_p{spec['seat']}"
            selected.append(spec)
    return selected, pools


def intervention(plan, view, lane, cast):
    changed = copy_data(plan)
    original = next((p for p in plan['powers'] if p['power_id']=='Rout'), None)
    if cast and original and original['target']['lane']==lane:
        return changed
    changed['powers'] = [p for p in changed['powers'] if p['power_id']!='Rout']
    if cast:
        occupied = {p['queue_index'] for p in changed['powers']}
        index = next(i for i in range(len(occupied)+1) if i not in occupied)
        changed['powers'].append(declaration(view['player_id'], view['round'], 'Rout', dict(lane=lane), index=index))
        changed['powers'].sort(key=lambda p:p['queue_index'])
    # A submission requires contiguous queue indices and matching declaration
    # identities. Removing Rout before War Machine must resequence that one
    # identity without changing the remaining power's target or parameters.
    for index, slot in enumerate(changed['powers']):
        identity = declaration(view['player_id'], view['round'], slot['power_id'], index=index)
        slot.update(queue_index=index,declaration_id=identity['declaration_id'])
    return changed


def pressure_positions(records):
    """Separate outnumbered-lane diagnostic; no claim that every answer is exhausted.

    Take the largest visible mobile-enemy HP surplus per source/seat in rounds
    4--15 where V12 casts Rout, then the six largest of those surpluses. Require
    at least four mobile enemies and reachable pressure. Final outcomes never
    enter selection. Record planned reinforcements, without equating HP or body
    counts to fighting strength or assuming the unchosen hand has no answer.
    """
    pool = []
    for record in records:
        for item in record['trace']:
            view, decision = item['view'], item['decision']
            f = Facts(view)
            if f.kind != 'Deimos' or not 4 <= view['round'] <= 15 or not f.available('Rout')[0]:
                continue
            rout = next((p for p in decision['plan']['powers'] if p['power_id']=='Rout'), None)
            if not rout:
                continue
            lane = rout['target']['lane']; value = rout_value(f, lane)
            enemies = [r for r in f.units(f.enemy,lane)
                       if mobile(r['attributes']) and not r['attributes'].get('hidden',False)]
            allies = f.units(f.pid,lane)
            enemy_hp = sum(r['attributes']['hp'] for r in enemies)
            own_hp = sum(r['attributes']['hp'] for r in allies)
            if len(enemies)<4 or not value['threats'] or enemy_hp<=own_hp:
                continue
            spec = dict(source=record['spec']['name'],seat=f.pid,round=view['round'],lane=lane,
                original='fired',public_values={k:rout_value(f,k) for k in LANES},
                view_sha256=fingerprint(view),plan_sha256=fingerprint(decision['plan']),
                pressure=dict(enemy_bodies=len(enemies),own_bodies=len(allies),enemy_hp=enemy_hp,
                    own_hp=own_hp,hp_surplus=enemy_hp-own_hp,planned=context(f,decision['plan'])))
            spec['name'] = f"{spec['source']}__pressure_r{spec['round']}_p{spec['seat']}"
            pool.append(spec)
    pool.sort(key=lambda s:(-s['pressure']['hp_surplus'],fingerprint([s['source'],s['seat'],s['round']])))
    selected,seen = [],set()
    for spec in pool:
        key = spec['source'],spec['seat']
        if key in seen:
            continue
        seen.add(key);selected.append(spec)
        if len(selected)==6:
            break
    return selected,pool


def snapshot(game):
    world = game._state['world']
    units = [dict(id=r['id'], owner=r['owner'], **{k:r['attributes'].get(k) for k in
        ('lane','hp','armor','x_fp','y_fp','suit','monster_id','waiting','rout_round')})
        for r in world['entities']['entities'] if r['kind']=='marcher']
    castles = [dict(id=r['id'], owner=r['owner'], integrity=r['attributes']['integrity'])
               for r in world['entities']['entities'] if r['kind']=='castle']
    return dict(round=game.clock.round, next_hook=game.clock.hook, units=units, castles=castles,
                players=copy_data(world['players']))


def continue_one(spec, manifest, output):
    start = time.perf_counter()
    row = dict(spec=spec, manifest_sha256=fingerprint(manifest), status='failed', error=None)
    try:
        original = load(Path(output)/'games'/(spec['source']+'.json.gz'))
        game = PowerMatch(original['spec']['setup'])
        operations, checkpoints, measured = [], [], []
        seat, number = spec['seat'], spec['round']
        expected = next(t for t in original['trace'] if t['view']['player_id']==seat and t['view']['round']==number)
        for op in original['operations']:
            if op['kind']=='submit' and game.clock.round==number:
                view = observe(game, seat)
                if fingerprint(view)!=spec['view_sha256'] or view!=expected['view']:
                    raise ValueError('Recorded intervention view does not replay')
                replacement = intervention(op['plans'][seat], view, spec['lane'], spec['cast'])
                control = replacement==op['plans'][seat]
                if replacement['order']!=op['plans'][seat]['order']:
                    raise ValueError('Ordinary order changed')
                changed = copy_data(op); changed['plans'][seat] = replacement
                row.update(control=control, prefix_sha256=fingerprint(operations),
                    original_plan=op['plans'][seat], intervention=replacement,
                    opponent_plan_sha256=fingerprint(op['plans'][1-seat]))
                cursor = len(game._state['events']['rows'])
                result = game.apply(changed)
                if result['action']=='invalid': raise ValueError(result)
                operations.append(changed)
                break
            result = game.apply(op)
            if result['action']=='invalid': raise ValueError(result)
            operations.append(op)
        else:
            raise ValueError('Intervention round absent')
        policy = Policy(output, manifest['weights'])
        while game.outcome()['winner']==-1:
            if game.clock.round>40: raise ValueError('Round cap reached')
            current, hook = game.clock.round, game.clock.hook
            if hook=='submission_lock' and game._state['submissions']==[None,None]:
                op = dict(kind='submit', plans=[policy.decide(observe(game,p),Preview(game,p))['plan'] for p in (0,1)])
            elif hook=='present_public_state' and game._state['world']['data']['game_economy']['stockpile_pending']:
                p = game._state['world']['data']['game_economy']['stockpile_pending']['player_id']
                op = policy.choose_card(observe(game,p),'stockpile')['operation']
            elif hook=='present_public_state' and game._state['world']['data']['game_market']['seat']!=2:
                p = game._state['world']['data']['game_market']['seat']
                op = policy.choose_card(observe(game,p),'slaver')['operation']
            else:
                op = full_match_inputs.next_operation(game)
            result = game.apply(op)
            if result['action']=='invalid': raise ValueError(result)
            operations.append(op)
            events = game._state['events']['rows']
            if current<=number+2:
                measured.extend(copy_data(r['event']) for r in events[cursor:])
                if op['kind']=='step' and hook in ('post_resolution_movement_state','marching'):
                    checkpoints.append(dict(completed_hook=hook, board=snapshot(game)))
            cursor = len(events)
        final = digest(game)
        if control and (operations!=original['operations'] or final!=original['semantic']['final_state_sha256']):
            raise ValueError('Unchanged control did not reproduce original game')
        row.update(status='complete', outcome=game.outcome(), won=game.outcome()['winner']==seat,
            operations=operations, operations_sha256=fingerprint(operations), final_state_sha256=final,
            checkpoints=checkpoints, measured_events=measured, trace=policy.trace,
            trace_sha256=fingerprint(policy.trace))
    except Exception:
        row['error'] = traceback.format_exc()
    row['wall_seconds'] = time.perf_counter()-start
    atomic_json(Path(output)/'continuations'/(spec['name']+('__cast' if spec['cast'] else '__hold')+'.json.gz'),row,compressed=True)
    return {k:row[k] for k in ('spec','status','error','control','outcome','won','wall_seconds') if k in row}


def run_pool(function, specs, manifest, output, workers):
    results = []
    with ProcessPoolExecutor(max_workers=workers, mp_context=multiprocessing.get_context('spawn')) as pool:
        futures = [pool.submit(function,s,manifest,str(output)) for s in specs]
        for future in as_completed(futures):
            row = future.result(); results.append(row)
            print(json.dumps(row,sort_keys=True),flush=True)
    if any(r['status']!='complete' for r in results):
        raise ValueError('At least one diagnostic game failed')
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=('collect','replay','pressure'))
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--workers',type=int,default=4)
    parser.add_argument('--resume',action='store_true',help='Reuse complete continuations with matching manifest and position; rerun only absent/failed records')
    args = parser.parse_args()
    if args.workers<1: parser.error('Workers must be positive')
    root = Path(__file__).resolve().parents[2]
    for name in ('games','continuations'):
        (args.output/name).mkdir(parents=True,exist_ok=True)
    revision, engine = source_identity(root)
    if args.phase=='collect':
        specs = [s for s in cases(1,NAMESPACE) if 'Deimos' in s['setup']['lords']
                 and set(s['setup']['lords'])<=OPPONENTS]
        assert len(specs)==9
        manifest = dict(schema='U13_ROUT_TIMING_DIAGNOSTICS_V1',source_revision=revision,
            engine_source_sha256=engine,weights=asdict(Weights()),namespace=NAMESPACE,
            policy=freeze_baseline(root,BASELINE,args.output/'policy'),specs=specs,
            selection='Earliest eligible held and fired Rout per game; choose at most six of each by stable source/seat/round hash, without outcomes.',
            scope='Diagnostic single-submission interventions; fixed ordinary and opposing orders at intervention, frozen V12 thereafter. Not a policy strength comparison.')
        if (args.output/'manifest.json').exists(): raise ValueError('Use a fresh collection directory')
        atomic_json(args.output/'manifest.json',manifest)
        run_pool(collect_one,specs,manifest,args.output,args.workers)
        records = [read_record(args.output/'games'/(s['name']+'.json.gz'),manifest,s) for s in specs]
        selected,pools = positions(records)
        atomic_json(args.output/'positions.json',dict(selected=selected,eligible=pools))
        print(f'COLLECTED {len(records)} complete games; selected {len(selected)} positions',flush=True)
    else:
        manifest = json.loads((args.output/'manifest.json').read_text())
        if engine!=manifest['engine_source_sha256']: raise ValueError('Different engine')
        if args.phase=='pressure':
            records = [read_record(args.output/'games'/(s['name']+'.json.gz'),manifest,s) for s in manifest['specs']]
            selected,pool = pressure_positions(records)
            atomic_json(args.output/'positions-pressure.json',dict(selected=selected,eligible=pool,
                selection=pressure_positions.__doc__,parent_manifest_sha256=fingerprint(manifest)))
        else:
            selected = json.loads((args.output/'positions.json').read_text())['selected']
        specs = [dict(s,cast=cast) for s in selected for cast in (False,True)]
        results,pending = [],[]
        for spec in specs:
            path = args.output/'continuations'/(spec['name']+('__cast' if spec['cast'] else '__hold')+'.json.gz')
            if args.resume and path.exists():
                row = load(path)
                if row['spec']!=spec or row['manifest_sha256']!=fingerprint(manifest):
                    raise ValueError('Existing continuation belongs to a different experiment')
                if row['status']=='complete':
                    results.append({k:row[k] for k in ('spec','status','error','control','outcome','won','wall_seconds')})
                    continue
                # Keep the rejected attempt auditable when correcting a runner.
                failed = args.output/'failed-attempts'/path.name
                failed.parent.mkdir(exist_ok=True)
                if failed.exists():
                    raise ValueError('Failed-attempt archive already exists')
                failed.write_bytes(path.read_bytes())
            pending.append(spec)
        if pending:
            results.extend(run_pool(continue_one,pending,manifest,args.output,args.workers))
        name = 'replay-summary-pressure.json' if args.phase=='pressure' else 'replay-summary.json'
        atomic_json(args.output/name,dict(results=results))
        print(f'REPLAYED {len(results)} continuations; {sum(r["control"] for r in results)} exact controls',flush=True)
    if source_identity(root)[1]!=engine: raise ValueError('Engine changed during diagnostic run')
    return 0


if __name__=='__main__':
    raise SystemExit(main())
