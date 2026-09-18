"""Selection contracts: default stability, bounded legality, independent replay."""
from collections import Counter
import random
import unittest
from unittest.mock import patch

from u13_pysim.copying import copy_data
from .budget import Budget, Limits
from .common import CommonSmartCore, VERSION as POLICY
from .observation import observe, Preview
from .planner_probe import PlannerObserver
from .rite_cases import prepared_case
from .selection import PlanSelector, SelectionSettings


def candidates(scores):
    return [dict(score=score, plan=dict(id=i)) for i, score in enumerate(scores)]


class SelectionTests(unittest.TestCase):
    def test_zero_temperature_preserves_first_legal_tie_and_preview_work(self):
        rows = candidates([100, 100, 90]); calls = []
        def preview(plan):
            calls.append(plan['id'])
            return dict(action='invalid' if plan['id'] == 0 else 'legal')
        budget = Budget()
        with patch('u13_doctrine.selection.math.exp', side_effect=AssertionError('greedy softmax')):
            chosen, rejected, trace = PlanSelector().select(rows, preview, budget, round_number=1, seat=0)
        self.assertIs(rows[1], chosen)
        self.assertEqual([0, 1], calls)
        self.assertEqual(1, len(rejected))
        self.assertEqual(2, budget.report()['used']['previews'])
        self.assertEqual((2, 2, 0), (trace['best_legal_rank'], trace['chosen_rank'], trace['score_gap']))
        self.assertIsNone(trace['draw_uint53'])
        self.assertEqual('', PlanSelector(SelectionSettings(0, 500, 'unused')).policy_suffix)

    def test_softmax_pool_excludes_illegal_and_outside_gap_plans(self):
        rows = candidates([110, 100, 99, 98, 70]); before = copy_data(rows); calls = []
        def preview(plan):
            index = plan.pop('id'); calls.append(index)
            return dict(action='invalid' if index in (0, 2) else 'legal')
        config = SelectionSettings(10, 2, 'pool-contract')
        chosen, rejected, trace = PlanSelector(config).select(rows, preview, Budget(), round_number=2, seat=1)
        self.assertEqual([0, 1, 2, 3], calls)
        self.assertEqual([2, 4], [x['rank'] for x in trace['legal_pool']])
        self.assertIn(chosen, [rows[1], rows[3]])
        self.assertEqual(2, len(rejected))
        self.assertEqual(before, rows)
        self.assertLessEqual(trace['score_gap'], 2)

    def test_preview_cap_keeps_legal_fallback_and_reports_truncation(self):
        rows = candidates([100, 99, 98, 97]); calls = []
        def preview(plan):
            calls.append(plan['id']); return dict(action='legal')
        budget = Budget(Limits(previews=2))
        chosen, _, trace = PlanSelector(SelectionSettings(10, 20, 'cap')).select(
            rows, preview, budget, round_number=1, seat=0)
        self.assertEqual([0, 1], calls)
        self.assertIn(chosen, rows[:2])
        self.assertTrue(trace['pool_truncated'])
        self.assertEqual(2, budget.report()['used']['previews'])
        with self.assertRaisesRegex(ValueError, 'No admitted plan'):
            PlanSelector().select(rows, lambda p:dict(action='invalid'), Budget(Limits(previews=2)), round_number=1, seat=0)

    def test_seeded_choices_repeat_across_call_order_without_using_global_rng(self):
        rows = candidates([100, 100, 99]); selector = PlanSelector(SelectionSettings(2, 2, 'independent-policy'))
        legal = lambda p:dict(action='legal')
        before = random.getstate()
        first = selector.select(rows, legal, Budget(), round_number=7, seat=0)
        other_seat = selector.select(rows, legal, Budget(), round_number=7, seat=1)
        other_round = selector.select(rows, legal, Budget(), round_number=8, seat=0)
        repeated = selector.select(rows, legal, Budget(), round_number=7, seat=0)
        self.assertEqual(first, repeated)
        self.assertEqual(before, random.getstate())
        self.assertEqual(3, len({x[2]['draw_key_sha256'] for x in (first, other_seat, other_round)}))
        self.assertTrue(0 <= first[2]['draw_uint53'] < 1 << 53)
        changed_seed = PlanSelector(SelectionSettings(2, 2, 'other-policy'))
        other = changed_seed.select(rows, legal, Budget(), round_number=7, seat=0)
        self.assertNotEqual(first[2]['draw_key_sha256'], other[2]['draw_key_sha256'])
        self.assertEqual(selector.policy_suffix, changed_seed.policy_suffix)

    def test_softmax_weights_are_stable_and_sample_competitive_alternatives(self):
        rows = candidates([1000000, 1000000, 999000]); counts = Counter()
        for seed in range(128):
            selector = PlanSelector(SelectionSettings(1, 1000, str(seed)))
            chosen, _, trace = selector.select(rows, lambda p:dict(action='legal'), Budget(), round_number=1, seat=0)
            counts[chosen['plan']['id']] += 1
            self.assertEqual(0, trace['score_gap'])
        self.assertEqual({0, 1}, set(counts))
        self.assertTrue(all(30 < n < 98 for n in counts.values()))

    def test_fixed_draw_and_choice_vectors_for_cross_runtime_replay(self):
        rows = candidates([100, 99, 96])
        selector = PlanSelector(SelectionSettings(2, 4, 'selector-vector'))
        vectors = ((0, 1, 0, 3943365002308912), (0, 2, 1, 8131265051549902),
                   (1, 1, 1, 7209499939280478), (1, 2, 0, 1080969604697828))
        for seat, number, expected, draw in vectors:
            with self.subTest(seat=seat, round=number):
                chosen, _, trace = selector.select(rows, lambda p:dict(action='legal'), Budget(),
                    round_number=number, seat=seat)
                self.assertEqual((expected, draw), (chosen['plan']['id'], trace['draw_uint53']))

    def test_invalid_settings_fail_before_any_decision(self):
        for name in ('temperature', 'max_score_gap'):
            for value in (-1, float('nan'), float('inf'), True, '1', 10**1000):
                with self.subTest(name=name, value=value), self.assertRaises(ValueError):
                    SelectionSettings(**{name:value})
        with self.assertRaises(ValueError): SelectionSettings(temperature=1)
        with self.assertRaises(ValueError): SelectionSettings(policy_seed=42)

    def test_softmax_observation_cannot_read_hidden_seed_or_mutate_match(self):
        game = prepared_case('win'); view = observe(game, 0); before = game.snapshot()
        policy = CommonSmartCore(selector=PlanSelector(SelectionSettings(10, 30, 'public-selector-test')))
        decision = policy.decide(view, Preview(game, 0))
        self.assertEqual(before, game.snapshot())
        self.assertEqual('legal', Preview(game, 0)(decision['plan'])['action'])
        self.assertLessEqual(decision['budget']['used']['previews'], 8)
        self.assertNotEqual(POLICY, decision['policy'])
        game._state['seed'] = 'changed-private-engine-seed'
        game._state['world']['data']['card_zones']['deck'].reverse()
        game._state['submissions'][1] = [dict(hidden_order='changed')]
        self.assertEqual(view, observe(game, 0))
        self.assertEqual(decision, policy.decide(observe(game, 0), Preview(game, 0)))

    def test_observer_distinguishes_selection_downgrades_and_missing_measurements(self):
        spec = dict(name='selector-observer', setup=dict(lords=['Odradek', 'Gremory']))
        observer = PlannerObserver(spec)
        self.assertIsNone(observer.report()['plan_selection']['max_score_gap'])
        game = prepared_case('win'); decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        # Exercise the passive observer with a known non-best selector record.
        decision['selection'].update(mode='softmax', chosen_rank=3, score_gap=7, draw_uint53=1, pool_truncated=True)
        observer.accepted(1, 0, decision)
        result = observer.report()['plan_selection']
        self.assertEqual(1, result['counts']['below_best_legal_score'])
        self.assertEqual(1, result['counts']['random_draws'])
        self.assertEqual(7, result['max_score_gap'])
        self.assertEqual(decision['selection'], observer.report()['decision_examples'][0]['selection'])


if __name__ == '__main__': unittest.main()
