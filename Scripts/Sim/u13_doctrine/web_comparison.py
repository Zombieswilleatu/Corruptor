"""Small Web-only V16/V17 comparison: Snare fixed, opposing policy frozen V15."""
import ast
from concurrent.futures import ProcessPoolExecutor, wait, FIRST_COMPLETED
from dataclasses import asdict
import hashlib
import importlib
import importlib.util
import json
import multiprocessing
from pathlib import Path
import platform
import sys
import time

from u13_pysim import opening
from u13_pysim.verify import source_identity
from .common import CommonSmartCore, VERSION, Weights
from .comparison import freeze_baseline
from .diagnostics import fingerprint
from .orias_comparison import FocalPolicy, aggregate, cases as all_cases, run_one
from .reference_probe import harness_hash
from .survey import atomic_json, read_record

BASELINE = '9659d8fc70466b98f95a47ee8a20bef9416f8570'
OPPONENT = 'c92181268fae026f30d76d97c2c5b822185848ca'
OPPONENTS = ('Gremory', 'Deimos', 'Humbaba', 'Kalligan')
NAMESPACE = 'u13-orias-web-only-v17-2026-09-20'


def cases():
    return [s for s in all_cases(1, NAMESPACE) if s['opponent'] in OPPONENTS]


def load_package(directory):
    directory = Path(directory).resolve()
    name = 'u13_web_frozen_'+hashlib.sha256(str(directory).encode()).hexdigest()[:16]
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, directory/'__init__.py', submodule_search_locations=[str(directory)])
        module = importlib.util.module_from_spec(spec); sys.modules[name] = module
        spec.loader.exec_module(module)
    return importlib.import_module(name+'.common')


class WebPolicy(FocalPolicy):
    def __init__(self, directory, spec, weights):
        base = load_package(directory)
        opponent = load_package(Path(directory).parent/'opponent')
        self.policies = [opponent.CommonSmartCore(opponent.Weights(**weights)) for _ in (0, 1)]
        seat = spec['focal_seat']
        self.policies[seat] = CommonSmartCore(Weights(**weights)) if spec['variant'] == 'new' else base.CommonSmartCore(base.Weights(**weights))
        self.policy_ids = [opponent.VERSION]*2
        self.policy_ids[seat] = VERSION if spec['variant'] == 'new' else base.VERSION
        self.trace = []


def snare_identity(path):
    names = {'_spent_cards', '_snare_cost', '_guard_scenario', 'snare_value'}
    tree = ast.parse(Path(path).read_text())
    found = {node.name: ast.dump(node, include_attributes=False) for node in tree.body
             if isinstance(node, ast.FunctionDef) and node.name in names}
    if set(found) != names: raise ValueError('Missing Snare functions')
    return fingerprint(found)


def run(root, directory, workers=8):
    root, directory = Path(root), Path(directory).resolve()
    if workers < 1: raise ValueError('Workers must be positive')
    (directory/'games').mkdir(parents=True, exist_ok=True)
    baseline = freeze_baseline(root, BASELINE, directory/'baseline')
    opponent = freeze_baseline(root, OPPONENT, directory/'opponent')
    old, foe = load_package(directory/'baseline'), load_package(directory/'opponent')
    snare = snare_identity(root/'Scripts/Sim/u13_doctrine/orias_tactics.py')
    if snare != snare_identity(directory/'baseline/orias_tactics.py'):
        raise ValueError('Snare changed in Web-only experiment')
    revision, engine = source_identity(root)
    specs = cases()
    manifest = dict(schema='U13_ORIAS_WEB_ONLY_V17_V1', source_revision=revision,
        engine_source_sha256=engine, harness_source_sha256=harness_hash(root),
        runner_sha256=hashlib.sha256((root/'Scripts/Sim/run_u13_web_comparison.py').read_bytes()).hexdigest(),
        baseline=baseline, opponent=opponent, baseline_policy=old.VERSION, candidate_policy=VERSION,
        opponent_policy=foe.VERSION, snare_functions_sha256=snare, weights=asdict(Weights()),
        opening_policy=opening.ECONOMY, namespace=NAMESPACE, planned_games=len(specs), cases=specs,
        implementation=platform.python_implementation(), python=sys.version, round_cap=40,
        scope='16 predeclared games: V16 versus Web-only V17, fixed V15 opponents, four diagnostic opponents, one fresh seed each, both seats. Snare functions unchanged. Focused preliminary sample, not general balance.')
    path = directory/'manifest.json'
    if path.exists() and json.loads(path.read_text()) != manifest: raise ValueError('Different campaign identity')
    atomic_json(path, manifest)
    pending = []
    for spec in specs:
        path = directory/'games'/(spec['name']+'.json.gz')
        if path.exists(): read_record(path, manifest, spec)
        else: pending.append(spec)
    start, done = time.perf_counter(), len(specs)-len(pending)
    print(f'WEB ONLY {len(specs)} declared games; {done} cached; {workers} workers', flush=True)
    with ProcessPoolExecutor(max_workers=workers, mp_context=multiprocessing.get_context('spawn')) as pool:
        tasks = {pool.submit(run_one, spec, manifest, str(directory), WebPolicy) for spec in pending}
        while tasks:
            finished, tasks = wait(tasks, timeout=15, return_when=FIRST_COMPLETED)
            for task in finished:
                result = task.result(); done += 1
                print(f"{result['status'].upper()} {done}/{len(specs)} {result['name']} rounds={result['rounds']} wall={result['wall_seconds']:.1f}s elapsed={time.perf_counter()-start:.1f}s", flush=True)
                if result['error']: print(result['error'], flush=True)
            if not finished: print(f'RUNNING {done}/{len(specs)} elapsed={time.perf_counter()-start:.1f}s', flush=True)
    if source_identity(root)[1] != engine or harness_hash(root) != manifest['harness_source_sha256']:
        raise ValueError('Source changed during campaign')
    summary = aggregate(read_record(directory/'games'/(s['name']+'.json.gz'), manifest, s) for s in specs)
    summary['limitation'] = manifest['scope']
    report = dict(manifest=manifest, summary=summary, summary_sha256=fingerprint(summary), elapsed_seconds=time.perf_counter()-start)
    atomic_json(directory/'summary.json', report)
    print(f"WEB COMPLETE {summary['completed']}/{len(specs)} failures={summary['failed']} pairs={summary['paired_results']}", flush=True)
    return report
