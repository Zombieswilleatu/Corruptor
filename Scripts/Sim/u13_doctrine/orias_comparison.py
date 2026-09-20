"""Focal Orias old/new comparison against a fixed frozen V15 opponent."""
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, wait, FIRST_COMPLETED
from dataclasses import asdict
import hashlib
import json
import multiprocessing
from pathlib import Path
import platform
import shutil
import statistics
import sys
import time
import traceback

from u13_pysim import opening
from u13_pysim.opening import LORDS
from u13_pysim.verify import source_identity
from .common import CommonSmartCore, VERSION, Weights
from .comparison import freeze_baseline, load_baseline
from .diagnostics import fingerprint
from .planner_probe import PlannerObserver, run_case
from .reference_probe import harness_hash
from .survey import LOADOUT, atomic_json, read_record

BASELINE = 'c92181268fae026f30d76d97c2c5b822185848ca'
NAMESPACE = 'u13-orias-v15-v16-2026-09-20'


def cases(repeats=2, namespace=NAMESPACE):
    if type(repeats) is not int or repeats < 1:
        raise ValueError('Positive integer repeats required')
    for opponent in LORDS:
        for repeat in range(repeats):
            seed = f'{namespace}:Orias:{opponent}:{repeat:02d}'
            for seat in (0, 1):
                lords = [opponent, opponent]; lords[seat] = 'Orias'
                pair_id = f'orias_{opponent.lower()}_{repeat:02d}_p{seat}'
                for variant in ('old', 'new'):
                    yield dict(name=pair_id+'__'+variant, pair_id=pair_id,
                        variant=variant, focal_seat=seat, opponent=opponent, repeat=repeat,
                        setup=dict(seed=seed, lords=lords[:], castles=[LOADOUT[:], LOADOUT[:]]))


class FocalPolicy:
    def __init__(self, directory, spec, weights):
        base = load_baseline(directory)
        self.policies = [base.CommonSmartCore(base.Weights(**weights)) for _ in (0, 1)]
        self.policy_ids = [base.VERSION]*2
        if spec['variant'] == 'new':
            self.policies[spec['focal_seat']] = CommonSmartCore(Weights(**weights))
            self.policy_ids[spec['focal_seat']] = VERSION
        self.trace = []

    def decide(self, view, preview):
        decision = self.policies[view['player_id']].decide(view, preview)
        if decision['policy'] != self.policy_ids[view['player_id']]:
            raise ValueError('Wrong policy routed to seat')
        self.trace.append(dict(view=view, decision=decision))
        return decision

    def choose_card(self, view, category):
        result = self.policies[view['player_id']].choose_card(view, category)
        return result


class OriasObserver(PlannerObserver):
    """Passive event facts; never gives hidden information back to the policy."""
    def __init__(self, spec, policy_ids):
        super().__init__(spec, policy_ids)
        self.focal_seat = spec['focal_seat']
        self.orias_events, self.orias_orders = [], []

    def accepted(self, number, seat, decision):
        super().accepted(number, seat, decision)
        if seat == self.focal_seat:
            self.orias_orders.append(dict(round=number, action=decision['plan']['order'].get('action', 'Pass')))

    def event(self, index, event, current_round):
        super().event(index, event, current_round)
        kind, data = event['type'], event['data']
        if kind in ('WEB_STARTED', 'SNARE_ACTIVE', 'HUNT_RESOLVED', 'SIEGE_RESOLVED', 'COMBAT_ORDER_FIZZLED') and data.get('player_id') == self.focal_seat:
            self.orias_events.append(dict(type=kind, round=data.get('round', current_round), data=data))

    def report(self):
        report = super().report()
        report['orias_observed'] = dict(events=self.orias_events, orders=self.orias_orders)
        return report


def run_one(spec, manifest, directory):
    policy = FocalPolicy(Path(directory)/'baseline', spec, manifest['weights'])
    start = time.perf_counter()
    try:
        semantic, timing, operations = run_case(spec, policy, policy.policy_ids, OriasObserver)
        status, error = 'complete', None
    except Exception:
        semantic, timing, operations = {}, {}, []
        status, error = 'failed', traceback.format_exc()
    record = dict(manifest_sha256=fingerprint(manifest), spec=spec, status=status, error=error,
        semantic=semantic, semantic_sha256=fingerprint(semantic), timing=timing,
        operations=operations, trace=policy.trace, trace_sha256=fingerprint(policy.trace),
        wall_seconds=time.perf_counter()-start)
    atomic_json(Path(directory)/'games'/(spec['name']+'.json.gz'), record, compressed=True)
    return dict(name=spec['name'], status=status, error=error, rounds=semantic.get('rounds'), wall_seconds=record['wall_seconds'])


def metrics(record):
    seat, game = record['spec']['focal_seat'], record['semantic']
    result = Counter(decisions=0, Web_selected=0, Snare_selected=0, web_activation_hits=0,
        web_activations=0, snare_activations=0, snare_followup_selected=0,
        snare_followup_resolved=0, snare_without_followup_decision=0)
    for item in record['trace']:
        if item['view']['player_id'] != seat: continue
        result['decisions'] += 1
        for power in item['decision']['plan']['powers']:
            if power['power_id'] in ('Web', 'Snare'): result[power['power_id']+'_selected'] += 1
    for group in game['diagnostics']['groups']:
        if group['seat'] == seat and group['category'] == 'powers' and group['term'] == 'Web':
            result['web_activation_hits'] += group['metrics'].get('web_hits', 0)
    observed = game['diagnostics']['orias_observed']
    orders = {row['round']: row['action'] for row in observed['orders']}
    for row in observed['events']:
        if row['type'] == 'WEB_STARTED': result['web_activations'] += 1
        if row['type'] != 'SNARE_ACTIVE': continue
        result['snare_activations'] += 1
        n = row['round']
        result['snare_without_followup_decision'] += n not in orders
        result['snare_followup_selected'] += orders.get(n) in ('Hunt', 'Siege')
        result['snare_followup_resolved'] += any(e['round'] == n and e['type'] in ('HUNT_RESOLVED', 'SIEGE_RESOLVED') for e in observed['events'])
    return dict(result)


def aggregate(records):
    games, pairs, groups = [], {}, {}
    totals = {variant: Counter() for variant in ('old', 'new')}
    for record in records:
        spec, game = record['spec'], record['semantic']
        variant = spec['variant']; totals[variant]['requested'] += 1
        row = {k: spec[k] for k in ('name', 'pair_id', 'variant', 'focal_seat', 'opponent', 'repeat')}
        row.update(status=record['status'], error=record['error'], wall_seconds=record['wall_seconds'])
        pair = pairs.setdefault(spec['pair_id'], {})
        if record['status'] == 'complete':
            won = game['outcome']['winner'] == spec['focal_seat']
            pair[variant] = won
            measured = metrics(record)
            row.update(won=won, rounds=game['rounds'], outcome=game['outcome'], metrics=measured,
                rejected_previews=len(game['diagnostics']['rejected_previews']), timing=record['timing'])
            totals[variant].update(dict(completed=1, wins=int(won), rounds=game['rounds']))
            totals[variant].update(measured)
            for key in ('opponent:'+spec['opponent'], 'seat:'+str(spec['focal_seat'])):
                group = groups.setdefault(key, {v: Counter(completed=0, wins=0, rounds=0) for v in ('old', 'new')})
                group[variant].update(dict(completed=1, wins=int(won), rounds=game['rounds']))
        else: totals[variant]['failed'] += 1
        games.append(row)
    paired = Counter(new_only=0, old_only=0, both_win=0, both_lose=0, incomplete=0)
    for pair in pairs.values():
        if set(pair) != {'old', 'new'}: paired['incomplete'] += 1
        elif pair['old'] == pair['new']: paired['both_win' if pair['new'] else 'both_lose'] += 1
        else: paired['new_only' if pair['new'] else 'old_only'] += 1
    for variant, total in totals.items():
        completed = total['completed']
        total['win_rate'] = total['wins']/completed if completed else None
        total['mean_rounds'] = total['rounds']/completed if completed else None
        for power in ('Web', 'Snare'):
            total[power+'_per_decision'] = total[power+'_selected']/total['decisions'] if total['decisions'] else None
            total[power+'_per_game'] = total[power+'_selected']/completed if completed else None
    return dict(requested=len(games), completed=sum(t['completed'] for t in totals.values()),
        failed=sum(t['failed'] for t in totals.values()), paired_results=dict(paired),
        totals=totals, breakdown=groups, games=games,
        limitation='Two seeds per opponent with related seat swaps; preliminary comparison against fixed V15 opponents and ordinary loadout, not general Lord balance. Web slowing time and counterfactual prevented Guard deployments are not measured.')


def checked_record(directory, manifest, spec):
    path = Path(directory)/'games'/(spec['name']+'.json.gz')
    reused = manifest.get('reused_completed_records', {}).get(spec['name'])
    if reused:
        if hashlib.sha256(path.read_bytes()).hexdigest() != reused:
            raise ValueError('Reused record bytes changed')
        return read_record(path, manifest['original_manifest'], spec)
    return read_record(path, manifest, spec)


def run(root, directory, workers=6, pilot=False, reuse_completed=None):
    root, directory = Path(root), Path(directory).resolve()
    if workers < 1: raise ValueError('Workers must be positive')
    specs = list(cases())
    (directory/'games').mkdir(parents=True, exist_ok=True)
    frozen = freeze_baseline(root, BASELINE, directory/'baseline')
    base = load_baseline(directory/'baseline')
    revision, engine = source_identity(root)
    paths = sorted((root/'Scripts/Sim/u13_doctrine').rglob('*.py'))
    hashes = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes().replace(b'\r\n', b'\n')).hexdigest() for p in paths}
    manifest = dict(schema='U13_ORIAS_FOCAL_COMPARISON_V1', source_revision=revision,
        source_tree=__import__('subprocess').check_output(['git', '-C', str(root), 'rev-parse', 'HEAD^{tree}'], text=True).strip(),
        engine_source_sha256=engine, harness_source_sha256=harness_hash(root),
        runner_sha256=hashlib.sha256((root/'Scripts/Sim/run_u13_orias_comparison.py').read_bytes()).hexdigest(),
        candidate_source_hashes=hashes, candidate_package_sha256=fingerprint(hashes),
        opening_policy=opening.ECONOMY, baseline=frozen, candidate_policy=VERSION,
        baseline_policy=base.VERSION, opponent_policy=base.VERSION, weights=asdict(Weights()),
        namespace=NAMESPACE, planned_games=len(specs), round_cap=40, cases=specs,
        implementation=platform.python_implementation(), python=sys.version,
        scope='Only focal Orias changes policy; engine and opponents fixed. All 72 cases declared before pilot. Failed/censored games remain explicit.')
    if reuse_completed:
        previous = Path(reuse_completed).resolve()
        original = json.loads((previous/'manifest.json').read_text())
        for key in ('source_revision', 'source_tree', 'engine_source_sha256', 'opening_policy',
                    'baseline', 'candidate_policy', 'baseline_policy', 'opponent_policy',
                    'weights', 'namespace', 'planned_games', 'round_cap', 'cases', 'implementation', 'python'):
            if manifest[key] != original[key]: raise ValueError('Cannot reuse changed experiment: '+key)
        exempt = {'Scripts/Sim/u13_doctrine/orias_comparison.py',
                  'Scripts/Sim/u13_doctrine/test_orias_comparison.py'}
        if {k:v for k,v in hashes.items() if k not in exempt} != {
                k:v for k,v in original['candidate_source_hashes'].items() if k not in exempt}:
            raise ValueError('Cannot reuse changed policy or simulation driver')
        reused = {}
        for spec in specs:
            source = previous/'games'/(spec['name']+'.json.gz')
            if not source.exists(): continue
            record = read_record(source, original, spec)
            if record['status'] != 'complete': continue
            # The correction only affects focal observations lacking action.
            # Every reused game must prove that branch was never encountered.
            if any('action' not in t['decision']['plan']['order'] for t in record['trace']
                   if t['view']['player_id'] == spec['focal_seat']):
                raise ValueError('Completed record unexpectedly encountered missing action')
            target = directory/'games'/source.name
            if target.exists() and target.read_bytes() != source.read_bytes():
                raise ValueError('Conflicting reused record')
            if not target.exists(): shutil.copyfile(source, target)
            reused[spec['name']] = hashlib.sha256(source.read_bytes()).hexdigest()
        manifest.update(original_manifest=original, reused_completed_records=reused,
            observer_correction='Missing combat action means Pass. Original completed records retained byte-for-byte with original manifest and hashes; failed observer record excluded from outcomes and rerun with identical setup. No policies, scoring, driver or authority changed.')
    path = directory/'manifest.json'
    if path.exists() and json.loads(path.read_text()) != manifest:
        raise ValueError('Different comparison identity; sources must stay pinned')
    atomic_json(path, manifest)
    selected = specs[:2] if pilot else specs
    pending = []
    for spec in selected:
        path = directory/'games'/(spec['name']+'.json.gz')
        if path.exists(): checked_record(directory, manifest, spec)
        else: pending.append(spec)
    start, done = time.perf_counter(), len(selected)-len(pending)
    print(f'ORIAS {len(selected)} games this invocation / {len(specs)} declared; {done} cached; {workers} workers', flush=True)
    with ProcessPoolExecutor(max_workers=workers, mp_context=multiprocessing.get_context('spawn')) as pool:
        tasks = {pool.submit(run_one, spec, manifest, str(directory)) for spec in pending}
        while tasks:
            finished, tasks = wait(tasks, timeout=15, return_when=FIRST_COMPLETED)
            for task in finished:
                result = task.result(); done += 1
                print(f"{result['status'].upper()} {done}/{len(selected)} {result['name']} rounds={result['rounds']} wall={result['wall_seconds']:.1f}s elapsed={time.perf_counter()-start:.1f}s", flush=True)
                if result['error']: print(result['error'], flush=True)
            if not finished: print(f'RUNNING {done}/{len(selected)} elapsed={time.perf_counter()-start:.1f}s', flush=True)
    if source_identity(root)[1] != engine or harness_hash(root) != manifest['harness_source_sha256']:
        raise ValueError('Sources changed during comparison')
    summary = aggregate(checked_record(directory, manifest, s) for s in selected)
    report = dict(manifest=manifest, summary=summary, summary_sha256=fingerprint(summary), elapsed_seconds=time.perf_counter()-start)
    atomic_json(directory/('pilot-summary.json' if pilot else 'summary.json'), report)
    print(f"ORIAS COMPLETE {summary['completed']}/{len(selected)} failures={summary['failed']} pairs={summary['paired_results']}", flush=True)
    return report
