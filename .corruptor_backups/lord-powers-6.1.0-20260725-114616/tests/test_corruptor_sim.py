import random
import unittest

import corruptor_sim as sim


class CardIdentityTests(unittest.TestCase):
    def test_two_player_deck_uses_unique_card_instances(self):
        random.seed(12345)

        deck = sim.make_deck_2p()

        self.assertEqual(
            len(deck),
            60,
        )

        self.assertEqual(
            len({
                id(card)
                for card in deck
            }),
            len(deck),
            "Every physical card in the deck must have a unique object identity.",
        )


class GremoryRuinousHarvestTests(unittest.TestCase):
    def test_harvest_removes_exact_most_recent_eligible_card(self):
        game = sim.Game(
            ["Gremory"],
            ["Orias"],
        )

        gremory = game.players[0]
        gremory.alive = True
        gremory.gremory_veil_draw_done = False

        low_before = sim.Card(
            "Penitent",
            1,
        )

        older_duplicate = sim.Card(
            "Vulture",
            5,
        )

        middle_card = sim.Card(
            "Butcher",
            5,
        )

        newer_duplicate = sim.Card(
            "Vulture",
            5,
        )

        low_after = sim.Card(
            "Wright",
            2,
        )

        game.discard = [
            low_before,
            older_duplicate,
            middle_card,
            newer_duplicate,
            low_after,
        ]

        game._gremory_ruinous_harvest()

        self.assertTrue(
            gremory.gremory_veil_draw_done,
        )

        self.assertEqual(
            len(gremory.hand),
            1,
        )

        self.assertIs(
            gremory.hand[0],
            newer_duplicate,
            "Harvest must take the exact most-recent eligible physical card.",
        )

        self.assertTrue(
            any(
                card is older_duplicate
                for card in game.discard
            ),
            "The older identical card must remain in the discard pile.",
        )

        self.assertFalse(
            any(
                card is newer_duplicate
                for card in game.discard
            ),
            "The selected newer card must be removed from the discard pile.",
        )

        self.assertEqual(
            [
                f"{card.suit}:{card.value}"
                for card in game.discard
            ],
            [
                "Penitent:1",
                "Vulture:5",
                "Butcher:5",
                "Wright:2",
            ],
        )


if __name__ == "__main__":
    unittest.main()
