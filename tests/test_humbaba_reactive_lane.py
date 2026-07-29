import unittest

import corruptor_sim as sim


class HumbabaReactiveLaneTests(unittest.TestCase):
    def setUp(self):
        self.variant = sim.VARIANT.copy()
        self.features = sim.ACTIVE_FEATURES.copy()
        self.ruleset = sim.ACTIVE_RULESET

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features)
        sim.ACTIVE_RULESET = self.ruleset

    @staticmethod
    def _marcher(card, lane):
        return {"card": card, "value": card.value, "lane": lane, "pos": 0}

    def test_humbaba_response_is_forced_into_enemy_lane(self):
        sim.activate_ruleset("lab-v6.5")
        game = sim.Game(["Humbaba"], ["Valak"])
        player, opponent = game.players
        player.marchers = [self._marcher(sim.Card("Wright", 3), "Lord")]
        opponent.marchers = [self._marcher(sim.Card("Penitent", 3), "Castle")]
        player.lord_guards = [sim.Card("Butcher", 5), sim.Card("Butcher", 4)]
        player.castle_guards = []

        game._march_launch(player)

        self.assertEqual(len(player.marchers), 2)
        self.assertEqual({marcher["lane"] for marcher in player.marchers}, {"Lord", "Castle"})

    def test_humbaba_cannot_open_a_second_attack(self):
        sim.activate_ruleset("lab-v6.5")
        game = sim.Game(["Humbaba"], ["Valak"])
        player, opponent = game.players
        player.marchers = [self._marcher(sim.Card("Wright", 3), "Lord")]
        opponent.marchers = []
        player.lord_guards = [sim.Card("Butcher", 5), sim.Card("Butcher", 4)]

        game._march_launch(player)

        self.assertEqual(len(player.marchers), 1)

    def test_canonical_humbaba_has_no_reactive_slot(self):
        sim.activate_ruleset("de-v2")
        sim.VARIANT["marching"] = True
        game = sim.Game(["Humbaba"], ["Valak"])
        player, opponent = game.players
        player.marchers = [self._marcher(sim.Card("Wright", 3), "Lord")]
        opponent.marchers = [self._marcher(sim.Card("Penitent", 3), "Castle")]
        player.lord_guards = [sim.Card("Butcher", 5), sim.Card("Butcher", 4)]

        game._march_launch(player)

        self.assertEqual(len(player.marchers), 1)


if __name__ == "__main__":
    unittest.main()
