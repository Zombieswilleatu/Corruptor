"""Rites must reach whole-plan judgment without turning shared Veil into a veto."""
import unittest

from u13_pysim import full_match_inputs
from .budget import Limits
from .common import CommonSmartCore
from .diagnostics import fingerprint
from .facts import Facts
from .observation import observe, Preview
from .planner_probe import PlannerObserver
from .rite_cases import prepared_case
from .veil_judgment import settlement_projection


class RitePlanTests(unittest.TestCase):
    def decision(self, game, **kwargs):
        before = game.snapshot()
        result = CommonSmartCore(**kwargs).decide(observe(game, 0), Preview(game, 0))
        self.assertEqual(before, game.snapshot())
        self.assertEqual('legal', Preview(game, 0)(result['plan'])['action'])
        self.assertLessEqual(result['budget']['used']['complete_plans'], 32)
        self.assertLessEqual(result['budget']['used']['previews'], 8)
        return result

    def test_zero_and_negative_material_rites_can_be_chosen_for_settlement(self):
        for values in ((5, 3, 3), (5, 5, 2)):
            with self.subTest(values=values):
                game = prepared_case('win', values)
                result = self.decision(game)
                candidate = next(c for c in result['retained_candidates'] if c['term'] == 'Invocation')
                self.assertLessEqual(candidate['score'], 0)
                stats = result['rite_plans']['Invocation']
                self.assertGreaterEqual(stats['scored_plans'], 2)
                self.assertGreater(stats['current_board_wins'], 0)
                self.assertTrue(stats['selected'])
                self.assertEqual(dict(winner=0, win_by='Dominion'), result['veil']['paid_choice_scenario'])
                submitted = game.apply(dict(kind='submit', plans=[result['plan'], dict(powers=[], order={})]))
                self.assertNotEqual('invalid', submitted['action'])
                while game.outcome()['winner'] == -1 and game.clock.round == 1:
                    self.assertNotEqual('invalid', game.apply(full_match_inputs.next_operation(game))['action'])
                self.assertEqual((0, 'Dominion'), (game.outcome()['winner'], game.outcome()['win_by']))

    def test_hold_and_enemy_win_rites_are_scored_without_being_forced(self):
        for name in ('hold', 'enemy_win', 'already_winning'):
            with self.subTest(name=name):
                result = self.decision(prepared_case(name))
                stats = result['rite_plans']['Invocation']
                self.assertGreaterEqual(stats['scored_plans'], 2)
                self.assertFalse(stats['selected'])
                if name == 'enemy_win': self.assertGreater(stats['current_board_losses'], 0)
                self.assertNotIn('invocation', result['plan']['order'].get('rites', {}))
                row = next(a for a in result['assessments'] if a['term'] == 'Invocation')
                self.assertEqual('complete_plan_score', row['reason'])
                self.assertFalse(result['veil']['hard_veto'])

    def test_rite_reserves_a_plan_before_ordinary_bundles_fill_a_small_budget(self):
        result = self.decision(prepared_case('win'), limits=Limits(complete_plans=2))
        self.assertEqual(2, result['budget']['used']['complete_plans'])
        self.assertTrue(result['rite_plans']['Invocation']['selected'])
        self.assertEqual(1, result['rite_plans']['Invocation']['scored_plans'])

    def test_once_spent_invocation_is_not_proposed_again(self):
        game = prepared_case('win')
        game._state['world']['data']['dominion_rites']['invocation_rounds'][0] = 1
        result = self.decision(game)
        self.assertEqual(0, result['rite_plans']['Invocation']['scored_plans'])
        self.assertNotIn('invocation', result['plan']['order'].get('rites', {}))

    def test_static_win_is_labeled_uncertain_and_respects_ritual_precedence(self):
        game = prepared_case('win'); view = observe(game, 0)
        result = self.decision(game)
        self.assertFalse(result['veil']['hard_veto'])
        self.assertEqual('hidden_orders_prevent_proof', result['veil']['reason'])
        view['players'][1]['resources']['souls'] = 12
        self.assertEqual(dict(winner=1, win_by='Ritual'), settlement_projection(Facts(view), result['plan']))

    def test_observer_records_actual_policy_ids_and_plan_scoring_denominators(self):
        game = prepared_case('hold'); result = self.decision(game)
        spec = dict(name='rite_observer', setup=dict(lords=['Odradek', 'Gremory']))
        observer = PlannerObserver(spec, ['candidate', 'baseline'])
        observer.accepted(1, 0, result)
        report = observer.report()
        row = next(x for x in report['groups'] if x['category'] == 'rites' and x['term'] == 'Invocation')
        self.assertEqual('candidate', row['policy_id'])
        self.assertEqual(1, report['rite_planning']['Invocation:measured_decisions'])
        self.assertEqual(result['rite_plans']['Invocation']['scored_plans'], report['rite_planning']['Invocation:scored_plans'])
        self.assertEqual(fingerprint(result), fingerprint(self.decision(game)))


if __name__ == '__main__': unittest.main()
