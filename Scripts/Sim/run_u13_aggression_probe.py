#!/usr/bin/env python3
"""Paired doctrine-memory ablation against a public-information all-in attacker.

Regular full-game rules and marching lanes. No combat shortcuts or rule changes.
The attacker ignores Guards/powers/Work, uses its entire remaining hand, and
waits until Ritual is funded before returning a banished Lord.
"""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from copy import copy
import json
from pathlib import Path
import time

from u13_pysim import full_match_inputs
from u13_pysim.power_match import PowerMatch
from u13_pysim.lifecycle import RITUAL_SOULS
from u13_pysim.opening import LORDS
from u13_doctrine.common import CommonSmartCore, Weights, ordinary
from u13_doctrine.facts import Facts, Proposal
from u13_doctrine.observation import observe, Preview
from u13_doctrine.recipes import Recipes
from u13_doctrine.diagnostics import fingerprint

LOADOUT = ['Keep', 'Bastion', 'SummoningCircle', 'Stockpile', 'SiegeEngine']


def all_in(view, preview):
    f = Facts(view); weights = Weights(); prefixes = [{}]
    if not f.lord[f.pid]['attributes']['alive'] and f.resources['souls'] >= RITUAL_SOULS:
        prefixes = [p.payload for p in ordinary(f, 'resummon', weights)] or [{}]
    candidates = []
    for prefix in prefixes:
        paid = prefix.get('summon', {}).get('card_ids', [])
        reduced = copy(f); reduced.hand = [r for r in f.hand if r['id'] not in paid]
        ids = [r['id'] for r in reduced.hand]; book = Recipes(reduced, weights)
        for action, lane, target in reduced.attack_targets():
            if not ids: continue
            p = Proposal('combat', action, dict(action=action, lane=lane, target_id=target, card_ids=ids),
                         reduced.attack_value(action, target, ids, weights), 'all_in', tuple(ids))
            book.attach(p)
            order = dict(p.payload, **prefix)
            order['staging'] = {lane: 'March' for lane in ('Lord', 'Castle')}
            candidates.append((p.value, dict(order=order, powers=[])))
        if not ids:
            candidates.append((0, dict(order=prefix, powers=[])))
    for _, plan in sorted(candidates, key=lambda x: (-x[0], fingerprint(x[1]))):
        if preview(plan)['action'] == 'legal': return plan
    raise ValueError('all-in adversary has no legal plan')


def run(spec):
    started = time.perf_counter(); seat = spec['bot_seat']
    lords = ['Deimos', 'Deimos']; lords[seat] = spec['lord']
    game = PowerMatch(dict(seed=spec['seed'], lords=lords, castles=[LOADOUT[:], LOADOUT[:]],
        ward_experiment='U13_SPLIT_WARD_V1', tempo_experiment='U13_VEIL_ATTACK_ROUND25_V1'))
    policy = CommonSmartCore(opponent_memory_enabled=spec['memory'])
    choices = []; counts = Counter(); cursor = 0
    while game.outcome()['winner'] == -1:
        if game.clock.round > 25: raise ValueError('probe exceeded round limit')
        hook = game.clock.hook; data = game._state['world']['data']
        if hook == 'submission_lock' and game._state['submissions'] == [None, None]:
            decision = policy.decide(observe(game, seat), Preview(game, seat))
            plans = [None, None]; plans[seat] = decision['plan']
            plans[1-seat] = all_in(observe(game, 1-seat), Preview(game, 1-seat))
            order = plans[seat]['order']; ward = order if order.get('action') == 'Ward' else order.get('ward')
            counts['ward_rounds'] += bool(ward)
            counts['attack_rounds'] += order.get('action') in ('Hunt', 'Siege')
            counts['reactive_rounds'] += bool(decision['opponent_memory']['aggression'])
            choices.append(dict(round=game.clock.round, plan=plans[seat],
                memory=decision['opponent_memory'], defense=decision['defense']['selected']))
            op = dict(kind='submit', plans=plans)
        elif hook == 'present_public_state' and data['game_economy']['stockpile_pending']:
            pid = data['game_economy']['stockpile_pending']['player_id']
            op = policy.choose_card(observe(game, pid), 'stockpile')['operation']
        elif hook == 'present_public_state' and data['game_market']['seat'] != 2:
            pid = data['game_market']['seat']
            op = policy.choose_card(observe(game, pid), 'slaver')['operation']
        else:
            op = full_match_inputs.next_operation(game)
        result = game.apply(op)
        if result['action'] == 'invalid': raise ValueError((game.clock.round, op, result))
        events = game._state['events']['rows']
        for envelope in events[cursor:]:
            event = envelope['event']; d = event['data']
            if event['type'] == 'WARD_CONTESTED' and d['player_id'] == seat:
                counts['ward_saves'] += bool(d['saved'])
            if event['type'] == 'PERSONAL_TEAR_CREATED' and d.get('player_id') == seat:
                counts['tear_source:'+d.get('source', 'unknown')] += d.get('amount', 1)
        cursor = len(events)
    return dict(spec=spec, outcome=game.outcome(), rounds=game.clock.round,
                bot_won=game.outcome()['winner'] == seat, counts=dict(counts), decisions=choices,
                seconds=round(time.perf_counter()-started, 3))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lords', nargs='+', choices=LORDS, default=['Gremory', 'Humbaba', 'Valak'])
    parser.add_argument('--repeats', type=int, default=1)
    parser.add_argument('--workers', type=int, default=3)
    parser.add_argument('--output', type=Path, default=Path('aggression-probe'))
    args = parser.parse_args()
    if args.repeats < 1 or not 1 <= args.workers <= 4: parser.error('positive repeats; 1–4 workers')
    if args.output.exists() and any(args.output.iterdir()): parser.error('output directory must be empty')
    args.output.mkdir(parents=True, exist_ok=True)
    specs = [dict(lord=lord, bot_seat=seat, memory=memory,
                  seed=f'u13-aggression-v1:{lord}:{repeat}')
             for lord in args.lords for repeat in range(args.repeats)
             for seat in (0,1) for memory in (False,True)]
    results = []
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        for i, row in enumerate(pool.map(run, specs)):
            results.append(row)
            (args.output/f'game-{i:03d}.json').write_text(json.dumps(row, indent=2)+'\n')
            print(json.dumps({k:v for k,v in row.items() if k != 'decisions'}), flush=True)
    summary = {str(memory):dict(games=sum(r['spec']['memory']==memory for r in results),
        bot_wins=sum(r['bot_won'] for r in results if r['spec']['memory']==memory),
        mean_rounds=sum(r['rounds'] for r in results if r['spec']['memory']==memory)/(len(results)/2))
        for memory in (False,True)}
    (args.output/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary), flush=True)


if __name__ == '__main__': main()
