import unittest

import corruptor_sim as sim


class ForecastDrivenDoctrineTests(unittest.TestCase):
    def setUp(self):
        self.variant_before = sim.VARIANT.copy()
        self.features_before = sim.ACTIVE_FEATURES.copy()
        self.ruleset_before = sim.ACTIVE_RULESET
        sim.activate_ruleset("lab-v6.5")

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant_before)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features_before)
        sim.ACTIVE_RULESET = self.ruleset_before

    def _hunt_game(self):
        game = sim.Game(["Deimos"], ["Valak"])
        attacker, defender = game.players
        attacker.lord = "Deimos"
        attacker.alive = True
        attacker.threat = 0
        attacker.hand = [sim.Card("Butcher", 5), sim.Card("Butcher", 4)]
        defender.lord = "Valak"
        defender.alive = True
        defender.threat = 0
        defender.castles.clear()
        defender.castle_integrity.clear()
        defender.lord_guards.clear()
        defender.sigils["Lord"] = ""
        guard = sim.Card("Penitent", 5)
        guard.guard_revealed = False
        defender.lord_guards.append(guard)
        return game, attacker, defender, guard

    def test_threat_one_is_not_a_generic_hunt_beacon(self):
        game, attacker, defender, _guard = self._hunt_game()
        defender.threat = 0
        zero = game._score_hunt(attacker, defender, "neutral")
        defender.threat = 1
        one = game._score_hunt(attacker, defender, "neutral")
        self.assertAlmostEqual(zero, one, places=9)

    def test_hidden_guard_face_value_does_not_leak(self):
        game, attacker, defender, guard = self._hunt_game()
        guard.guard_revealed = False
        guard.value = 5
        five = game._score_hunt(attacker, defender, "neutral")
        guard.value = 3
        three = game._score_hunt(attacker, defender, "neutral")
        self.assertAlmostEqual(five, three, places=9)

    def test_weaker_revealed_guard_increases_hunt_priority(self):
        game, attacker, defender, guard = self._hunt_game()
        guard.guard_revealed = True
        guard.value = 5
        five = game._score_hunt(attacker, defender, "neutral")
        guard.value = 3
        three = game._score_hunt(attacker, defender, "neutral")
        self.assertGreater(three, five)

    def test_forecast_can_override_static_siege_target_order(self):
        game = sim.Game(["Deimos"], ["Valak"])
        attacker, defender = game.players
        attacker.lord = "Deimos"
        attacker.alive = True
        attacker.hand = [sim.Card("Butcher", 5), sim.Card("Butcher", 4)]
        defender.castles = {"Keep", "Stockpile"}
        defender.castle_integrity = {"Keep": 1, "Stockpile": 14}
        defender.castle_guards.clear()
        defender.sigils["Castle"] = ""
        self.assertEqual(game._pick_siege_target(attacker, defender), "Keep")

    def test_default_opening_loadout_always_contains_keep(self):
        game = sim.Game(["Orias"], ["Gremory"])
        game._setup()
        expected_count = int(sim.VARIANT.get("starting_castles", 3))
        for player in game.players:
            self.assertIn("Keep", player.castles)
            self.assertEqual(len(player.castles), expected_count)


if __name__ == "__main__":
    unittest.main()
