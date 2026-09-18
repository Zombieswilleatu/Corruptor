"""Closing preferences use public information and remain subject to admission."""
import unittest

from u13_pysim import full_match_inputs, power_components
from u13_pysim.copying import copy_data
from .closing import judgment
from .common import CommonSmartCore, Weights
from .facts import Facts
from .observation import observe, Preview
from .rite_cases import prepared_case
from .veil_judgment import settlement_projection


def closing_game():
    game = prepared_case('win')
    power_components.prepare(game, [
        dict(kind='fixture_resources', player_id=1, resources=dict(personal_tears=2)),
        dict(kind='fixture_data', data=dict(neutral_tears=5))])
    return game


def invocation(view):
    return dict(powers=[], order=dict(rites=dict(invocation=dict(card_ids=[r['id'] for r in view['hand']]))))


class ClosingTests(unittest.TestCase):
    def test_closing_beats_large_material_weight_and_reaches_actual_dominion(self):
        game = closing_game(); before = game.snapshot()
        decision = CommonSmartCore(weights=Weights(recruit=10000)).decide(observe(game, 0), Preview(game, 0))
        self.assertEqual(before, game.snapshot())
        self.assertIn('invocation', decision['plan']['order']['rites'])
        self.assertEqual('resilient', decision['closing']['selected']['status'])
        self.assertGreater(decision['closing']['selected']['priority_bonus'], 70)
        self.assertLessEqual(decision['budget']['used']['complete_plans'], 32)
        self.assertLessEqual(decision['budget']['used']['previews'], 8)
        self.assertLessEqual(decision['closing']['checks'], 6*decision['closing']['plans'])
        op = dict(kind='submit', plans=[decision['plan'], dict(powers=[], order={})])
        self.assertNotEqual('invalid', game.apply(op)['action'])
        while not game.clock.completed:
            self.assertNotEqual('invalid', game.apply(full_match_inputs.next_operation(game))['action'])
        self.assertEqual((0, 'Dominion'), (game.outcome()['winner'], game.outcome()['win_by']))

    def test_enemy_ritual_reward_flags_fragility_without_discarding_closing_chance(self):
        game = closing_game()
        power_components.prepare(game, [dict(kind='fixture_resources', player_id=1, resources=dict(souls=9))])
        view = observe(game, 0); plan = invocation(view)
        self.assertEqual('legal', Preview(game, 0)(plan)['action'])
        projection = settlement_projection(Facts(view), plan)
        self.assertEqual(dict(winner=0, win_by='Dominion'), projection)
        stress = judgment(Facts(view), plan, projection)
        self.assertIn(dict(name='siege_reward', winner=1, win_by='Ritual'), stress['checks'])
        decision = CommonSmartCore().decide(view, Preview(game, 0))
        self.assertIn('invocation', decision['plan']['order']['rites'])
        self.assertEqual('fragile', decision['closing']['selected']['status'])
        self.assertEqual(70, decision['closing']['selected']['win_credit'])
        self.assertEqual(0, decision['closing']['selected']['priority_bonus'])
        self.assertGreater(decision['rite_plans']['Invocation']['scored_plans'], 0)
        self.assertFalse(decision['closing']['hard_veto'])

    def test_collapse_lead_is_sensitive_to_soul_margin_and_seat_zero_tie(self):
        view = observe(prepared_case('win'), 0)
        view['data']['neutral_tears'] = 17
        view['players'][1]['resources']['souls'] = 4
        for own, resilient in ((5, False), (7, True)):
            with self.subTest(souls=own):
                view['players'][0]['resources']['souls'] = own
                plan = invocation(view); projection = settlement_projection(Facts(view), plan)
                self.assertEqual(dict(winner=0, win_by='FinalCollapse'), projection)
                result = judgment(Facts(view), plan, projection)
                self.assertEqual(resilient, result['status'] == 'resilient')
        # Reverse the resource tie and perspective: equal Souls do not win p1.
        view['players'][0]['resources']['souls'] = 4
        view['players'][1]['resources']['souls'] = 7
        view['player_id'] = 1
        self.assertIn('siege_reward', judgment(Facts(view), invocation(view),
            dict(winner=1, win_by='FinalCollapse'))['adverse'])

    def test_one_enemy_tear_can_interrupt_dominion_without_proving_a_loss(self):
        view = observe(prepared_case('win'), 0); before = copy_data(view)
        plan = invocation(view); projection = settlement_projection(Facts(view), plan)
        result = judgment(Facts(view), plan, projection)
        self.assertEqual('fragile', result['status'])
        self.assertEqual([], result['adverse'])
        self.assertIn('tear', result['interrupted'])
        self.assertEqual(before, view)

    def test_banished_lord_does_not_disqualify_dominion_but_does_break_ritual(self):
        view = observe(closing_game(), 0)
        lord = next(r for r in view['board'] if r['kind'] == 'lord' and r['owner'] == 0)
        lord['attributes']['alive'] = False
        plan = invocation(view); f = Facts(view)
        self.assertEqual('resilient', judgment(f, plan, settlement_projection(f, plan))['status'])
        view['players'][0]['resources'].update(personal_tears=0, souls=12)
        view['players'][1]['resources']['personal_tears'] = 0
        lord['attributes']['alive'] = True
        plan = dict(powers=[], order={}); f = Facts(view)
        self.assertEqual('Ritual', settlement_projection(f, plan)['win_by'])
        self.assertIn('hunt_reward', judgment(f, plan, settlement_projection(f, plan))['interrupted'])

    def test_orias_mark_can_flip_a_collapse_that_survives_ordinary_hunt(self):
        view = observe(prepared_case('win'), 0)
        view['data']['neutral_tears'] = 17
        view['players'][0]['resources']['souls'] = 5
        view['players'][1]['resources']['souls'] = 1
        view['players'][1]['lord_id'] = 'Orias'
        for row in view['board']:
            if row['kind'] == 'lord':
                if row['owner'] == 0: row['attributes']['threat'] = 2
                else: row['attributes']['lord_id'] = 'Orias'
        f = Facts(view); plan = invocation(view)
        result = judgment(f, plan, settlement_projection(f, plan))
        self.assertNotIn('hunt_reward', result['adverse'])
        self.assertIn('tear_and_marked_hunt_reward', result['adverse'])
        self.assertEqual(6, len(result['checks']))

    def test_rejected_closing_plan_falls_back_without_spending_extra_preview_budget(self):
        game = closing_game(); authority = Preview(game, 0); before = game.snapshot()
        def preview(plan):
            if 'invocation' in plan['order'].get('rites', {}):
                return dict(action='invalid', reason='directed_admission_failure')
            return authority(plan)
        decision = CommonSmartCore().decide(observe(game, 0), preview)
        self.assertTrue(decision['rejected_previews'])
        self.assertEqual('legal', authority(decision['plan'])['action'])
        self.assertLessEqual(decision['budget']['used']['previews'], 8)
        self.assertEqual(before, game.snapshot())

    def test_profane_target_survival_is_conditional_even_when_shocks_leave_a_win(self):
        view = observe(closing_game(), 0)
        castle = next(r for r in view['board'] if r['kind'] == 'castle' and r['owner'] == 0
                      and r['attributes']['castle_type'] == 'Stockpile')
        plan = dict(powers=[], order=dict(action='Profane', lane='Castle', target_id=castle['id'], card_ids=[]))
        f = Facts(view); projection = settlement_projection(f, plan)
        self.assertEqual(0, projection['winner'])
        result = judgment(f, plan, projection)
        self.assertEqual([], result['adverse']); self.assertEqual([], result['interrupted'])
        self.assertEqual('fragile', result['status'])
        self.assertTrue(result['conditional_own_profane'])


if __name__ == '__main__': unittest.main()
