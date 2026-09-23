#!/usr/bin/env python3
"""Paired Python experiment: ordinary first draw and free starting Lords.

The production opening, rules, policy and native gates are untouched. Only a
fresh experimental match's setup is replaced, before any operation runs.
"""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, wait, FIRST_COMPLETED
import hashlib
import json
import multiprocessing
from pathlib import Path
import platform
import statistics
import sys
import time
import traceback
from unittest.mock import patch

from u13_doctrine import planner_probe
from u13_doctrine.common import Weights, VERSION
from u13_doctrine.diagnostics import fingerprint
from u13_doctrine.reference_probe import harness_hash
from u13_doctrine.survey import TracedPolicy, atomic_json, cases, read_record
from u13_pysim import opening, economy
from u13_pysim.copying import copy_data
from u13_pysim.power_match import PowerMatch
from u13_pysim.primitives import entity_id
from u13_pysim.verify import source_identity

EXPERIMENT = 'U13_EXPERIMENT_FREE_LORD_NORMAL_DRAW_V1'
VARIANTS = ('control', 'normal_draw')


def undealt_deck(seed):
    """Reproduce the same trimmed/shuffled deck, with physical IDs preserved."""
    deck = []
    for suit in opening.SUITS:
        cards = [entity_id('card', 'game:deck:'+suit, i) for i in range(sum(opening.COUNTS))]
        opening.shuffle(cards, seed, 'trim:'+suit)
        deck.extend(cards[3:])
    opening.shuffle(deck, seed, 'opening')
    market = [deck.pop() for _ in range(3)]
    return deck, market


def make_match(setup, variant):
    if variant not in VARIANTS:
        raise ValueError('unknown opening variant')
    match = PowerMatch(setup)
    if variant == 'control':
        return match
    s, w = match._state, match._state['world']
    z = economy.zones(w)
    deck, market = undealt_deck(setup['seed'])
    # Fail closed if the production setup has changed beneath the experiment.
    dealt = deck[:]
    original_hands = [[dealt.pop() for _ in range(5)] for _ in range(2)]
    records = w['data']['game_economy']['opening']['summons']
    if z['deck'] != dealt or z['market'] != market:
        raise ValueError('production shuffle/deal changed')
    for pid, record in enumerate(records):
        if z['hands'][pid] != [c for c in original_hands[pid] if c not in record['card_ids']]:
            raise ValueError('production opening payment changed')
    if z['discard'] != [c for record in records for c in record['card_ids']]:
        raise ValueError('production opening discard changed')

    # Omit the separate setup deal and its card payment. The normal first-round
    # draw, Stockpile and Slaver still execute through the unchanged authority.
    z['deck'], z['hands'], z['discard'] = deck, [[], []], []
    for row in w['entities']['entities']:
        if row['kind'] == 'card':
            row['owner'] = -1
    for record in records:
        if record['circle_id']:
            economy.entity(w, record['circle_id'])['attributes']['integrity'] += record['circle_exerted']
        record.update(cost=0, paid_value=0, shortfall=0, card_ids=[], card_values=[],
                      circle_id='', circle_exerted=0)
    if not economy.cards_valid(w):
        raise ValueError('experimental opening broke physical card ownership')
    s['presentation_world'] = copy_data(w)
    # Experimental states must never masquerade as native-accepted snapshots.
    s['policy_id'] += ':'+EXPERIMENT
    s['rules_hash'] = hashlib.sha256((s['rules_hash']+':'+EXPERIMENT).encode()).hexdigest()
    return match


def metrics(match, trace):
    losses = []
    for row in match._state['events']['rows']:
        event = row['event']; kind, d = event['type'], event['data']
        if kind == 'CASTLE_DESTROYED':
            castle = d['castle']
            cause = 'hunt_keep' if d['event_id'].startswith('hunt:') else d['cause']
            losses.append(dict(round=d['round'], cause=cause, castle_id=castle['id'],
                owner=castle['owner'], castle_type=castle['attributes']['castle_type']))
        elif kind == 'CASTLE_RUINED':
            losses.append(dict(round=d['round'], cause=d['cause'], castle_id=d['castle_id'],
                               owner=d['player_id']))
    castles = [r for r in match._state['world']['entities']['entities'] if r['kind'] == 'castle']
    first = []
    for item in trace:
        view, plan = item['view'], item['decision']['plan']
        if view['round'] != 1:
            continue
        hand = view['hand']
        first.append(dict(seat=view['player_id'], cards=len(hand),
            face_value=sum(r['attributes']['value'] for r in hand),
            full_hand_attack_strength=sum(r['attributes']['value'] for r in hand),
            action=plan['order'].get('action', 'Pass'),
            combat_cards=len(plan['order'].get('card_ids', [])),
            guard_cards=len(plan['order'].get('guard_moves', []))))
    return dict(losses=losses, first_loss_round=min((r['round'] for r in losses), default=None),
        opening_decisions=first,
        final_castles=[dict(id=r['id'], owner=r['owner'], **r['attributes']) for r in castles],
        final_commissioned_survivors=sum(r['attributes']['status'] in ('standing','defunct')
            and r['attributes']['construction_state']=='active' for r in castles))


def read_result(path, identity, spec, variant):
    record = read_record(path, identity, spec)
    if record['variant'] != variant or record['metrics_sha256'] != fingerprint(record['metrics']):
        raise ValueError('corrupt comparison metrics: '+str(path))
    return record


def run_pair(spec, identity, directory, baseline_directory):
    baseline = read_record(Path(baseline_directory)/'games'/(spec['name']+'.json.gz'),
                           identity['baseline'], spec)
    results = []
    for variant in VARIANTS:
        path = Path(directory)/variant/(spec['name']+'.json.gz')
        if path.exists():
            record = read_result(path, identity, spec, variant)
        else:
            policy = TracedPolicy(Weights(**identity['baseline']['weights']))
            created = []
            def factory(setup):
                match = make_match(setup, variant)
                created.append(match)
                return match
            start = time.perf_counter()
            semantic, timing, operations, measured, error = {}, {}, [], {}, None
            try:
                # This patch is scoped to the probe's constructor alias in one
                # worker process. PowerMatch and all its handlers stay original.
                with patch.object(planner_probe, 'PowerMatch', factory):
                    semantic, timing, operations = planner_probe.run_case(spec, policy)
                measured = metrics(created[0], policy.trace)
                if variant == 'control':
                    if semantic != baseline['semantic'] or fingerprint(policy.trace) != baseline['trace_sha256']:
                        raise ValueError('control differs from saved survey')
                status = 'complete'
            except Exception:
                status, error = 'failed', traceback.format_exc()
            record = dict(manifest_sha256=fingerprint(identity), spec=spec, variant=variant,
                status=status, error=error, semantic=semantic, semantic_sha256=fingerprint(semantic),
                timing=timing, operations=operations, trace=policy.trace, trace_sha256=fingerprint(policy.trace),
                metrics=measured, metrics_sha256=fingerprint(measured), wall_seconds=time.perf_counter()-start,
                control_matches_saved_survey=(variant=='control' and status=='complete'))
            atomic_json(path, record, compressed=True)
        results.append(dict(variant=variant, status=record['status'], error=record['error'],
                            rounds=record['semantic'].get('rounds')))
    return dict(name=spec['name'], results=results)


def summary(records):
    good = [r for r in records if r['status']=='complete']
    if not good:
        return dict(completed=0, failed=len(records))
    losses = [loss for r in good for loss in r['metrics']['losses']]
    first = [r['metrics']['first_loss_round'] for r in good if r['metrics']['first_loss_round'] is not None]
    decisions = [d for r in good for d in r['metrics']['opening_decisions']]
    rounds = [r['semantic']['rounds'] for r in good]
    lords = {lord:dict(games=0, wins=0) for lord in opening.LORDS}
    for r in good:
        for seat, lord in enumerate(r['spec']['setup']['lords']):
            lords[lord]['games'] += 1
            lords[lord]['wins'] += int(r['semantic']['outcome']['winner']==seat)
    return dict(completed=len(good), failed=len(records)-len(good),
        rejected_previews=sum(len(r['semantic']['diagnostics']['rejected_previews']) for r in good),
        mean_rounds=statistics.mean(rounds), median_rounds=statistics.median(rounds), round_range=[min(rounds),max(rounds)],
        wins_by=Counter(r['semantic']['outcome']['win_by'] for r in good), lord_results=lords,
        first_loss_median=statistics.median(first) if first else None,
        first_loss_mean=statistics.mean(first) if first else None,
        games_without_castle_loss=len(good)-len(first),
        games_with_round_one_loss=sum(x==1 for x in first),
        games_with_loss_by_round_three=sum(x<=3 for x in first),
        losses=len(losses), loss_causes=Counter(r['cause'] for r in losses),
        losses_by_round=Counter(str(r['round']) for r in losses),
        mean_castle_losses=len(losses)/len(good),
        mean_commissioned_survivors=statistics.mean(r['metrics']['final_commissioned_survivors'] for r in good),
        opening_hands_mean=statistics.mean(d['cards'] for d in decisions),
        opening_attack_strength_mean=statistics.mean(d['full_hand_attack_strength'] for d in decisions),
        opening_actions=Counter(d['action'] for d in decisions),
        opening_guard_cards_mean=statistics.mean(d['guard_cards'] for d in decisions))


def compare(records):
    control, alternative = records['control'], records['normal_draw']
    pairs = []
    for a, b in zip(control, alternative):
        if a['spec'] != b['spec']:
            raise ValueError('unpaired comparison')
        if a['status']!='complete' or b['status']!='complete':
            continue
        pairs.append(dict(name=a['spec']['name'], lords=a['spec']['setup']['lords'],
            repeat=a['spec']['repeat'],
            rounds_delta=b['semantic']['rounds']-a['semantic']['rounds'],
            castle_losses_delta=len(b['metrics']['losses'])-len(a['metrics']['losses']),
            first_loss_round=[a['metrics']['first_loss_round'], b['metrics']['first_loss_round']],
            round_one_loss=[a['metrics']['first_loss_round']==1,b['metrics']['first_loss_round']==1],
            winner_changed=a['semantic']['outcome']['winner']!=b['semantic']['outcome']['winner']))
    return dict(pairs=pairs, paired_games=len(pairs),
        all_controls_match_saved_survey=bool(control) and all(r['control_matches_saved_survey'] for r in control),
        rounds_delta_mean=statistics.mean(p['rounds_delta'] for p in pairs) if pairs else None,
        longer=sum(p['rounds_delta']>0 for p in pairs), shorter=sum(p['rounds_delta']<0 for p in pairs),
        same_length=sum(p['rounds_delta']==0 for p in pairs),
        round_one_losses_removed=sum(p['round_one_loss']==[True,False] for p in pairs),
        round_one_losses_added=sum(p['round_one_loss']==[False,True] for p in pairs),
        winners_changed=sum(p['winner_changed'] for p in pairs))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repeats', type=int, default=2)
    parser.add_argument('--workers', type=int, default=8)
    parser.add_argument('--limit', type=int, help='bounded smoke run; same manifest permits later extension')
    args = parser.parse_args()
    if args.repeats<1 or args.workers<1 or (args.limit is not None and args.limit<1):
        parser.error('counts must be positive')
    root = Path(__file__).resolve().parents[2]
    baseline = json.loads((args.baseline/'manifest.json').read_text())
    revision, engine = source_identity(root)
    if engine!=baseline['engine_source_sha256'] or harness_hash(root)!=baseline['harness_source_sha256'] or VERSION!=baseline['policy']:
        raise ValueError('source differs from saved baseline')
    identity = dict(schema='U13_OPENING_COMPARISON_V1', experiment=EXPERIMENT, source_revision=revision,
        engine_source_sha256=engine, baseline=baseline,
        runner_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        python=sys.version, implementation=platform.python_implementation(),
        intervention='omit setup deal/payment; restore initial Circle offering; keep ordinary draw, Stockpile, Slaver and later Resummon',
        scope='Python rule experiment, unchanged doctrine; not native parity or Lord balance evidence')
    args.output.mkdir(parents=True, exist_ok=True)
    manifest_path = args.output/'manifest.json'
    if manifest_path.exists() and json.loads(manifest_path.read_text())!=identity:
        raise ValueError('different comparison already exists at output')
    atomic_json(manifest_path, identity)
    for variant in VARIANTS:
        (args.output/variant).mkdir(exist_ok=True)
    specs = list(cases(args.repeats, baseline['namespace']))
    if args.limit:
        specs = specs[:args.limit]
    start, completed = time.perf_counter(), 0
    print(f'OPENING COMPARISON: {len(specs)} pairs / {2*len(specs)} games; {args.workers} workers', flush=True)
    with ProcessPoolExecutor(max_workers=args.workers, mp_context=multiprocessing.get_context('spawn')) as pool:
        pending = {pool.submit(run_pair, spec, identity, str(args.output), str(args.baseline)) for spec in specs}
        while pending:
            done, pending = wait(pending, timeout=15, return_when=FIRST_COMPLETED)
            for future in done:
                result = future.result(); completed += 1
                print(f'PAIR {completed}/{len(specs)} elapsed={time.perf_counter()-start:.1f}s '+json.dumps(result), flush=True)
            if not done:
                print(f'RUNNING {completed}/{len(specs)} pairs elapsed={time.perf_counter()-start:.1f}s', flush=True)
    records = {v:[read_result(args.output/v/(s['name']+'.json.gz'),identity,s,v) for s in specs] for v in VARIANTS}
    result = dict(manifest=identity, repeats=args.repeats, requested_pairs=len(specs),
        results={v:summary(records[v]) for v in VARIANTS}, comparison=compare(records),
        invocation_seconds=time.perf_counter()-start)
    result['results_sha256'] = fingerprint(dict(results=result['results'],comparison=result['comparison']))
    atomic_json(args.output/'summary.json', result)
    print('COMPARISON COMPLETE '+json.dumps(result['results'],sort_keys=True),flush=True)
    return int(any(result['results'][v]['failed'] for v in VARIANTS))


if __name__ == '__main__':
    raise SystemExit(main())
