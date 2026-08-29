import unittest

import corruptor_sim as sim


class OdradekInterlockNoSoulTests(unittest.TestCase):
    def setUp(self):
        self.variant_before = dict(sim.VARIANT)
        self.features_before = dict(sim.ACTIVE_FEATURES)
        self.ruleset_before = getattr(sim, "ACTIVE_RULESET", None)
        if hasattr(sim, "activate_ruleset"):
            sim.activate_ruleset("lab-v6.5")

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant_before)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features_before)
        if self.ruleset_before is not None:
            sim.ACTIVE_RULESET = self.ruleset_before

    @staticmethod
    def card(suit, value):
        return sim.Card(suit, value)

    def fixture(self):
        game = sim.Game(["Deimos"], ["Odradek"], seed=77331)
        attacker, odradek = game.players
        attacker.lord = "Deimos"
        attacker.alive = True
        odradek.lord = "Odradek"
        odradek.alive = True
        odradek.odradek_recoil_done = False
        odradek.odradek_bank = None
        return game, attacker, odradek

    def test_successful_recoil_banks_card_but_grants_no_soul(self):
        game, attacker, odradek = self.fixture()
        high = self.card("Butcher", 5)
        second = self.card("Wright", 4)
        low = self.card("Vulture", 2)
        attacker.committed = [high, second, low]
        souls_before = odradek.souls

        result = game._odradek_recoil(attacker, odradek)

        self.assertTrue(result["fired"])
        self.assertTrue(odradek.odradek_recoil_done)
        self.assertIs(odradek.odradek_bank, second)
        self.assertNotIn(second, attacker.committed)
        self.assertEqual(odradek.souls, souls_before)
        self.assertEqual(result["soul_gain"], 0)

    def test_higher_replacement_still_works_without_soul(self):
        game, attacker, odradek = self.fixture()
        old_bank = self.card("Penitent", 2)
        odradek.odradek_bank = old_bank
        high = self.card("Butcher", 5)
        replacement = self.card("Wright", 4)
        attacker.committed = [high, replacement]
        souls_before = odradek.souls

        result = game._odradek_recoil(attacker, odradek)

        self.assertTrue(result["fired"])
        self.assertIs(result["replaced_card"], old_bank)
        self.assertIs(odradek.odradek_bank, replacement)
        self.assertNotIn(replacement, attacker.committed)
        self.assertEqual(odradek.souls, souls_before)
        self.assertEqual(result["soul_gain"], 0)

    def test_locked_bank_still_blocks_equal_or_lower_candidate(self):
        game, attacker, odradek = self.fixture()
        old_bank = self.card("Butcher", 5)
        odradek.odradek_bank = old_bank
        high = self.card("Wright", 5)
        candidate = self.card("Vulture", 4)
        attacker.committed = [high, candidate]
        original = list(attacker.committed)
        souls_before = odradek.souls

        result = game._odradek_recoil(attacker, odradek)

        self.assertTrue(result["fired"])
        self.assertTrue(result["locked"])
        self.assertIs(odradek.odradek_bank, old_bank)
        self.assertEqual(attacker.committed, original)
        self.assertEqual(odradek.souls, souls_before)
        self.assertEqual(result["soul_gain"], 0)


if __name__ == "__main__":
    unittest.main()
