import unittest

import corruptor_sim as sim


class BlockedProfaneTests(unittest.TestCase):
    def test_fresh_sigil_clears_pending_profane(self):
        game = sim.Game(
            ["Valak"],
            ["Deimos"],
        )

        player = game.players[0]
        opponent = game.players[1]

        player.alive = True
        opponent.alive = True

        player.castles = {
            "Keep",
            "SummoningCircle",
            "SiegeEngine",
        }
        player.profaned_castles.clear()
        player.pending_profane = "SummoningCircle"
        player.profane_this_round = False
        player.tears = 0

        opponent.sigils["Lord"] = "fresh"
        opponent.sigils["Castle"] = ""

        game._resolve_profane(
            player,
            opponent,
        )

        self.assertEqual(
            player.pending_profane,
            "",
            "A Fresh Sigil must cancel the queued Profane Tear.",
        )
        self.assertIn(
            "SummoningCircle",
            player.castles,
        )
        self.assertNotIn(
            "SummoningCircle",
            player.profaned_castles,
        )
        self.assertFalse(
            player.profane_this_round,
        )
        self.assertEqual(
            player.tears,
            0,
        )


if __name__ == "__main__":
    unittest.main()
