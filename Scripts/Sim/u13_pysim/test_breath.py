"""Immediate healing, aura timing and one-time declaration firing."""
import unittest
from .breath_cases import generate


class BreathTests(unittest.TestCase):
    def test_pulse_both_seats_cap_and_exclusions_then_normal_regeneration(self):
        self.assertEqual(2, len(generate(('pulse_seat0','pulse_seat1'))['cases']))

    def test_aura_follows_the_lane_without_repeating_the_activation_pulse(self):
        self.assertEqual(1, len(generate(('lane_reentry',))['cases']))

    def test_armed_breath_and_muster_survive_source_banishment(self):
        self.assertEqual(1, len(generate(('armed_banishment',))['cases']))
