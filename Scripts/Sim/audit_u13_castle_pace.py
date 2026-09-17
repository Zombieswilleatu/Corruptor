#!/usr/bin/env python3
"""Replay one seed across all 81 matchups for exact castle-loss timing."""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, as_completed
import json
import multiprocessing
from pathlib import Path
import statistics

from u13_doctrine.survey import cases, read_record, atomic_json
from u13_pysim.power_match import PowerMatch
from u13_pysim.benchmark_full_match import digest
from u13_pysim.verify import source_identity


def replay(task):
    directory, spec, identity = task
    record = read_record(Path(directory)/'games'/(spec['name']+'.json.gz'), identity, spec)
    if record['status'] != 'complete': raise ValueError('Incomplete source game')
    game = PowerMatch(spec['setup']); cursor = 0; losses = []
    siege_attempts = Counter(); siege_rounds = {}; harmful_events = Counter()
    for op in record['operations']:
        result = game.apply(op)
        if result['action'] == 'invalid': raise ValueError(result)
        rows = game._state['events']['rows']
        for row in rows[cursor:]:
            e = row['event']; kind, d = e['type'], e['data']
            if kind == 'SIEGE_RESOLVED' and not d.get('pillage', False):
                siege_attempts[d['target_id']] += 1
                siege_rounds.setdefault(d['target_id'], []).append(d['round'])
            if kind == 'CASTLE_DESTROYED':
                castle = d['castle']; cause = d['cause']
                # Hunt destruction uses the general default cause "siege";
                # distinguish its authoritative command ID explicitly.
                if d['event_id'].startswith('hunt:'): cause = 'hunt_keep'
                losses.append(dict(round=d['round'], castle_id=castle['id'], owner=castle['owner'],
                    castle_type=castle['attributes']['castle_type'], cause=cause, hook=d['hook'],
                    ever_commissioned=castle['attributes']['construction_state'] == 'active'))
            elif kind == 'CASTLE_RUINED':
                losses.append(dict(round=d['round'], castle_id=d['castle_id'], owner=d['player_id'],
                                   cause=d['cause'], hook=game.clock.hook))
            if kind in ('CASTLE_DAMAGED', 'CASTLE_CEILING_CHANGED', 'CASTLE_DEFUNCT'):
                harmful_events[kind] += 1
        cursor = len(rows)
    final = digest(game)
    if final != record['semantic']['final_state_sha256']: raise ValueError('Replay final digest mismatch: '+spec['name'])
    castles = [r for r in game._state['world']['entities']['entities'] if r['kind'] == 'castle']
    by_seat = [[r for r in castles if r['owner'] == seat] for seat in (0,1)]
    return dict(name=spec['name'], lords=spec['setup']['lords'], rounds=record['semantic']['rounds'],
        final_digest_matched=True, final_state_sha256=final, losses=losses,
        first_loss_round=min((r['round'] for r in losses), default=None),
        final_ruined=sum(r['attributes']['status'] == 'ruined' for r in castles),
        final_ruined_by_seat=[sum(r['attributes']['status'] == 'ruined' for r in group) for group in by_seat],
        final_statuses=[dict(id=r['id'], owner=r['owner'], **r['attributes']) for r in castles],
        siege_attempts=dict(siege_attempts), siege_rounds=siege_rounds, harmful_event_counts=harmful_events)


def summarize(games):
    # ProfaneRuins leaves a "profaned" row in the registry. Counting every row
    # other than "ruined" as a survivor would count these lost castles twice.
    for g in games:
        rows = g['final_statuses']
        g['final_profaned'] = sum(r['status'] == 'profaned' for r in rows)
        g['final_lost_by_seat'] = [sum(r['owner'] == seat and r['status'] in ('ruined', 'profaned') for r in rows) for seat in (0,1)]
        g['final_commissioned_survivors'] = sum(r['status'] in ('standing', 'defunct') and r['construction_state'] == 'active' for r in rows)
        g['final_construction'] = sum(r['status'] in ('standing', 'defunct') and r['construction_state'] != 'active' for r in rows)
        g['final_operational'] = sum(r['status'] == 'standing' and r['construction_state'] == 'active' and r['integrity'] >= 7 for r in rows)
    losses = [loss for g in games for loss in g['losses']]
    first = [g['first_loss_round'] for g in games if g['first_loss_round'] is not None]
    remaining = [g['final_commissioned_survivors'] for g in games]
    return dict(games=len(games), all_final_digests_matched=all(g['final_digest_matched'] for g in games),
        losses=len(losses), unique_castles_lost=sum(len({r['castle_id'] for r in g['losses']}) for g in games),
        cause_counts=Counter(r['cause'] for r in losses), loss_round_histogram=Counter(str(r['round']) for r in losses),
        first_loss_median=statistics.median(first) if first else None,
        first_loss_mean=statistics.mean(first) if first else None,
        first_loss_range=[min(first),max(first)] if first else None, games_without_loss=len(games)-len(first),
        games_with_first_loss_in_round_one=sum(r == 1 for r in first),
        final_ruined_mean=statistics.mean(g['final_ruined'] for g in games),
        final_profaned_mean=statistics.mean(g['final_profaned'] for g in games),
        final_commissioned_survivors_mean=statistics.mean(remaining),
        final_commissioned_survivors_histogram=Counter(remaining),
        final_construction_mean=statistics.mean(g['final_construction'] for g in games),
        final_operational_mean=statistics.mean(g['final_operational'] for g in games),
        games_with_a_seat_all_five_lost=sum(5 in g['final_lost_by_seat'] for g in games),
        siege_attempts=sum(sum(g['siege_attempts'].values()) for g in games))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--workers', type=int, default=8)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    identity = json.loads((args.directory/'manifest.json').read_text())
    if source_identity(Path(__file__).resolve().parents[2])[1] != identity['engine_source_sha256']:
        raise ValueError('Engine differs from the saved survey; use matching source for these replays.')
    specs = list(cases(1, identity['namespace'])); games = []
    with ProcessPoolExecutor(max_workers=args.workers, mp_context=multiprocessing.get_context('spawn')) as pool:
        futures = [pool.submit(replay, (str(args.directory), spec, identity)) for spec in specs]
        for future in as_completed(futures):
            game = future.result(); games.append(game)
            print('CASTLE REPLAY',len(games),'/81',game['name'],'first_loss',game['first_loss_round'],flush=True)
    games.sort(key=lambda g:g['name'])
    summary = summarize(games)
    atomic_json(args.output, dict(manifest=identity, sample='repeat 00: one exact replay per ordered matchup',
        summary=summary,games=games,limitations='Timing counts game rounds, not rounds of sustained pressure. Wish Prices are separate; rebuilds may create repeat losses. No pre-change control.'))
    print(json.dumps(summary,sort_keys=True),flush=True)


if __name__ == '__main__': main()
