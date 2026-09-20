"""Matched old/new/no-Rout experiment with a frozen ordinary opponent."""
from collections import Counter, defaultdict
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import asdict
import math
import multiprocessing
from pathlib import Path
import platform
import sys
import time
import traceback

from u13_pysim.opening import LORDS
from u13_pysim.verify import source_identity
from .common import CommonSmartCore, Weights
from .comparison import freeze_baseline, load_baseline
from .diagnostics import fingerprint
from .planner_probe import run_case
from .reference_probe import harness_hash
from .survey import atomic_json, read_record

BASELINE = 'b385b10fe84c80ad72d70cf071d510bd1b98d457'
NAMESPACE = 'u13-rout-threeway-20260920-v1'
MODES = ('old', 'new', 'none')
# First three slots start active. Both seats use the identical selected setup;
# no Lord's production opening or castle selection policy is changed.
LOADOUTS = {
    'zero': ['Keep', 'Stockpile', 'Bastion', 'SummoningCircle', 'Bastion'],
    'one': ['Keep', 'Stockpile', 'SiegeEngine', 'SummoningCircle', 'Bastion'],
    'two': ['Keep', 'SiegeEngine', 'SiegeEngine', 'SummoningCircle', 'Stockpile'],
}


def cases(namespace=NAMESPACE, repeats=1):
    for repeat in range(repeats):
        for opponent in LORDS:
            for loadout, castles in LOADOUTS.items():
                for seat in (0, 1):
                    lords = [opponent, opponent]; lords[seat] = 'Deimos'
                    pair = f'{opponent.lower()}_{loadout}_{repeat:02d}_p{seat}'
                    for mode in MODES:
                        yield dict(name=pair+'__'+mode, pair_id=pair, mode=mode,
                            opponent=opponent, loadout=loadout, deimos_seat=seat,
                            mirror=opponent == 'Deimos', repeat=repeat,
                            setup=dict(seed=f'{namespace}:{opponent}:{loadout}:{repeat}',
                                lords=lords[:], castles=[castles[:], castles[:]]))


class Policy:
    def __init__(self, directory, spec, weights):
        base = load_baseline(Path(directory)/'baseline')
        self.policies = [base.CommonSmartCore(base.Weights(**weights)) for _ in (0, 1)]
        if spec['mode'] != 'old':
            self.policies[spec['deimos_seat']] = CommonSmartCore(Weights(**weights), rout_mode=spec['mode'])
        self.policy_ids = [p.policy_id for p in self.policies]
        self.spec, self.trace = spec, []

    def decide(self, view, preview):
        seat = view['player_id']; decision = self.policies[seat].decide(view, preview)
        if decision['policy'] != self.policy_ids[seat]: raise ValueError('Wrong seat policy')
        if self.spec['mode'] == 'none' and seat == self.spec['deimos_seat']:
            if any(s['power_id'] == 'Rout' for s in decision['plan']['powers']):
                raise ValueError('No-Rout control declared Rout')
        self.trace.append(dict(view=view, decision=decision))
        return decision

    def choose_card(self, view, category):
        return self.policies[view['player_id']].choose_card(view, category)


def run_one(spec, manifest, directory):
    policy = Policy(directory, spec, manifest['weights']); start = time.perf_counter()
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


def aggregate(records):
    rows, maximum = [], Counter()
    for record in records:
        spec, sem = record['spec'], record['semantic']
        row = {k: spec[k] for k in ('name', 'pair_id', 'mode', 'opponent', 'loadout', 'deimos_seat', 'mirror', 'repeat')}
        row.update(status=record['status'], error=record['error'])
        if record['status'] == 'complete':
            trace = [i for i in record['trace'] if i['view']['player_id'] == spec['deimos_seat']]
            groups = [g for g in sem['diagnostics']['groups'] if g['seat'] == spec['deimos_seat']]
            rout_groups = [g for g in groups if g['category'] == 'powers' and g['term'] == 'Rout']
            row.update(won=sem['outcome']['winner'] == spec['deimos_seat'], rounds=sem['rounds'],
                operations=sem['operations'], outcome=sem['outcome'],
                rejected_previews=len(sem['diagnostics']['rejected_previews']),
                rout_casts=sum(any(s['power_id'] == 'Rout' for s in i['decision']['plan']['powers']) for i in trace),
                war_machine_casts=sum(any(s['power_id'] == 'WarMachine' for s in i['decision']['plan']['powers']) for i in trace),
                rout_affected_marchers=sum(g['metrics'].get('affected_marchers', 0) for g in rout_groups),
                final_state_sha256=sem['final_state_sha256'], decisions_sha256=sem['decisions_sha256'])
            for key, value in sem['diagnostics']['maximum_work'].items(): maximum[key] = max(maximum[key], value)
        rows.append(row)
    groups, contrasts = {}, {}
    for scope in ('nonmirror', 'mirror', 'all'):
        selected = [r for r in rows if r['status'] == 'complete' and
                    (scope == 'all' or r['mirror'] == (scope == 'mirror'))]
        groups[scope] = {}
        for loadout in ('all', *LOADOUTS):
            subset = [r for r in selected if loadout == 'all' or r['loadout'] == loadout]
            groups[scope][loadout] = {mode: dict(games=sum(r['mode'] == mode for r in subset),
                **{key: sum(r[key] for r in subset if r['mode'] == mode)
                   for key in ('won', 'rounds', 'operations', 'rout_casts', 'war_machine_casts', 'rout_affected_marchers')}) for mode in MODES}
            pairs = defaultdict(dict)
            for row in subset: pairs[row['pair_id']][row['mode']] = row
            comparison = {}
            for left, right in (('new', 'old'), ('old', 'none'), ('new', 'none')):
                complete = [p for p in pairs.values() if left in p and right in p]
                gain = sum(p[left]['won'] and not p[right]['won'] for p in complete)
                loss = sum(p[right]['won'] and not p[left]['won'] for p in complete)
                discordant = gain+loss
                tail = min(1, 2*sum(math.comb(discordant, k) for k in range(min(gain, loss)+1))/2**discordant)
                comparison[left+'_vs_'+right] = dict(pairs=len(complete), gains=gain, losses=loss,
                    net=gain-loss, unchanged=len(complete)-discordant, descriptive_two_sided_sign_p=tail)
            contrasts[scope+'_'+loadout] = comparison
    main = contrasts['nonmirror_all']['new_vs_old']
    screen = (main['pairs'] == 48 and main['net'] >= 6 and main['gains'] >= 2*main['losses']
        and all(contrasts['nonmirror_'+k]['new_vs_old']['net'] > 0 for k in LOADOUTS))
    return dict(requested=len(rows), completed=sum(r['status'] == 'complete' for r in rows),
        failed=sum(r['status'] != 'complete' for r in rows), groups=groups, contrasts=contrasts,
        games=rows, maximum_work=dict(maximum),
        rejected_previews=sum(r.get('rejected_previews', 0) for r in rows),
        candidate_meets_preregistered_cohort_screen=screen,
        inference_limit='Exploratory fixed-opponent cohort, not Lord balance or independent Bernoulli trials. Opposite seats share seeds. Mirror old controls reuse the same setup and are correlated; report separately.')


def run(root, directory, workers=6, namespace=NAMESPACE, baseline=BASELINE):
    root, directory = Path(root), Path(directory)
    (directory/'games').mkdir(parents=True, exist_ok=True)
    frozen = freeze_baseline(root, baseline, directory/'baseline')
    revision, engine = source_identity(root)
    specs = list(cases(namespace))
    manifest = dict(schema='U13_ROUT_THREEWAY_V1', source_revision=revision,
        engine_source_sha256=engine, harness_source_sha256=harness_hash(root), baseline=frozen,
        weights=asdict(Weights()), namespace=namespace, specs=specs,
        implementation=platform.python_implementation(), python=sys.version,
        cohort_screen='New gains at least 6/48 nonmirror wins, gains at least twice losses, positive net in every loadout; all validation gates pass. No post-outcome coefficient changes.',
        scope='Old frozen V12 vs opt-in delay scorer vs V12 with Rout proposal suppressed. Every opponent is frozen V12 on identical current rules; only focal Deimos varies. Both seats share each loadout. No balance/rule changes.')
    path = directory/'manifest.json'
    if path.exists():
        import json
        if manifest != json.loads(path.read_text()): raise ValueError('Different experiment identity')
    atomic_json(path, manifest)
    pending = []
    for spec in specs:
        path = directory/'games'/(spec['name']+'.json.gz')
        if path.exists(): read_record(path, manifest, spec)
        else: pending.append(spec)
    start, done = time.perf_counter(), len(specs)-len(pending)
    print(f'THREEWAY {len(specs)} games, {done} cached, {workers} workers', flush=True)
    with ProcessPoolExecutor(max_workers=workers, mp_context=multiprocessing.get_context('spawn')) as pool:
        tasks = [pool.submit(run_one, spec, manifest, str(directory)) for spec in pending]
        for task in as_completed(tasks):
            result = task.result(); done += 1
            print(f"{result['status'].upper()} {done}/{len(specs)} {result['name']} rounds={result['rounds']} elapsed={time.perf_counter()-start:.1f}s", flush=True)
            if result['error']: print(result['error'], flush=True)
    if source_identity(root)[1] != engine or harness_hash(root) != manifest['harness_source_sha256']:
        raise ValueError('Source changed during experiment')
    result = aggregate(read_record(directory/'games'/(s['name']+'.json.gz'), manifest, s) for s in specs)
    report = dict(manifest=manifest, summary=result, summary_sha256=fingerprint(result), elapsed_seconds=time.perf_counter()-start)
    atomic_json(directory/'summary.json', report)
    print(f"THREEWAY COMPLETE {result['completed']}/{len(specs)}, failed={result['failed']}, rejected={result['rejected_previews']}", flush=True)
    return report
