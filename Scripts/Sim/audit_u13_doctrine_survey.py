#!/usr/bin/env python3
"""Inspect public decisions and replay a bounded set of missed-Rite scenarios.

This is a diagnostic, not an experimental policy. Counterfactual round replays
hold the recorded opposing order fixed; that order never informs candidate
construction. No strength estimate is derived from the selected examples.
"""
import argparse
from collections import Counter
import json
from pathlib import Path

from u13_doctrine.common import Weights, ordinary
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.facts import Facts
from u13_doctrine.observation import Preview, observe
from u13_doctrine.reference_probe import harness_hash
from u13_doctrine.survey import read_record, atomic_json, cases
from u13_doctrine.veil_judgment import settlement_projection
from u13_pysim.benchmark_full_match import digest
from u13_pysim.copying import copy_data
from u13_pysim.full_match_inputs import next_operation
from u13_pysim.power_match import PowerMatch
from u13_pysim.verify import source_identity


def replay_invocation(record, example):
    match = PowerMatch(record['spec']['setup'])
    number, seat = example['round'], example['seat']
    for operation in record['operations']:
        if match.clock.round == number and operation['kind'] == 'submit':
            break
        applied = match.apply(operation)
        if applied['action'] == 'invalid': raise ValueError(applied)
    else:
        raise ValueError('Recorded planning boundary missing')
    original = next(t for t in record['trace'] if t['view']['round'] == number and t['view']['player_id'] == seat)
    if fingerprint(observe(match, seat)) != fingerprint(original['view']):
        raise ValueError('Replay observation differs from recorded policy input')
    preview = Preview(match, seat)(example['alternative_plan'])
    if preview['action'] != 'legal': raise ValueError(preview)
    operation = copy_data(operation)
    operation['plans'][seat] = example['alternative_plan']
    changed = match.apply(operation)
    if changed['action'] == 'invalid': raise ValueError(changed)
    while match.clock.round == number and match.outcome()['winner'] == -1:
        applied = match.apply(next_operation(match))
        if applied['action'] == 'invalid': raise ValueError(applied)
    return dict(game=record['spec']['name'], round=number, seat=seat,
        observed_planning_input_matched=True, preview=preview,
        original_game_outcome=record['semantic']['outcome'],
        original_plan_scenario=original['decision']['veil']['paid_choice_scenario'],
        alternative_plan=example['alternative_plan'], predicted_scenario=example['alternative'],
        alternate_round_outcome=match.outcome(), alternate_final_sha256=digest(match),
        interpretation='One changed own plan against the same recorded simultaneous opponent order; not a guaranteed win against other orders')


def audit(directory, summary_name='summary.json', replay_examples=6):
    directory = Path(directory)
    report = json.loads((directory/summary_name).read_text())
    if fingerprint(report['summary']) != report['summary_sha256']:
        raise ValueError('Corrupt survey summary')
    identity = report['manifest']; weights = Weights(**identity['weights'])
    root = Path(__file__).resolve().parents[2]
    if source_identity(root)[1] != identity['engine_source_sha256'] or harness_hash(root) != identity['harness_source_sha256']:
        raise ValueError('Engine or policy differs from the saved survey; use matching source for this audit.')
    by_name = {s['name']: s for s in cases(report['repeats'], identity['namespace'])}
    invocation, conflicts, decisions = Counter(), Counter(), Counter()
    examples, power_examples, missed_games = [], {}, set()
    for header in report['summary']['games']:
        spec = by_name[header['name']]
        record = read_record(directory/'games'/(spec['name']+'.json.gz'), identity, spec)
        if record['status'] != 'complete': continue
        for item in record['trace']:
            view, decision = item['view'], item['decision']
            f = Facts(view); order = decision['plan']['order']
            decisions['planning_decisions'] += 1
            decisions['selected_enemy_win_scenario'] += decision['veil']['paid_choice_scenario']['winner'] == f.enemy
            for p in ordinary(f, 'rites', weights):
                if p.term != 'Invocation': continue
                payment = sum(f.by_id[k]['attributes']['value'] for k in p.cards)
                net = p.value-weights.card_cost*payment
                invocation['generated'] += 1
                invocation['initial_score_nonpositive'] += net <= 0
                plan = dict(powers=[], order=p.payload)
                result = settlement_projection(f, plan)
                if result['winner'] == f.pid and decision['veil']['paid_choice_scenario']['winner'] != f.pid:
                    invocation['alternative_wins_current_board_scenario_chosen_does_not'] += 1
                    invocation['scenario_'+result['win_by']] += 1
                    missed_games.add(spec['name'])
                    # One earliest example per game, fixed order; priority is
                    # given below to games the relevant seat actually lost.
                    if not any(x['game'] == spec['name'] for x in examples):
                        examples.append(dict(game=spec['name'], round=view['round'], seat=f.pid,
                            lord=f.kind, original_loser=record['semantic']['outcome']['winner'] != f.pid,
                            initial_score=net, payment=payment, alternative_plan=plan, alternative=result))
            for power in decision['plan']['powers']:
                name = power['power_id']
                if name not in ('Projection', 'Consume', 'Ravenous'): continue
                conflicts[name+':selected'] += 1
                if name == 'Ravenous':
                    if order.get('lane') == power['target']['lane'] and order.get('card_ids'):
                        conflicts[name+':same_lane_recruitment'] += 1
                    continue
                lane = power['target']['zone'] if name == 'Projection' else f.by_id[power['target']['entity_id']]['attributes']['lane']
                if order.get('action') not in ('Hunt', 'Siege') or order.get('lane') != lane: continue
                forecast = f.attack(order['action'], order['target_id'], order['card_ids'])
                if forecast['guards'] == len(f.guards(f.enemy, lane)):
                    conflicts[name+':own_attack_removes_all_visible_guards'] += 1
                    selected = power_examples.setdefault(name, [])
                    if len(selected) < 4:
                        selected.append(dict(game=spec['name'], round=view['round'], seat=f.pid,
                                             power=power, order=order, forecast=forecast))
    invocation['games_with_missed_scenario'] = len(missed_games)
    examples.sort(key=lambda x: (not x['original_loser'], x['game'], x['round'], x['seat']))
    replays = []
    for example in examples[:replay_examples]:
        spec = by_name[example['game']]
        record = read_record(directory/'games'/(spec['name']+'.json.gz'), identity, spec)
        result = replay_invocation(record, example); replays.append(result)
        print('REPLAY', example['game'], example['round'], result['alternate_round_outcome'], flush=True)
    return dict(manifest_sha256=fingerprint(identity), summary_sha256=report['summary_sha256'],
        decisions=decisions, invocation=invocation, power_conflicts=conflicts,
        power_examples=power_examples, missed_invocation_examples=examples[:20], invocation_replays=replays,
        limitations=['Current-board scenarios omit future simultaneous orders and reactions.',
            'Guard-clear forecasts omit new enemy Guards/Ward; they identify risk, not guaranteed whiffs.',
            'Same-lane Ravenous recruitment alone does not prove harmful net value.',
            'Selected replay counterfactuals demonstrate cases, not a win-rate estimate.'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--summary', default='summary.json')
    parser.add_argument('--replay-examples', type=int, default=6)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.replay_examples < 0: parser.error('replay examples must be nonnegative')
    result = audit(args.directory, args.summary, args.replay_examples)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    atomic_json(args.output, result)
    print(json.dumps({k: result[k] for k in ('decisions','invocation','power_conflicts')}, sort_keys=True))


if __name__ == '__main__': main()
