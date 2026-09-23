#!/usr/bin/env python3
"""Three-arm paired Ward/attack-reward trial, two recycled workers; Python only."""
import argparse
from collections import Counter
from dataclasses import asdict
import gc
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time
import traceback

from run_u13_lord_balance import freeze, verify_frozen, package
from u13_pysim.lifecycle import RITUAL_SOULS, DOMINION_TEARS, DOMINION_VEIL
from u13_pysim.split_ward import VERSION, TEMPO, TEMPO_SOUL_START_ROUND
from u13_doctrine.common import Weights
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.planner_probe import run_case, PlannerObserver
from u13_doctrine.process_memory import sample
from u13_doctrine.survey import (TracedPolicy, cases, atomic_json, pooled_results,
                                read_record, manifest)

NAMESPACE = 'u13-split-ward-screen-20260921'
PAIRS = (('Gremory', 'Kanifous'), ('Kalligan', 'Deimos'), ('Humbaba', 'Kroni'))


def specs(full_roster=False, tempo=False, early_check=False, roster_screen=False):
    if roster_screen:
        for case in cases(2, "u13-tempo-roster-20260922"):
            yield dict(case, name=case["name"]+"_tempo", arm="tempo",
                setup=dict(case["setup"], ward_experiment=VERSION, tempo_experiment=TEMPO))
        return
    if early_check:
        early = {('Kanifous', 'Gremory'), ('Gremory', 'Kanifous'), ('Humbaba', 'Kroni')}
        for case in cases(6, NAMESPACE):
            if case['repeat'] == 0 or tuple(case['setup']['lords']) not in early: continue
            setup = dict(case['setup'], ward_experiment=VERSION, tempo_experiment=TEMPO)
            yield dict(case, name=case['name']+'_tempo', arm='tempo', setup=setup)
        return
    selected = {pair for left, right in PAIRS for pair in ((left, right), (right, left))}
    for case in cases(1, NAMESPACE):
        if not full_roster and tuple(case['setup']['lords']) not in selected: continue
        for arm in (('split', 'bonus', 'tempo') if tempo else ('current', 'split', 'bonus')):
            spec = dict(case, name=case['name']+'_'+arm, arm=arm, setup=dict(case['setup']))
            if arm in ('split', 'bonus', 'tempo'): spec['setup']['ward_experiment'] = VERSION
            if arm == 'bonus': spec['setup']['decisive_soul_bonus'] = True
            if arm == 'tempo': spec['setup']['tempo_experiment'] = TEMPO
            yield spec


class Observer(PlannerObserver):
    def __init__(self, *args):
        super().__init__(*args)
        self.trial = Counter()
        self.wards = []
        self.finish = None
        self.attack_escalation = {}

    def accepted(self, number, seat, decision):
        super().accepted(number, seat, decision)
        order = decision['plan']['order']
        self.trial['decisions'] += 1
        self.trial['action:'+order.get('action', 'Pass')] += 1
        ward = order if order.get('action') == 'Ward' else order.get('ward', {})
        self.trial['ward_decisions'] += bool(ward)
        self.trial['split_decisions'] += bool(order.get('ward'))
        self.trial['ward_cards'] += len(ward.get('card_ids', []))
        self.trial['attack_cards'] += len(order.get('card_ids', [])) if order.get('action') in ('Hunt', 'Siege') else 0
        self.trial['split_candidates'] += decision.get('split_ward', {}).get('candidates', 0)

    def event(self, index, event, current_round):
        super().event(index, event, current_round)
        kind, data = event['type'], event['data']
        if kind == 'MARCHER_SPAWNED':
            self.trial['monster_bodies' if 'monster_id' in data['attributes'] else 'normal_recruits'] += 1
        if kind == 'MONSTER_SUMMONED': self.trial['monster_summons'] += 1
        if kind == 'WARD_CONTESTED':
            self.trial['ward_contested'] += 1
            self.trial['ward_saved'] += data['saved']
            self.wards.append(data)
        if kind == 'WARD_SOUL_GAINED': self.trial['ward_souls'] += data['amount']
        if kind == 'DECISIVE_SOUL_GAINED': self.trial['decisive_souls'] += data['amount']
        if kind in ('HUNT_STARTED', 'SIEGE_STARTED') and 'veil_attack_bonus' in data:
            bonus = data['veil_attack_bonus']
            self.trial['attacks_with_bonus:'+str(bonus)] += 1
            self.attack_escalation.setdefault(str(bonus), current_round)
        if kind == 'MATCH_FINISHED':
            self.finish = dict(data)
            tears = data['personal_tears']
            self.finish['ritual_souls_required'] = RITUAL_SOULS
            self.finish['dominion_tears_required'] = DOMINION_TEARS
            self.finish['personal_tears_short_of_dominion'] = [max(0, DOMINION_TEARS-t) for t in tears]
            self.finish['dominion_qualified_players'] = [pid for pid in (0, 1)
                if data['veil_total'] >= DOMINION_VEIL and tears[pid] >= DOMINION_TEARS and tears[pid] > tears[1-pid]]
            self.finish['personal_tears_short_of_five'] = [max(0, 5-t) for t in tears]
            self.finish['veil_short_of_twelve'] = max(0, 12-data['veil_total'])
            self.finish['personal_tears_tied'] = tears[0] == tears[1]

    def report(self):
        return dict(super().report(), split_trial=dict(self.trial), ward_audit=self.wards, victory_race=self.finish, attack_escalation_first_round=self.attack_escalation)


def worker(spec, identity, directory):
    started = time.perf_counter(); cpu = time.process_time()
    memory = sample()
    policy = TracedPolicy(Weights(**identity['weights']))
    try:
        semantic, timing, operations = run_case(spec, policy, observer_factory=Observer)
        status, error = 'complete', None
    except Exception:
        semantic, timing, operations = {}, {}, []
        status, error = 'failed', traceback.format_exc()
    record = dict(manifest_sha256=fingerprint(identity), spec=spec, status=status,
        semantic=semantic, semantic_sha256=fingerprint(semantic), timing=timing,
        operations=operations, trace=policy.trace, trace_sha256=fingerprint(policy.trace),
        error=error, wall_seconds=time.perf_counter()-started)
    atomic_json(Path(directory)/(spec['name']+'.json.gz'), record, compressed=True)
    result = dict(name=spec['name'], status=status, rounds=semantic.get('rounds'), error=error,
                  wall_seconds=time.perf_counter()-started)
    del record, policy, semantic, timing, operations
    gc.collect()
    result['performance'] = dict(start=memory, after_gc=sample(), cpu_seconds=time.process_time()-cpu)
    return result


def execute(output, full_roster=False, tempo=False, early_check=False, roster_screen=False):
    verify_frozen(output)
    identity = manifest(Path(__file__).resolve().parents[2], "u13-tempo-roster-20260922" if roster_screen else NAMESPACE, Weights())
    identity.update(experiment=VERSION, scope='Python-only opt-in rules trial; no native/UI parity claim',
                    frozen_source=fingerprint(json.loads((output/'frozen-source.json').read_text())))
    atomic_json(output/'manifest.json', identity)
    case_list = list(specs(full_roster, tempo, early_check, roster_screen))
    atomic_json(output/'split-config.json', dict(cases=case_list, workers=2, worker_batch_size=4, full_roster=full_roster, tempo=tempo, early_check=early_check, roster_screen=roster_screen,
        tempo_rule=f"Veil 15/19/23: +1/+2/+3 attack; bonus souls from round {TEMPO_SOUL_START_ROUND}; hard end after normal victories at round 25" if tempo else None,
        bonus='One extra soul for Hunt banishment or Siege target destruction, max one per player/round; no pillage',
        source_revision=identity['source_revision'], runtime=platform.python_implementation(),
        rule='One nonempty Ward plus optional Hunt/Siege, disjoint cards, no Sigils, lane-only screen, at most one causal-save soul'))
    games = output/'games'; games.mkdir()
    for result in pooled_results(case_list, identity, str(games), 2, 4, task=worker):
        if result is None: print('Two workers still running.', flush=True); continue
        print(json.dumps(result), flush=True)
        atomic_json(output/(result['name']+'-performance.json'), result)
        if result['status'] != 'complete': raise RuntimeError(result['error'])
    if roster_screen:
        from u13_doctrine.lord_balance import summarize, markdown
        balance = summarize(read_record(games/(spec["name"]+".json.gz"), identity, spec) for spec in case_list)
        atomic_json(output/"lord-balance.json", balance)
        (output/"lord-balance.md").write_text(markdown(balance), encoding="utf-8")
    arms = {spec['arm']: Counter() for spec in case_list}
    paired = {}
    for spec in case_list:
        record = read_record(games/(spec['name']+'.json.gz'), identity, spec)
        game = record['semantic']; diagnostics = game['diagnostics']
        stats = Counter(diagnostics['split_trial'])
        stats.update(games=1, rounds=game['rounds'], rejected_previews=len(diagnostics['rejected_previews']),
                     banishments=diagnostics['event_counts'].get('LORD_BANISHED', 0))
        stats['win:'+game['outcome']['win_by']] += 1
        stats['round_band:'+('under15' if game['rounds'] < 15 else '15to20' if game['rounds'] <= 20 else 'over20')] += 1
        stats['reached_round25'] += game['rounds'] >= 25
        stats['normal_win_in_target_window'] += (15 <= game['rounds'] <= 20
            and game['outcome']['win_by'] in ('Ritual', 'Dominion'))
        finish = diagnostics['victory_race']
        stats['ended_before_collapse_threshold'] += finish['veil_total'] < 26
        stats['ended_at_collapse_threshold'] += finish['veil_total'] >= 26
        if game['outcome']['win_by'] == 'Ritual':
            stats['ritual_with_someone_dominion_qualified'] += bool(finish['dominion_qualified_players'])
            stats['ritual_with_neither_at_five_tears'] += max(finish['personal_tears']) < 5
        arms[spec['arm']].update(stats)
        paired.setdefault(spec['name'].rsplit('_', 1)[0], {})[spec['arm']] = dict(stats, victory_race=finish, attack_escalation_first_round=diagnostics["attack_escalation_first_round"])
    report = dict(arms=arms, paired=paired, scope=('162 current-tempo games: two fresh seeds per ordered matchup, including 18 mirrors' if roster_screen else 'Five fresh seeds for each of three previously early seat-ordered matchups; new tempo rules only' if early_check
                     else f'{len(case_list)//3} seed/loadout/seat triplets; exploratory comparison, not tuned balance'),
                  primary=('Normal victories in rounds 15-20; early/late tails and round-25 forced endings' if tempo
                           else 'FinalCollapse frequency and endings below Veil 26'), guardrail='Preserve Dominion alongside Ritual; inspect terminal souls, tears and Veil')
    atomic_json(output/'split-comparison.json', report)
    print(json.dumps(report, indent=2), flush=True)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--roster-screen', action='store_true', help='162 current-tempo games; two fresh seeds per ordered matchup')
    parser.add_argument('--early-check', action='store_true', help='Five fresh seeds per early matchup; 15 tempo games')
    parser.add_argument('--tempo', action='store_true', help='Compare split, always-on bonus, and Veil/round-25 tempo profile')
    parser.add_argument('--full-roster', action='store_true', help='81 matchups per arm, 243 games total')
    parser.add_argument('--frozen', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.roster_screen:
        if args.full_roster or args.early_check: parser.error("roster-screen cannot combine with another sample selection")
        args.tempo = True
    if args.early_check:
        if args.full_roster: parser.error("early-check and full-roster are mutually exclusive")
        args.tempo = True
    if args.frozen: return execute(args.output, args.full_roster, args.tempo, args.early_check, args.roster_screen)
    root = Path(__file__).resolve().parents[2]
    output = (args.output or Path.home()/'Downloads/Corruptor/Balance'/
              time.strftime('split-ward-%Y%m%d-%H%M%S')).resolve()
    output.mkdir(parents=True, exist_ok=False)
    frozen = freeze(root, output)
    env = dict(os.environ); env.pop('PYTHONPATH', None)
    checks = subprocess.run([sys.executable, '-m', 'unittest', 'u13_doctrine.test_split_ward',
        'u13_doctrine.test_ward_recipes', 'u13_doctrine.test_reserved_recipes', 'u13_doctrine.test_diagnostics',
        'u13_doctrine.test_recipes_veil'], cwd=frozen/'Scripts/Sim', env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (output/'focused-python.log').write_text(checks.stdout)
    print(checks.stdout, flush=True)
    if checks.returncode: return checks.returncode
    print(f'Prepared {162 if args.roster_screen else 15 if args.early_check else 243 if args.full_roster else 18} games, two workers, recycle every four games: {output}', flush=True)
    if args.prepare_only: return 0
    code = 1
    try:
        with (output/'run.log').open('w') as log:
            proc = subprocess.Popen([sys.executable, '-u', str(frozen/'Scripts/Sim/run_u13_split_ward_experiment.py'),
                '--frozen', '--output', str(output)]+(['--full-roster'] if args.full_roster else [])+(['--tempo'] if args.tempo else [])+(['--early-check'] if args.early_check else [])+(['--roster-screen'] if args.roster_screen else []), cwd=frozen, env=env,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            for line in proc.stdout: print(line, end='', flush=True); log.write(line); log.flush()
            code = proc.wait()
        return code
    finally:
        atomic_json(output/'run-status.json', dict(status='complete' if code == 0 else 'failed_or_interrupted', exit_code=code))
        package(output)


if __name__ == '__main__': raise SystemExit(main())
