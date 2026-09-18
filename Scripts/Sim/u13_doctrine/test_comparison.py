"""Check seat pairing and evidence denominators before policy comparisons."""
import unittest
from .comparison import aggregate, paired_cases


class ComparisonTests(unittest.TestCase):
    def test_every_matchup_has_both_policy_assignments_on_the_same_setup(self):
        specs = list(paired_cases(1, 'comparison-test'))
        self.assertEqual(162, len(specs))
        self.assertEqual(162, len({s['name'] for s in specs}))
        self.assertEqual(81, len({tuple(s['setup']['lords']) for s in specs}))
        for first, second in zip(specs[::2], specs[1::2]):
            self.assertEqual((0, 1), (first['candidate_seat'], second['candidate_seat']))
            self.assertEqual(first['setup'], second['setup'])
            self.assertEqual(first['pair_id'], second['pair_id'])

    def test_failed_games_are_neither_wins_nor_completed_pairs(self):
        spec = next(paired_cases(1, 'failed'))
        result = aggregate([dict(spec=spec, semantic={}, status='failed', error='censored')], 'new')
        self.assertEqual((1, 0, 1), (result['requested'], result['completed'], result['failed']))
        self.assertEqual({}, result['wins'])
        self.assertEqual([], result['rite_measurements'])
        self.assertEqual(1, result['paired_results']['incomplete'])

    def test_old_policy_unmeasured_plan_counts_remain_unknown(self):
        spec = next(paired_cases(1, 'old'))
        assessments = [dict(category='rites', term=t, generated=1, retained=1, selected=False)
                       for t in ('Supplicants', 'Invocation', 'ProfaneRuins')]
        decision = dict(policy='old', assessments=assessments, budget=dict(used=dict(complete_plans=4)))
        record = dict(spec=spec, status='complete', error=None,
            semantic=dict(outcome=dict(winner=1, win_by='Dominion'), rounds=5,
                          diagnostics=dict(rejected_previews=[], groups=[])),
            timing=dict(decision_ms=1, simulation_ms=2), trace=[dict(decision=decision)])
        result = aggregate([record], 'new')
        row = next(r for r in result['rite_measurements'] if r['term'] == 'Invocation')
        self.assertIsNone(row['scored_plans'])
        self.assertEqual(0, row['scored_measured_decisions'])
        self.assertEqual(1, row['generated'])
        self.assertEqual(1, result['wins']['baseline'])
        self.assertEqual(1, result['paired_results']['incomplete'])


if __name__ == '__main__': unittest.main()
