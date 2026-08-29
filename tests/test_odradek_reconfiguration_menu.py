import inspect
import unittest

import corruptor_sim as sim


EXPECTED_POLICY = (
    "heuristic-2026.08-action-forecast-v1"
    "-odradek-reconfig-menu-v1_1"
)


class OdradekReconfigurationMenuTests(unittest.TestCase):
    def setUp(self):
        self.variant = dict(sim.VARIANT)
        self.features = dict(sim.ACTIVE_FEATURES)
        self.ruleset = getattr(sim, "ACTIVE_RULESET", None)
        self.lock_lords = getattr(sim, "LOCK_LORDS", None)
        if hasattr(sim, "activate_ruleset"):
            sim.activate_ruleset("lab-v6.5")

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features)
        if self.ruleset is not None:
            sim.ACTIVE_RULESET = self.ruleset
        if self.lock_lords is not None:
            sim.LOCK_LORDS = self.lock_lords

    @staticmethod
    def card(suit, value, revealed=False):
        card = sim.Card(suit, value)
        card.guard_revealed = revealed
        return card

    def game(self):
        game = sim.Game(["Odradek"], ["Deimos"], seed=99117)
        odr, op = game.players
        odr.lord = "Odradek"
        odr.alive = True
        op.lord = "Deimos"
        op.alive = True
        return game, odr, op

    def test_policy(self):
        self.assertEqual(sim.AI_POLICY, EXPECTED_POLICY)

    def test_guard_exchange_is_hidden_blind_and_conserves_cards(self):
        game, odr, op = self.game()
        own = self.card("Butcher", 1)
        enemy = self.card("Wright", 5)
        odr.lord_guards = [own]
        op.castle_guards = [enemy]
        odr.odradek_reconfig_tokens = 1

        source = inspect.getsource(
            sim.Game._odradek_reconfig_guard_exchange
        )
        self.assertNotIn(".value", source)
        self.assertNotIn(".suit", source)

        self.assertTrue(
            game._odradek_reconfig_guard_exchange(odr, op)
        )
        self.assertEqual(odr.odradek_reconfig_tokens, 0)
        self.assertIs(odr.lord_guards[0], enemy)
        self.assertIs(op.castle_guards[0], own)
        self.assertFalse(enemy.guard_revealed)
        self.assertFalse(own.guard_revealed)

    def test_revealed_and_temporary_guards_are_ineligible(self):
        game, odr, op = self.game()
        revealed = self.card("Butcher", 4, True)
        temp = self.card("Penitent", 3)
        enemy = self.card("Wright", 2)
        odr.lord_guards = [revealed, temp]
        odr.penitent_temp_guards = [temp]
        op.lord_guards = [enemy]
        odr.odradek_reconfig_tokens = 2

        self.assertFalse(
            game._odradek_reconfig_guard_exchange(odr, op)
        )
        self.assertEqual(odr.odradek_reconfig_tokens, 2)

    def test_lane_shift_preserves_marcher_state(self):
        game, odr, op = self.game()
        mine = {
            "card": self.card("Butcher", 2),
            "value": 2,
            "lane": "Lord",
            "pos": 1,
        }
        enemy = {
            "card": self.card("Wright", 5),
            "value": 5,
            "lane": "Lord",
            "pos": 1,
        }
        odr.marchers = [mine]
        op.marchers = [enemy]
        odr.odradek_reconfig_tokens = 1

        self.assertTrue(
            game._odradek_reconfig_lane_shift(odr, op)
        )
        self.assertEqual(mine["lane"], "Castle")
        self.assertEqual(mine["value"], 2)
        self.assertEqual(mine["pos"], 1)
        self.assertEqual(odr.odradek_reconfig_tokens, 0)

    def test_allegiance_shift_preserves_state(self):
        game, odr, op = self.game()
        enemy = {
            "card": self.card("Vulture", 4),
            "value": 4,
            "lane": "Castle",
            "pos": max(
                0,
                int(sim.VARIANT.get("march_steps", 3)) - 1,
            ),
        }
        op.marchers = [enemy]
        odr.marchers = []
        odr.odradek_reconfig_tokens = 3

        self.assertTrue(
            game._odradek_reconfig_steal_marcher(odr, op)
        )
        self.assertNotIn(enemy, op.marchers)
        self.assertIn(enemy, odr.marchers)
        self.assertEqual(enemy["lane"], "Castle")
        self.assertEqual(enemy["value"], 4)
        self.assertEqual(odr.odradek_reconfig_tokens, 0)

    def test_hunt_inversion_hits_attacker_not_odradek(self):
        game, odr, op = self.game()
        odr.castles = set()
        op.castles = set()
        odr.lord_guards = [self.card("Wright", 5)]
        op.lord_guards = []
        op.committed = [
            self.card("Butcher", 5),
            self.card("Butcher", 5),
            self.card("Vulture", 5),
            self.card("Wright", 5),
        ]
        op.action = "Hunt"
        op.tgt_pid = odr.pid
        odr.odradek_reconfig_tokens = 4

        self.assertTrue(
            game._odradek_reconfiguration_maybe_invert(
                op, odr, "Hunt"
            )
        )
        game._resolve_hunt(op, odr)

        self.assertTrue(odr.alive)
        self.assertFalse(op.alive)
        self.assertEqual(odr.odradek_reconfig_tokens, 0)

    def test_siege_inversion_needs_same_named_self_castle(self):
        game, odr, op = self.game()
        odr.castles = {"Stockpile"}
        op.castles = {"Bastion"}
        op.committed = [
            self.card("Butcher", 5),
            self.card("Wright", 5),
        ]
        odr.odradek_reconfig_tokens = 4

        self.assertFalse(
            game._odradek_reconfiguration_maybe_invert(
                op,
                odr,
                "Siege",
                forced_target="Stockpile",
            )
        )
        self.assertEqual(odr.odradek_reconfig_tokens, 4)

    def test_visible_inversion_risk_is_in_opponent_doctrine(self):
        hunt = inspect.getsource(sim.Game._score_hunt)
        siege = inspect.getsource(sim.Game._score_siege)
        self.assertIn("odradek_reconfig_tokens >= 4", hunt)
        self.assertIn("score -= ", hunt)
        self.assertIn("odradek_reconfig_tokens >= 4", siege)
        self.assertIn("likely_target in pl.castles", siege)

    def test_resolution_block_has_no_reconfiguration_tear_cashout(self):
        source = inspect.getsource(sim.Game._phase_resolution)
        start = source.index("Odradek — Reconfiguration Menu V1")
        tail = source[start:]
        end = tail.index("pl.prev_ward_target")
        block = tail[:end]
        self.assertIn("odradek_reconfig_tokens += 1", block)
        self.assertNotIn("_gain_neutral_tear", block)
        self.assertNotIn("_gain_tear", block)
        self.assertNotIn("reconfig_tokens_needed", block)


if __name__ == "__main__":
    unittest.main()
