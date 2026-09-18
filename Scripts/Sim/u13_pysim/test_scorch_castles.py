"""Castle-cycle semantics plus strict native/Python directed input generation."""
import unittest
from .scorch_castle_cases import generate

class CastleScorchTests(unittest.TestCase):
    def test_single_castle_cycles_switching_cooldown_and_source_lifetime(self):
        cases=generate()['cases']
        self.assertEqual(7,len(cases))
        self.assertEqual([4,6,6,2,3,0,4], [sum(c['castle_damage_by_round']) for c in cases])
