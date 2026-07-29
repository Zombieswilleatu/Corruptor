import unittest

import corruptor_sim as sim


class KanifousHandTollTests(unittest.TestCase):
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

    def test_lab_pays_lowest_hand_card_without_threat(self):
        sim.activate_ruleset("lab-v6.5")
        game = sim.Game(["Kanifous"], ["Valak"])
        player = game.players[0]
        low = sim.Card("Penitent", 1)
        high = sim.Card("Wright", 4)
        player.hand = [high, low]
        player.action = "Ward"
        player.threat = 2
        first = sim.Card("Butcher", 4)
        second = sim.Card("Butcher", 2)
        game.deck = [second, first]
        game.discard = []

        game._kanifous_invoke(player)

        self.assertEqual(player.threat, 2)
        self.assertNotIn(low, player.hand)
        self.assertIn(low, game.discard)
        self.assertEqual(player.kanifous_invokes_this_round, 1)
        self.assertTrue(sim.ACTIVE_FEATURES["kani_suit_effects"])

    def test_empty_hand_restores_exact_deck_order_and_does_not_invoke(self):
        sim.activate_ruleset("lab-v6.5")
        game = sim.Game(["Kanifous"], ["Valak"])
        player = game.players[0]
        player.hand = []
        cards = [
            sim.Card("Penitent", 1),
            sim.Card("Wright", 2),
            sim.Card("Butcher", 4),
        ]
        game.deck = cards[:]
        game.discard = []
        before_ids = [id(card) for card in game.deck]

        game._kanifous_invoke(player)

        self.assertEqual([id(card) for card in game.deck], before_ids)
        self.assertEqual(player.kanifous_invokes_this_round, 0)
        self.assertEqual(player.threat, 0)
        self.assertEqual(game.discard, [])

    def test_canonical_profile_keeps_printed_threat_cost(self):
        sim.activate_ruleset("de-v2")
        game = sim.Game(["Kanifous"], ["Valak"])
        player = game.players[0]
        player.hand = []
        player.threat = 1
        game.deck = [sim.Card("Butcher", 2), sim.Card("Butcher", 3)]
        game.discard = []

        game._kanifous_invoke(player)

        self.assertEqual(player.threat, 2)
        self.assertEqual(player.kanifous_invokes_this_round, 1)


if __name__ == "__main__":
    unittest.main()
