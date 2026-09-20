"""Admission checks for the focal-only matched experiment and event attribution."""
from dataclasses import asdict
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from .common import VERSION, Weights
from .comparison import freeze_baseline
from .orias_comparison import BASELINE, FocalPolicy, OriasObserver, aggregate, cases, metrics


class OriasComparisonTests(unittest.TestCase):
    def test_pairs_and_mirror_keep_identical_setups(self):
        specs = list(cases())
        self.assertEqual(72, len(specs))
        self.assertEqual(72, len({s['name'] for s in specs}))
        self.assertEqual(18, len({s['setup']['seed'] for s in specs}))
        self.assertEqual(36, len({s['pair_id'] for s in specs}))
        for old, new in zip(specs[::2], specs[1::2]):
            self.assertEqual(old['setup'], new['setup'])
            self.assertEqual(old['focal_seat'], new['focal_seat'])
            self.assertEqual(('old', 'new'), (old['variant'], new['variant']))
            self.assertEqual('Orias', old['setup']['lords'][old['focal_seat']])
        mirror = [s for s in specs if s['opponent'] == 'Orias']
        self.assertEqual(8, len(mirror))

    def test_routing_including_card_choices_and_mirror(self):
        root = Path(__file__).resolve().parents[3]
        with tempfile.TemporaryDirectory() as tmp:
            freeze_baseline(root, BASELINE, tmp)
            for spec in list(cases())[:4]:
                policy = FocalPolicy(tmp, spec, asdict(Weights()))
                for seat in (0, 1):
                    expected_new = spec['variant'] == 'new' and seat == spec['focal_seat']
                    self.assertEqual(expected_new, VERSION == policy.policy_ids[seat])
                    chosen = policy.policies[seat]
                    with patch.object(chosen, 'decide', return_value={'policy': policy.policy_ids[seat]}) as decide:
                        policy.decide({'player_id': seat}, None)
                        decide.assert_called_once()
                    with patch.object(chosen, 'choose_card', return_value={'seat': seat}) as choose:
                        self.assertEqual({'seat': seat}, policy.choose_card({'player_id': seat}, 'slaver'))
                        choose.assert_called_once()

    def test_failed_pair_is_explicit_not_a_loss(self):
        records = [dict(spec=s, semantic={}, status='failed', error='censored', wall_seconds=1) for s in list(cases())[:2]]
        result = aggregate(records)
        self.assertEqual((0, 2), (result['completed'], result['failed']))
        self.assertEqual(1, result['paired_results']['incomplete'])
        self.assertEqual(0, result['totals']['old']['wins'])

    def test_snare_followup_uses_activation_round_and_focal_seat(self):
        spec = next(cases())
        observer = OriasObserver(spec, ['old', 'old'])
        with patch('u13_doctrine.planner_probe.PlannerObserver.event'):
            for index, (seat, number) in enumerate(((0, 3), (1, 4))):
                observer.event(index, {'type': 'SNARE_ACTIVE', 'data': {'player_id': seat, 'round': number}}, number)
        self.assertEqual(1, len(observer.orias_events))
        observed = dict(events=observer.orias_events+[dict(type='HUNT_RESOLVED', round=3)],
                        orders=[dict(round=2, action='Ward'), dict(round=3, action='Hunt')])
        record = dict(spec=spec, trace=[], semantic=dict(diagnostics=dict(groups=[], orias_observed=observed)))
        counts = metrics(record)
        self.assertEqual(1, counts['snare_activations'])
        self.assertEqual(1, counts['snare_followup_selected'])
        self.assertEqual(1, counts['snare_followup_resolved'])

    def test_missing_combat_action_is_pass(self):
        observer = OriasObserver(next(cases()), ['old', 'old'])
        with patch('u13_doctrine.planner_probe.PlannerObserver.accepted'):
            observer.accepted(4, 0, dict(plan=dict(order={})))
        self.assertEqual([dict(round=4, action='Pass')], observer.orias_orders)

if __name__ == '__main__': unittest.main()
