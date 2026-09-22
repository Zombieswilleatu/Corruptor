"""Check screening denominators without running a balance campaign."""
import unittest

from .lord_balance import summarize, markdown, NAMESPACE
from .survey import cases


def record(left, right, winner, rounds=12):
    return dict(spec=dict(name=left+right, setup=dict(lords=[left, right])), status='complete',
                semantic=dict(rounds=rounds, outcome=dict(winner=winner, win_by='FinalCollapse')), trace=[])


class LordBalanceTests(unittest.TestCase):
    def test_mirrors_and_failed_games_do_not_inflate_win_rates(self):
        rows = [record('Gremory', 'Deimos', 0, 10), record('Deimos', 'Gremory', 1, 14),
                record('Gremory', 'Gremory', 0), record('Gremory', 'Humbaba', -1)]
        failed = record('Humbaba', 'Gremory', 0)
        failed.update(status='failed', semantic={}, error='round cap reached')
        result = summarize(rows+[failed])
        g = result['lords']['Gremory']
        self.assertEqual((3, 2, 0, 1), (g['games'], g['wins'], g['losses'], g['unresolved']))
        self.assertEqual(2/3, g['win_rate'])
        self.assertEqual(12, g['mean_rounds'])
        self.assertEqual(dict(games=2, wins=2, unresolved=0), result['matchups']['Gremory:Deimos'])
        self.assertEqual(dict(games=2, wins=0, unresolved=0), result['matchups']['Deimos:Gremory'])
        self.assertEqual({'0': 1, '1': 1}, result['non_mirror_seat_wins'])
        self.assertEqual(1, len(result['mirrors']))
        self.assertEqual(1, len(result['failures']))
        self.assertIsNone(result['lords']['Valak']['win_rate'])
        self.assertIn('Failed/capped games: 1', markdown(result))

    def test_first_pass_covers_all_lords_both_seats_with_shared_reverse_seeds(self):
        specs = list(cases(1, NAMESPACE))
        self.assertEqual(81, len(specs))
        by_pair = {tuple(s['setup']['lords']): s for s in specs}
        self.assertEqual(81, len(by_pair))
        for pair, spec in by_pair.items():
            self.assertEqual(spec['setup']['seed'], by_pair[pair[::-1]]['setup']['seed'])

    def test_behavior_records_powers_reserves_and_rejected_proposals(self):
        row = record('Gremory', 'Deimos', 0)
        row['trace'] = [dict(view=dict(player_id=0, data=dict(game_staging=dict(lanes=dict(Lord=dict(units=[{}, {}]))))),
            decision=dict(plan=dict(powers=[dict(power_id='InevitableRuin')], order=dict(staging=dict(Lord='March'))),
                          rejected_previews=[dict(reason='fixture')]))]
        result = summarize([row])['lords']['Gremory']
        self.assertEqual((1, 1, 2, 1), (result['decisions'], result['march_commands'], result['reserve_body_decisions'], result['rejected_previews']))
        self.assertEqual({'InevitableRuin': 1}, result['powers'])


if __name__ == '__main__': unittest.main()
