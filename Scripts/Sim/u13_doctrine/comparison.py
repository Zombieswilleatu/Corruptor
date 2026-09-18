"""Matched policy comparison on one shared engine; no rules or balance tuning."""
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, wait, FIRST_COMPLETED
from dataclasses import asdict
import hashlib
import importlib
import importlib.util
import io
import json
import multiprocessing
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tarfile
import time
import traceback

from u13_pysim import opening
from u13_pysim.verify import source_identity
from .common import CommonSmartCore, VERSION, Weights
from .diagnostics import fingerprint
from .planner_probe import run_case
from .reference_probe import harness_hash
from .survey import atomic_json, cases, read_record
from u13_pysim.opening import LORDS

SCHEMA = 'U13_MATCHED_DOCTRINE_COMPARISON_V1'
BASELINE = 'a58b0fc2dbb1dabbec53d8f4d9bc534962a99f52'


def paired_cases(repeats, namespace, lord=None):
    if lord is not None and lord not in LORDS: raise ValueError('Unknown focused Lord')
    for case in cases(repeats, namespace):
        if lord is not None and lord not in case['setup']['lords']: continue
        for seat in (0, 1):
            yield dict(case, name=case['name']+'__candidate_p'+str(seat), pair_id=case['name'], candidate_seat=seat)


def freeze_baseline(root, revision, directory):
    """Freeze the whole old policy package, keeping it separate from authority."""
    root, directory = Path(root), Path(directory)
    revision = subprocess.check_output(['git', '-C', str(root), 'rev-parse', '--verify', revision+'^{commit}'], text=True).strip()
    prefix = 'Scripts/Sim/u13_doctrine/'
    archive = subprocess.check_output(['git', '-C', str(root), 'archive', revision, prefix])
    files = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for member in tar.getmembers():
            if not member.isfile() or not member.name.startswith(prefix) or not member.name.endswith('.py'): continue
            name = member.name[len(prefix):]
            if '..' in Path(name).parts: raise ValueError('Invalid baseline path')
            files[name] = tar.extractfile(member).read().replace(b'\r\n', b'\n')
    if not {'__init__.py', 'common.py'} <= files.keys(): raise ValueError('Baseline has no common policy')
    found = {p.relative_to(directory).as_posix() for p in directory.rglob('*.py')} if directory.exists() else set()
    if found and found != files.keys(): raise ValueError('Different frozen baseline file set')
    for name, data in files.items():
        path = directory/name
        if path.exists() and path.read_bytes() != data: raise ValueError('Modified frozen baseline: '+name)
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists(): path.write_bytes(data)
    hashes = {name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}
    return dict(revision=revision, files=hashes, package_sha256=fingerprint(hashes))


def load_baseline(directory):
    directory = Path(directory).resolve()
    name = 'u13_frozen_baseline_doctrine'
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, directory/'__init__.py', submodule_search_locations=[str(directory)])
        module = importlib.util.module_from_spec(spec); sys.modules[name] = module
        spec.loader.exec_module(module)
    elif Path(sys.modules[name].__file__).resolve().parent != directory:
        raise ValueError('One frozen baseline per process is required')
    return importlib.import_module(name+'.common')


class MatchedPolicy:
    def __init__(self, baseline_directory, candidate_seat, weights):
        base = load_baseline(baseline_directory)
        self.policies = [None, None]
        self.policies[candidate_seat] = CommonSmartCore(Weights(**weights))
        self.policies[1-candidate_seat] = base.CommonSmartCore(base.Weights(**weights))
        self.policy_ids = [VERSION if p == candidate_seat else base.VERSION for p in (0, 1)]
        self.trace = []

    def decide(self, view, preview):
        decision = self.policies[view['player_id']].decide(view, preview)
        if decision['policy'] != self.policy_ids[view['player_id']]: raise ValueError('Wrong policy in seat')
        self.trace.append(dict(view=view, decision=decision))
        return decision

    def choose_card(self, view, category):
        return self.policies[view['player_id']].choose_card(view, category)


def run_one(spec, manifest, directory):
    policy = MatchedPolicy(Path(directory)/'baseline', spec['candidate_seat'], manifest['weights'])
    start = time.perf_counter()
    try:
        semantic, timing, operations = run_case(spec, policy, policy.policy_ids)
        status, error = 'complete', None
    except Exception:
        semantic, timing, operations = {}, {}, []
        status, error = 'failed', traceback.format_exc()
    record = dict(manifest_sha256=fingerprint(manifest), spec=spec, status=status, error=error,
        semantic=semantic, semantic_sha256=fingerprint(semantic), timing=timing,
        operations=operations, trace=policy.trace, trace_sha256=fingerprint(policy.trace),
        wall_seconds=time.perf_counter()-start)
    atomic_json(Path(directory)/'games'/(spec['name']+'.json.gz'), record, compressed=True)
    return dict(name=spec['name'], status=status, error=error, rounds=semantic.get('rounds'))


def aggregate(records, candidate_id):
    games, rounds, pairs = [], [], {}
    wins, routes, terms, maximum = Counter(), Counter(), {}, {}
    decisions, timing = Counter(), Counter()
    for record in records:
        spec, semantic = record['spec'], record['semantic']
        row = dict(name=spec['name'], candidate_seat=spec['candidate_seat'], lords=spec['setup']['lords'],
                   status=record['status'], error=record['error'])
        pair = pairs.setdefault(spec['pair_id'], [None, None])
        if record['status'] != 'complete': games.append(row); continue
        won = semantic['outcome']['winner'] == spec['candidate_seat']
        wins['candidate' if won else 'baseline'] += 1
        pair[spec['candidate_seat']] = won
        rounds.append(semantic['rounds']); routes[semantic['outcome']['win_by']] += 1
        row.update(candidate_won=won, rounds=semantic['rounds'], outcome=semantic['outcome'],
                   rejected_previews=len(semantic['diagnostics']['rejected_previews']))
        games.append(row)
        timing['decision_ms'] += record['timing']['decision_ms']
        timing['simulation_ms'] += record['timing']['simulation_ms']
        for item in record['trace']:
            decision = item['decision']; policy = decision['policy']
            decisions[policy] += 1
            budget = maximum.setdefault(policy, {})
            for key, count in decision['budget']['used'].items(): budget[key] = max(budget.get(key, 0), count)
            stats = decision.get('rite_plans', {})
            for term in ('Supplicants', 'Invocation', 'ProfaneRuins'):
                key = (policy, term)
                result = terms.setdefault(key, dict(policy=policy, term=term, generated=0, retained=0, selected=0,
                    scored_measured_decisions=0, scored_plans=None, current_board_wins=None, current_board_losses=None,
                    resolved=0, personal_tears=0, outcomes_unobserved=0))
                assessment = next(a for a in decision['assessments'] if a['category'] == 'rites' and a['term'] == term)
                for count in ('generated', 'retained', 'selected'): result[count] += assessment[count]
                if term in stats:
                    result['scored_measured_decisions'] += 1
                    for count in ('scored_plans', 'current_board_wins', 'current_board_losses'):
                        result[count] = (result[count] or 0)+stats[term][count]
        for group in semantic['diagnostics']['groups']:
            if group['category'] != 'rites': continue
            result = terms[(group['policy_id'], group['term'])]
            result['resolved'] += group['outcomes'].get('resolved', 0)
            result['personal_tears'] += group['metrics'].get('personal_tears', 0)
            result['outcomes_unobserved'] += group['outcome_unobserved']
    complete = [g for g in games if g['status'] == 'complete']
    return dict(requested=len(games), completed=len(complete), failed=len(games)-len(complete), games=games,
        candidate_policy=candidate_id, wins=wins, victory_routes=routes,
        paired_results=dict(candidate_wins_both=sum(v == [True, True] for v in pairs.values()),
            split=sum(None not in v and v[0] != v[1] for v in pairs.values()),
            baseline_wins_both=sum(v == [False, False] for v in pairs.values()),
            incomplete=sum(None in v for v in pairs.values())),
        rounds=sum(rounds), mean_rounds=statistics.mean(rounds) if rounds else None,
        rejected_previews=sum(g['rejected_previews'] for g in complete),
        decisions=decisions, rite_measurements=[terms[k] for k in sorted(terms)], maximum_work=maximum,
        total_decision_ms=timing['decision_ms'], total_simulation_ms=timing['simulation_ms'])


def run(root, directory, repeats=1, workers=8, namespace='u13-rite-v4-2026-09-18', baseline=BASELINE, lord=None):
    root, directory = Path(root), Path(directory)
    if workers < 1: raise ValueError('Workers must be positive')
    specs = list(paired_cases(repeats, namespace, lord))
    (directory/'games').mkdir(parents=True, exist_ok=True)
    frozen = freeze_baseline(root, baseline, directory/'baseline')
    base = load_baseline(directory/'baseline')
    revision, engine = source_identity(root)
    manifest = dict(schema=SCHEMA, source_revision=revision, engine_source_sha256=engine,
        opening_policy=opening.ECONOMY, harness_source_sha256=harness_hash(root), baseline=frozen,
        candidate_policy=VERSION, baseline_policy=base.VERSION, weights=asdict(Weights()),
        namespace=namespace, repeats=repeats, implementation=platform.python_implementation(), python=sys.version,
        scope='Both policies share current engine, fixed ordinary loadout and seed; swap policy seats for each ordered matchup. Python policy comparison, not native parity or Lord balance.')
    if lord is not None: manifest['focused_lord'] = lord
    path = directory/'manifest.json'
    if path.exists() and json.loads(path.read_text()) != manifest: raise ValueError('Different comparison identity')
    atomic_json(path, manifest)
    pending = []
    for spec in specs:
        path = directory/'games'/(spec['name']+'.json.gz')
        if path.exists(): read_record(path, manifest, spec)
        else: pending.append(spec)
    start, done = time.perf_counter(), len(specs)-len(pending)
    print(f'COMPARISON {len(specs)} games; {done} verified cached; {workers} workers', flush=True)
    with ProcessPoolExecutor(max_workers=workers, mp_context=multiprocessing.get_context('spawn')) as pool:
        tasks = {pool.submit(run_one, spec, manifest, str(directory)) for spec in pending}
        while tasks:
            finished, tasks = wait(tasks, timeout=15, return_when=FIRST_COMPLETED)
            for task in finished:
                result = task.result(); done += 1
                print(f"{result['status'].upper()} {done}/{len(specs)} {result['name']} rounds={result['rounds']} elapsed={time.perf_counter()-start:.1f}s", flush=True)
                if result['error']: print(result['error'], flush=True)
            if not finished: print(f'RUNNING {done}/{len(specs)} elapsed={time.perf_counter()-start:.1f}s', flush=True)
    if source_identity(root)[1] != engine or harness_hash(root) != manifest['harness_source_sha256']:
        raise ValueError('Source changed during comparison')
    summary = aggregate((read_record(directory/'games'/(s['name']+'.json.gz'), manifest, s) for s in specs), VERSION)
    report = dict(manifest=manifest, summary=summary, summary_sha256=fingerprint(summary), elapsed_seconds=time.perf_counter()-start)
    atomic_json(directory/'summary.json', report)
    print(f"COMPARISON COMPLETE {summary['completed']}/{len(specs)}; failures={summary['failed']}; wins={dict(summary['wins'])}; rejected_previews={summary['rejected_previews']}", flush=True)
    return report
