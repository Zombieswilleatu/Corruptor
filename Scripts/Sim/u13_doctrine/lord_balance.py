"""Descriptive Lord matchup screening; bot strength and game balance interact."""
from collections import Counter
from statistics import mean

from u13_pysim.opening import LORDS

NAMESPACE = 'u13-combined-v27-lord-balance-2026-09-21'


def summarize(records):
    results = {lord: dict(games=0, wins=0, losses=0, unresolved=0, rounds=[],
                         seats={str(s): dict(games=0, wins=0) for s in (0, 1)},
                         decisions=0, powers=Counter(), march_commands=0,
                         reserve_body_decisions=0, rejected_previews=0) for lord in LORDS}
    matchups, wins_by, seat_wins = {}, Counter(), Counter()
    mirrors, failures = [], []
    for record in records:
        spec = record['spec']; left, right = spec['setup']['lords']
        if record['status'] != 'complete':
            failures.append(dict(name=spec['name'], error=record.get('error')))
            continue
        game = record['semantic']; winner = game['outcome']['winner']
        if winner not in (-1, 0, 1): raise ValueError('Unknown winner: '+str(winner))
        if left == right:
            mirrors.append(dict(lord=left, winner=winner, rounds=game['rounds'],
                                win_by=game['outcome'].get('win_by')))
        else:
            if winner != -1:
                seat_wins[str(winner)] += 1
                wins_by[game['outcome'].get('win_by', 'unknown')] += 1
            for seat, lord in enumerate((left, right)):
                row = results[lord]
                row['games'] += 1; row['rounds'].append(game['rounds'])
                row['seats'][str(seat)]['games'] += 1
                row['wins'] += winner == seat
                row['losses'] += winner == 1-seat
                row['unresolved'] += winner == -1
                row['seats'][str(seat)]['wins'] += winner == seat
                key = lord + ':' + (right if seat == 0 else left)
                cell = matchups.setdefault(key, dict(games=0, wins=0, unresolved=0))
                cell['games'] += 1; cell['wins'] += winner == seat; cell['unresolved'] += winner == -1
        # Behavioral diagnostics include mirrors; win-rate denominators do not.
        for entry in record.get('trace', []):
            view, decision = entry['view'], entry['decision']
            row = results[spec['setup']['lords'][view['player_id']]]
            row['decisions'] += 1
            row['powers'].update(p['power_id'] for p in decision['plan']['powers'])
            row['march_commands'] += list(decision['plan']['order'].get('staging', {}).values()).count('March')
            row['reserve_body_decisions'] += sum(len(t['units']) for t in view['data'].get('game_staging', {}).get('lanes', {}).values())
            row['rejected_previews'] += len(decision.get('rejected_previews', []))
    for row in results.values():
        row['mean_rounds'] = round(mean(row.pop('rounds')), 2) if row['games'] else None
        row['win_rate'] = row['wins']/row['games'] if row['games'] else None
        row['powers'] = dict(row['powers'])
    return dict(scope='Initial self-play balance screen, not a strength ranking or balance verdict. Non-mirror results only in win rates; behavior includes mirrors. Failed/capped games are excluded and listed.',
                lords=results, matchups=matchups, mirrors=mirrors, failures=failures,
                non_mirror_seat_wins=dict(seat_wins), non_mirror_win_methods=dict(wins_by))


def markdown(report):
    lines = ['# Lord balance screen', '', report['scope'], '',
             '| Lord | Games | Wins | Losses | Unresolved | Win % | Mean rounds |',
             '| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
    for lord, row in report['lords'].items():
        rate = '—' if row['win_rate'] is None else f"{100*row['win_rate']:.1f}"
        lines.append(f"| {lord} | {row['games']} | {row['wins']} | {row['losses']} | {row['unresolved']} | {rate} | {row['mean_rounds']} |")
    lines += ['', '## Matchups', '', 'Each cell is row-Lord wins / games across both seats. Mirrors are separate.', '',
              '| Lord | '+' | '.join(LORDS)+' |', '| --- | '+' | '.join(['---:']*len(LORDS))+' |']
    for lord in LORDS:
        cells = []
        for enemy in LORDS:
            row = report['matchups'].get(lord+':'+enemy)
            cells.append('—' if row is None else f"{row['wins']}/{row['games']}")
        lines.append('| '+lord+' | '+' | '.join(cells)+' |')
    lines += ['', f"Mirror games: {len(report['mirrors'])}. Failed/capped games: {len(report['failures'])}.", '',
              '## Behavior', '', '| Lord | Decisions | MARCH commands | Rejected previews | Power casts |',
              '| --- | ---: | ---: | ---: | --- |']
    for lord, row in report['lords'].items():
        powers = ', '.join(f'{k}: {v}' for k,v in sorted(row['powers'].items())) or 'None'
        lines.append(f"| {lord} | {row['decisions']} | {row['march_commands']} | {row['rejected_previews']} | {powers} |")
    if report['failures']:
        lines += ['', 'Failed/capped cases: '+', '.join(r['name'] for r in report['failures'])]
    return '\n'.join(lines)+'\n'
