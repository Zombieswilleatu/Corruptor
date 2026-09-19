"""Decision contrasts for plan-aware Rout; engine continuations live in evidence."""
import unittest

from u13_pysim import economy, power_components, recruitment
from u13_pysim.copying import copy_data
from .common import CommonSmartCore
from .coordination import context
from .facts import Facts
from .lords.deimos import rout_value
from .observation import observe, Preview
from .rout_answers import evaluate
from .test_common import planning
from .test_recipes_veil import hand


def unit(view, identity, seat, x, suit='Butcher', **attrs):
    a = recruitment.profile(suit, 'Castle', seat, 0, 1)
    a.update(x_fp=x, **attrs)
    row = dict(id=identity, kind='marcher', owner=seat, attributes=a)
    view['board'].append(row)
    return row


def answer(view, order=None):
    f = Facts(view)
    return evaluate(f, 'Castle', context(f, dict(powers=[], order=order or {})), rout_value(f, 'Castle'))


class RoutAnswerTests(unittest.TestCase):
    def test_large_existing_answer_saves_rout_but_wounded_line_does_not(self):
        view = observe(planning('Deimos'), 0)
        own = [unit(view, 'own:'+str(i), 0, 900) for i in range(6)]
        for i in range(3): unit(view, 'enemy:'+str(i), 1, 1000)
        self.assertEqual('material_edge', answer(view)['answer'])
        self.assertEqual(0, answer(view)['score'])
        for row in own: row['attributes'].update(hp=1, armor=0, attack=1)
        result = answer(view)
        self.assertEqual(result['baseline_score'], result['score'])

    def test_committed_recruits_answer_gate_only_in_their_actual_lane(self):
        view = observe(planning('Deimos'), 0)
        hand(view, [('Butcher', 8)])
        unit(view, 'enemy', 1, 100)
        ward = dict(action='Ward', lane='Castle', card_ids=['ingredient:0'])
        here = answer(view, ward)
        elsewhere = answer(view, dict(ward, lane='Lord'))
        self.assertEqual((4, 4, 0), (here['planned_bodies'], here['planned_in_reach'], here['score']))
        self.assertEqual((0, 14), (elsewhere['planned_bodies'], elsewhere['score']))
        self.assertEqual(14, answer(view)['score'])  # Merely holding cards is not an answer.

    def test_next_round_reinforcements_do_not_erase_current_pressure(self):
        view = observe(planning('Deimos'), 0)
        hand(view, [('Butcher', 12)])
        unit(view, 'ally', 0, 400)
        for i in range(4): unit(view, 'enemy:'+str(i), 1, 1000)
        value = answer(view, dict(action='Ward', lane='Castle', card_ids=['ingredient:0']))
        self.assertEqual((6, 0, 6), (value['planned_bodies'], value['planned_in_reach'], value['reserves_next_round']))
        self.assertEqual(value['baseline_score'], value['score'])

    def test_spent_hidden_and_passed_defenders_are_not_an_answer(self):
        view = observe(planning('Deimos'), 0)
        unit(view, 'enemy', 1, 300)
        unit(view, 'hidden', 0, 200, hidden=True)
        unit(view, 'passed', 0, 1800)
        unit(view, 'spent', 0, 200, waiting=True)
        value = answer(view, dict(rites=dict(waiter_spends=[dict(lane='Castle', marcher_ids=['spent'])])))
        self.assertEqual((0, 1, 14), (value['defenders_now'], value['consumed_excluded'], value['score']))

    def test_estimate_is_permutation_and_seat_symmetric(self):
        view = observe(planning('Deimos'), 0)
        unit(view, 'ally', 0, 800, suit='Penitent')
        unit(view, 'enemy', 1, 1200, suit='Vulture')
        expected = answer(view)
        mirrored = copy_data(view); mirrored['player_id'] = 1
        for row in mirrored['board']:
            if row['owner'] in (0, 1): row['owner'] = 1-row['owner']
            if row['kind'] == 'marcher': row['attributes']['x_fp'] = 2400-row['attributes']['x_fp']
        mirrored['board'].reverse()
        self.assertEqual(expected, answer(mirrored))

    def test_decisions_hold_answered_wave_and_cast_overwhelming_wave_legally(self):
        for ours, theirs, expected in ((8, 2, False), (2, 8, True)):
            with self.subTest(ours=ours, theirs=theirs):
                game = planning('Deimos')
                changes = [dict(kind='fixture_marcher', player_id=p, lane='Castle',
                    origin='rout_answer', ordinal=20*p+i, suit='Butcher',
                    attributes=dict(x_fp=900 if p == 0 else 1100, y_fp=60+60*i))
                    for p, count in ((0, ours), (1, theirs)) for i in range(count)]
                power_components.prepare(game, changes)
                before = game.snapshot(); view = observe(game, 0)
                result = CommonSmartCore().decide(view, Preview(game, 0))
                self.assertEqual(expected, any(s['power_id'] == 'Rout' for s in result['plan']['powers']))
                self.assertEqual([], result['rejected_previews'])
                self.assertEqual(before, game.snapshot())
                for key, used in result['budget']['used'].items():
                    limit = 16 if key.startswith('generated:') else 4 if key.startswith('retained:') else 32 if key == 'complete_plans' else 8
                    self.assertLessEqual(used, limit)

    def test_candidate_ignores_opponent_hand_sealed_orders_and_rng(self):
        game = planning('Deimos')
        power_components.prepare(game, [dict(kind='fixture_marcher', player_id=1, lane='Castle',
            origin='rout_secret', ordinal=0, attributes=dict(x_fp=100))])
        view = observe(game, 0)
        expected = CommonSmartCore().decide(view, Preview(game, 0))
        game._state['seed'] = 'not available to the policy'
        game._state['submissions'][1] = [dict(secret='orders')]
        game._state['world']['data']['card_zones']['deck'].reverse()
        for identity in economy.zones(game._state['world'])['hands'][1]:
            economy.entity(game._state['world'], identity)['attributes']['value'] = 1
        self.assertEqual(view, observe(game, 0))
        view['hand'].reverse(); view['board'].reverse()
        self.assertEqual(expected, CommonSmartCore().decide(view, Preview(game, 0)))
