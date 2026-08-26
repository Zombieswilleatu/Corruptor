"""Focused contracts for the measured Kroni kit revision."""
import random
import unittest

import corruptor_sim as sim


class KroniRevisionTests(unittest.TestCase):
    def setUp(self):
        self.variant_before = sim.VARIANT.copy()
        self.features_before = sim.ACTIVE_FEATURES.copy()
        self.ruleset_before = sim.ACTIVE_RULESET
        self.lock_before = sim.LOCK_LORDS
        self.constants_before = {
            name: getattr(sim, name)
            for name in (
                "WIN_SOULS",
                "DOMINION_TRACK",
                "DOMINION_REQUIREMENT",
                "FINAL_COLLAPSE_TRACK",
                "HAND_LIMIT",
                "GARRISON_MAX",
                "MAX_THREAT",
                "MARKET_SIZE",
                "MAX_ROUNDS",
            )
        }
        sim.LOCK_LORDS = True
        random.seed(6802)

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant_before)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features_before)
        sim.ACTIVE_RULESET = self.ruleset_before
        sim.LOCK_LORDS = self.lock_before
        for name, value in self.constants_before.items():
            setattr(sim, name, value)

    @staticmethod
    def _fresh_kroni():
        game = sim.Game(["Kroni"], ["Orias"])
        game._setup()
        kroni = game.players[0]
        kroni.lord = "Kroni"
        kroni.alive = True
        kroni.kroni_consume_done = False
        kroni.kroni_tear_milestone_fired = False
        kroni.kroni_hunger = 2
        kroni.tears = 0
        return game, kroni

    def test_profiles_select_the_intended_rules(self):
        sim.activate_ruleset("de-v2")
        self.assertTrue(sim.ACTIVE_FEATURES["kro_fallback_feeds"])
        self.assertFalse(sim.ACTIVE_FEATURES["kro_milestone_once"])
        self.assertFalse(sim.VARIANT["odr_recoil_bank"])

        sim.activate_ruleset("lab-v6.5")
        self.assertFalse(sim.ACTIVE_FEATURES["kro_fallback_feeds"])
        self.assertTrue(sim.ACTIVE_FEATURES["kro_milestone_once"])
        self.assertTrue(sim.ACTIVE_FEATURES["kro_cannibal_h1"])
        self.assertFalse(sim.ACTIVE_FEATURES["kro_gorge"])
        self.assertTrue(sim.VARIANT["odr_recoil_bank"])
        self.assertTrue(sim.VARIANT["fix_breach_discard_alias"])
        self.assertTrue(sim.VARIANT["reconfig_neutral"])
        self.assertEqual(sim.VARIANT["reconfig_tokens_needed"], 3)
        self.assertEqual(sim.LAB_PROFILE_VERSION, "6.8.3-kroni-cannibal-no-gorge")

    def test_canonical_fallback_still_feeds(self):
        sim.activate_ruleset("de-v2")
        game, kroni = self._fresh_kroni()
        victim = sim.Card("Penitent", 1)
        kroni.castle_guards = [victim]

        self.assertIs(game._try_kroni_fallback(kroni), victim)
        self.assertEqual(kroni.kroni_hunger, 3)
        self.assertEqual(kroni.tears, 1)
        self.assertIn(victim, game.discard)
        self.assertEqual(game.removed_from_play, [])

    def test_lab_cannibal_hunger_is_compulsory_guards_only(self):
        sim.activate_ruleset("lab-v6.5")
        game, kroni = self._fresh_kroni()
        kroni.kroni_consume_done = True
        victim = sim.Card("Penitent", 1)
        kroni.castle_guards = [victim]

        self.assertIs(game._try_kroni_fallback(kroni), victim)
        self.assertEqual(kroni.kroni_hunger, 2)
        self.assertEqual(kroni.tears, 0)
        self.assertIn(victim, game.removed_from_play)

        game, kroni = self._fresh_kroni()
        kroni.kroni_consume_done = True
        garrison_card = sim.Card("Wright", 1)
        kroni.garrison = [garrison_card]

        self.assertIsNone(game._try_kroni_fallback(kroni))
        self.assertEqual(kroni.kroni_hunger, 1)
        self.assertEqual(kroni.garrison, [garrison_card])
        self.assertEqual(game.removed_from_play, [])

    def test_lab_gorge_is_removed_but_combat_consume_still_feeds(self):
        sim.activate_ruleset("lab-v6.5")
        game, kroni = self._fresh_kroni()
        kroni.kroni_hunger = 0
        kroni.souls = 0
        kroni.kroni_consume_done = False
        kroni.kroni_personally_defeated_guard = True
        game.any_destruction_this_round = True

        game._try_kroni_consume(kroni)
        self.assertEqual(kroni.kroni_hunger, 1)
        self.assertEqual(kroni.souls, 0)
        self.assertTrue(kroni.kroni_consume_done)

    def test_canonical_resummon_rearms_the_milestone(self):
        sim.activate_ruleset("de-v2")
        game, kroni = self._fresh_kroni()
        kroni.alive = False
        kroni.first_summon_done = True
        kroni.kroni_tear_milestone_fired = True

        game._ai_summon(kroni, forced=True)
        self.assertFalse(kroni.kroni_tear_milestone_fired)

    def test_lab_resummon_preserves_the_once_per_game_milestone(self):
        sim.activate_ruleset("lab-v6.5")
        game, kroni = self._fresh_kroni()
        kroni.alive = False
        kroni.first_summon_done = True
        kroni.kroni_tear_milestone_fired = True

        game._ai_summon(kroni, forced=True)
        self.assertTrue(kroni.kroni_tear_milestone_fired)

        tears_before = kroni.tears
        kroni.kroni_hunger = 2
        game._kroni_gain_hunger(kroni)
        self.assertEqual(kroni.kroni_hunger, 3)
        self.assertEqual(kroni.tears, tears_before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
