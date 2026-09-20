"""Bounded mechanics regressions; no doctrine or balance matches."""
import unittest

from . import incoming_damage as incoming, marching, marching_fixtures as fixtures
from .marching_columns import Columns
from .power_rules import RULES


class RoutDamageTests(unittest.TestCase):
    def test_retreat_round_only_and_positive_regular_hits(self):
        self.assertEqual(1, RULES['Rout']['retreat_regular_attack_bonus'])
        for clock in (399, 400, 599, 600, 799, 800):
            for base in (0, 3):
                with self.subTest(clock=clock, base=base):
                    bonus = int(base > 0 and 400 <= clock < 600)
                    self.assertEqual(base + bonus, incoming.regular_amount({'rout_round': 2}, base, clock))
                    self.assertEqual(base, incoming.amount({'rout_round': 2}, base, clock))
                    self.assertEqual(base, incoming.regular_amount({}, base, clock))

    def test_exposure_remains_independent(self):
        attributes = dict(rout_round=2, dotra_exposed_from_tick=450, dotra_exposed_until_tick=650)
        for clock, regular, packet in ((400, 4, 3), (450, 5, 4), (599, 5, 4), (600, 4, 4), (650, 3, 3)):
            with self.subTest(clock=clock):
                self.assertEqual(regular, incoming.regular_amount(attributes, 3, clock))
                self.assertEqual(packet, incoming.amount(attributes, 3, clock))

    def test_legacy_melee_reads_compact_rout_column_before_armor(self):
        spec = fixtures.load()['cases'][0]
        for applied in (None, 1, 2):
            for bypass in (False, True):
                with self.subTest(applied=applied, bypass=bypass):
                    columns = Columns(fixtures.initial(spec)['entities'])
                    columns.rout_round[0] = applied
                    columns.armor[0], columns.hp[0] = 3, 100
                    amount = 3 + int(applied == 2)
                    dealt = marching.attack(columns, 0, 3, bypass, 400)
                    self.assertEqual(amount if bypass else amount - 3, dealt)
                    self.assertEqual(3 if bypass else 0, columns.armor[0])
                    self.assertEqual(100 - dealt, columns.hp[0])


if __name__ == '__main__':
    unittest.main()
