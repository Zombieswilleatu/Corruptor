"""Focused contracts for the 6.8.6 measured integration."""
import unittest

import corruptor_sim as sim


class Integration686Tests(unittest.TestCase):
    def setUp(self):
        self.variant_before = sim.VARIANT.copy()
        self.features_before = sim.ACTIVE_FEATURES.copy()
        self.ruleset_before = sim.ACTIVE_RULESET
        self.constants_before = {
            name: getattr(sim, name)
            for name in (
                "WIN_SOULS", "DOMINION_TRACK", "DOMINION_REQUIREMENT",
                "FINAL_COLLAPSE_TRACK", "HAND_LIMIT", "GARRISON_MAX",
                "MAX_THREAT", "MARKET_SIZE", "MAX_ROUNDS",
            )
        }
        sim.activate_ruleset("lab-v6.5")

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant_before)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features_before)
        sim.ACTIVE_RULESET = self.ruleset_before
        for name, value in self.constants_before.items():
            setattr(sim, name, value)

    def test_momentum_refund_returns_the_highest_committed_card(self):
        game = sim.Game(["Orias"], ["Valak"])
        player = game.players[0]
        low = sim.Card("Penitent", 1)
        high = sim.Card("Butcher", 5)
        player.committed = [low, high]
        player.momentum_refund_due = 1

        refunded = game._apply_momentum_refund(player)

        self.assertEqual(refunded, [high])
        self.assertIn(high, player.hand)
        self.assertEqual(player.committed, [low])
        self.assertEqual(player.momentum_refund_due, 0)

    def test_scorch_escalates_burns_the_matching_lane_and_pays_flame_income(self):
        game = sim.Game(["Kalligan"], ["Valak"])
        kalligan, defender = game.players
        kalligan.alive = True
        defender.alive = True
        kalligan.kalligan_flame_tokens = 4
        game.persist_scorch_pid = defender.pid
        game.persist_scorch_type = "Lord"
        game.persist_scorch_level = 1
        burned_guard = sim.Card("Penitent", 1)
        surviving_guard = sim.Card("Wright", 2)
        defender.lord_guards = [burned_guard, surviving_guard]
        lane_card = sim.Card("Vulture", 4)
        defender.marchers = [{
            "card": lane_card, "value": 2, "lane": "Lord", "pos": 1,
        }]

        game._phase_resolution([])

        self.assertNotIn(burned_guard, defender.lord_guards)
        self.assertIn(surviving_guard, defender.lord_guards)
        self.assertEqual(defender.marchers, [])
        self.assertIn(lane_card, game.discard)
        self.assertEqual(game.persist_scorch_level, 2)
        self.assertEqual(kalligan.souls, 1)
        self.assertEqual(kalligan.kalligan_flame_tokens, 1)

    def test_graduated_veil_drift_ignores_the_median_game_then_closes(self):
        game = sim.Game(["Orias"], ["Valak"])
        for round_number in (15, 16, 17, 18, 19):
            game.round = round_number
            game._apply_graduated_veil_drift()

        self.assertEqual(game.neutral_tears, 1)
        self.assertAlmostEqual(game._veil_drift_acc, 0.5)

    def test_canonical_profile_keeps_the_new_mechanics_inert(self):
        sim.activate_ruleset("de-v2")
        self.assertEqual(sim.ACTIVE_FEATURES["momentum_refund"], 0)
        self.assertEqual(sim.ACTIVE_FEATURES["veil_drift_growth"], 0.0)
        self.assertTrue(sim.ACTIVE_FEATURES["kal_inferno_threat"])
        self.assertFalse(sim.ACTIVE_FEATURES["kal_flame_tokens"])
        self.assertFalse(sim.ACTIVE_FEATURES["kal_scorch_escalate"])
        self.assertFalse(sim.ACTIVE_FEATURES["kal_lane_scorch"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
