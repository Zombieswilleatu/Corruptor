import random
import unittest
from unittest.mock import patch

import corruptor_sim as sim


class CardConservationTests(unittest.TestCase):
    def setUp(self):
        self.variant_before = sim.VARIANT.copy()
        self.features_before = sim.ACTIVE_FEATURES.copy()
        self.ruleset_before = sim.ACTIVE_RULESET
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
        sim.activate_ruleset("de-v2")

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant_before)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features_before)
        sim.ACTIVE_RULESET = self.ruleset_before
        for name, value in self.constants_before.items():
            setattr(sim, name, value)

    @staticmethod
    def _physical_card_zones(game):
        zones = [
            ("deck", game.deck),
            ("discard", game.discard),
            ("market", game.market),
            ("removed_from_play", game.removed_from_play),
        ]

        for player in game.players:
            prefix = f"p{player.pid}"
            zones.extend([
                (f"{prefix}.hand", player.hand),
                (f"{prefix}.garrison", player.garrison),
                (f"{prefix}.castle_guards", player.castle_guards),
                (f"{prefix}.lord_guards", player.lord_guards),
                (f"{prefix}.committed", player.committed),
            ])

            marcher_cards = [
                marcher.get("card")
                for marcher in player.marchers
                if marcher.get("card") is not None
            ]
            zones.append((f"{prefix}.marchers", marcher_cards))

        return zones

    def _assert_card_conservation(self, game, context):
        locations = {}
        total_entries = 0

        for zone_name, cards in self._physical_card_zones(game):
            for card_index, card in enumerate(cards):
                self.assertIsNotNone(
                    card,
                    f"{context}: null card at {zone_name}[{card_index}]",
                )
                total_entries += 1
                locations.setdefault(id(card), []).append(
                    f"{zone_name}[{card_index}]"
                )

        duplicates = {
            card_id: card_locations
            for card_id, card_locations in locations.items()
            if len(card_locations) != 1
        }

        duplicate_report = "; ".join(
            " / ".join(card_locations)
            for card_locations in list(duplicates.values())[:8]
        )

        self.assertEqual(
            total_entries,
            60,
            f"{context}: expected 60 card-zone entries, got {total_entries}. "
            f"Duplicates: {duplicate_report or 'none'}",
        )
        self.assertEqual(
            len(locations),
            60,
            f"{context}: expected 60 distinct Card objects, got {len(locations)}. "
            f"Duplicates: {duplicate_report or 'none'}",
        )
        self.assertFalse(
            duplicates,
            f"{context}: physical Card object occupies multiple zones: "
            f"{duplicate_report}",
        )

    def _run_instrumented_game(self, seed, left_lord, right_lord):
        random.seed(seed)
        game = sim.Game([left_lord], [right_lord])

        for method_name in (
            "_setup",
            "_phase_development",
            "_phase_reflex_bid",
            "_phase_commitment",
            "_phase_reveal",
            "_phase_resolution",
            "_march_advance",
        ):
            original = getattr(game, method_name)

            def checked_phase(
                *args,
                _original=original,
                _method_name=method_name,
                **kwargs,
            ):
                result = _original(*args, **kwargs)
                self._assert_card_conservation(
                    game,
                    (
                        f"seed={seed} matchup={left_lord}/{right_lord} "
                        f"round={game.round} after={_method_name}"
                    ),
                )
                return result

            setattr(game, method_name, checked_phase)

        game.run()
        self._assert_card_conservation(
            game,
            (
                f"seed={seed} matchup={left_lord}/{right_lord} "
                f"round={game.round} terminal"
            ),
        )

    def test_odradek_breach_discards_selected_cards_from_hand_exactly_once(self):
        game = sim.Game(["Odradek"], ["Kalligan"])
        thief, winner = game.players

        winner_cards = [
            sim.Card("Wright", 5),
            sim.Card("Vulture", 4),
        ]
        thief_anchor = sim.Card("Butcher", 1)

        winner.hand = winner_cards.copy()
        thief.hand = [thief_anchor]

        game.breach = "Odradek"
        game.breach_owner = thief.pid
        game.reflex_winner = winner.pid

        choices = {
            winner.pid: ("Siege", winner_cards.copy(), "Keep"),
            thief.pid: ("Ward", [], "Castle"),
        }

        game._ai_reflex_choice = (
            lambda player, _opponent: choices.get(player.pid)
        )

        with patch.object(sim.random, "random", return_value=0.0):
            game._resolve_reflex_action(winner.pid)

        self.assertEqual(winner.hand, [])
        self.assertEqual(game.discard, winner_cards)
        self.assertTrue(all(card not in winner.hand for card in winner_cards))
        self.assertEqual(len({id(card) for card in game.discard}), 2)
        self.assertEqual(thief.hand, [thief_anchor])

    def test_every_phase_boundary_preserves_all_60_physical_cards(self):
        seeds = [*range(20), 75]

        for seed in seeds:
            for left_lord in sim.ALL_LORDS:
                for right_lord in sim.ALL_LORDS:
                    with self.subTest(
                        seed=seed,
                        left_lord=left_lord,
                        right_lord=right_lord,
                    ):
                        self._run_instrumented_game(
                            seed,
                            left_lord,
                            right_lord,
                        )


if __name__ == "__main__":
    unittest.main()
