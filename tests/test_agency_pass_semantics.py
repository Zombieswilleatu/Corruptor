"""Semantic regressions for the Corruptor agency pass."""

import unittest
from collections import Counter

import corruptor_sim as sim


class VariantIsolatedTest(unittest.TestCase):
    def setUp(self):
        self._variant = dict(sim.VARIANT)
        self._features = dict(sim.ACTIVE_FEATURES)
        self._ruleset = sim.ACTIVE_RULESET
        self._lock = sim.LOCK_LORDS
        self._kit = dict(sim.KIT_PROBE)
        self._constants = {
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
        sim.activate_ruleset("lab-v6.5")

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self._variant)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self._features)
        sim.ACTIVE_RULESET = self._ruleset
        sim.LOCK_LORDS = self._lock
        sim.KIT_PROBE.clear()
        sim.KIT_PROBE.update(self._kit)
        for name, value in self._constants.items():
            setattr(sim, name, value)


class RepairAgencyTests(VariantIsolatedTest):
    def test_repair_tax_values(self):
        self.assertEqual(
            sim.effective_repair_value(sim.Card("Wright", 4)),
            4,
        )
        self.assertEqual(
            sim.effective_repair_value(sim.Card("Butcher", 4)),
            3,
        )
        self.assertEqual(
            sim.effective_repair_value(sim.Card("Vulture", 1)),
            1,
        )

    def test_repair_is_legal_without_wright(self):
        pool = sim.repair_payment_pool([
            sim.Card("Butcher", 3),
        ])
        self.assertEqual(len(pool), 1)

    def test_repair_chooser_uses_effective_value(self):
        cards = [
            sim.Card("Butcher", 4),
            sim.Card("Wright", 4),
        ]
        picked = sim.choose_payment_cards(
            cards,
            4,
            value_of=lambda c: sim.effective_repair_value(c),
        )
        self.assertEqual(len(picked), 1)
        self.assertEqual(picked[0].suit, "Wright")

    def test_repair_does_not_block_hand_deploy_in_lab(self):
        self.assertFalse(sim.VARIANT["repair_blocks_hand_deploy"])


class SummonThreatExchangeTests(VariantIsolatedTest):
    def _banished(self, lord="Kalligan"):
        game = sim.Game([lord], ["Orias"])
        player = game.players[0]
        player.alive = False
        player.first_summon_done = True
        return game, player

    def test_unlocked_pool_shortfall_actually_summons(self):
        sim.LOCK_LORDS = False
        game, player = self._banished("Kalligan")
        player.hand = [sim.Card("Butcher", 1)]

        game._ai_summon(player)

        self.assertTrue(player.alive)
        self.assertEqual(player.threat, sim.MAX_THREAT)
        self.assertEqual(player.hand, [])

    def test_shortfall_beyond_threat_room_is_refused(self):
        game, player = self._banished("Kalligan")
        player.hand = []
        huge = sim.MAX_THREAT + 99
        self.assertFalse(
            game._summon_affordable(
                player,
                player.lord,
                huge,
            )
        )

    def test_retained_return_threat_controls_room(self):
        game, player = self._banished("Kalligan")
        player.return_threat_override = 3
        player.hand = [sim.Card("Butcher", 2)]

        self.assertFalse(
            game._summon_affordable(
                player,
                player.lord,
                4,
            )
        )
        self.assertTrue(
            game._summon_affordable(
                player,
                player.lord,
                3,
            )
        )

    def test_vessel_two_is_baseline_not_shortfall_erasure(self):
        game, player = self._banished("Kalligan")
        player.vessel_offered_lord = "Kalligan"
        player.hand = [sim.Card("Butcher", 2)]

        game._ai_summon(player)

        self.assertTrue(player.alive)
        self.assertEqual(player.threat, 4)
        self.assertEqual(player.vessel_offered_lord, "")

    def test_voluntary_exchange_exists_when_cards_can_pay_in_full(self):
        game, player = self._banished("Kalligan")
        sim.VARIANT["summon_hand_reserve_min"] = 10
        sim.VARIANT["summon_hand_reserve_max"] = 10
        sim.VARIANT["summon_threat_weight"] = 0.0
        player.hand = [
            sim.Card("Butcher", 3),
            sim.Card("Wright", 3),
        ]
        room = (
            sim.MAX_THREAT
            - game._summon_return_threat(
                player,
                player.lord,
            )
        )

        bid = game._summon_threat_bid(
            player,
            player.lord,
            cost=4,
            have=6,
            room=room,
        )

        self.assertGreater(bid, 0)
        self.assertLessEqual(bid, room)

    def test_discrete_card_overpay_reduces_actual_threat(self):
        game, player = self._banished("Kalligan")
        sim.VARIANT["summon_hand_reserve_min"] = 10
        sim.VARIANT["summon_hand_reserve_max"] = 10
        sim.VARIANT["summon_threat_weight"] = 0.0
        player.hand = [
            sim.Card("Butcher", 3),
            sim.Card("Wright", 3),
        ]

        game._ai_summon(player)

        self.assertTrue(player.alive)
        # Kalligan costs 4 and returns at 1. If doctrine asks to preserve cards,
        # discrete 3s may force card overpay; Threat must reflect the ACTUAL gap.
        spent = 6 - sum(c.value for c in player.hand)
        self.assertEqual(
            player.threat,
            sim.return_threat("Kalligan") + max(0, 4 - spent),
        )


class DominionAndHistoricalTests(VariantIsolatedTest):
    def test_current_lab_prices_profane_ruins_at_five(self):
        self.assertEqual(sim.VARIANT["profane_ruins_card_cost"], 5)

    def test_historical_profiles_do_not_enable_agency_rules(self):
        for ruleset in ("de-v2", "v5.29"):
            sim.activate_ruleset(ruleset)
            self.assertNotEqual(
                sim.VARIANT.get("repair_wright_mode", "off"),
                "tax",
            )
            self.assertTrue(
                sim.VARIANT.get("repair_blocks_hand_deploy", True)
            )
            self.assertFalse(
                sim.VARIANT.get("summon_threat_shortfall", False)
            )
            self.assertEqual(
                int(sim.VARIANT.get(
                    "profane_ruins_card_cost",
                    sim.VARIANT.get("profane_ruins_cost", 0),
                ) or 0),
                0,
            )


class CardConservationTests(VariantIsolatedTest):
    @staticmethod
    def _census(game):
        count = Counter()

        for zone in (game.deck, game.discard, game.market):
            count.update(
                (card.suit, card.value)
                for card in zone
            )

        for player in game.players:
            for name in (
                "hand",
                "garrison",
                "lord_guards",
                "castle_guards",
                "committed",
            ):
                count.update(
                    (card.suit, card.value)
                    for card in (getattr(player, name, []) or [])
                )

            for marcher in getattr(player, "marchers", []) or []:
                card = (
                    marcher.get("card")
                    if isinstance(marcher, dict)
                    else None
                )
                if card is not None:
                    count[(card.suit, card.value)] += 1

            bank = getattr(player, "odradek_bank", None)
            if bank is not None:
                count[(bank.suit, bank.value)] += 1

        return count

    def test_two_player_deck_is_sixty(self):
        deck = sim.make_deck_2p()
        self.assertEqual(len(deck), 60)

    def test_kroni_fallback_discards_instead_of_sinking_card(self):
        game = sim.Game(["Kroni"], ["Gremory"])
        game._setup()
        player = game.players[0]
        player.alive = True
        player.kroni_consume_done = False
        player.lord_guards = [sim.Card("Vulture", 1)]
        player.castle_guards = []

        before = len(game.discard)
        victim = game._try_kroni_fallback(player)

        self.assertIsNotNone(victim)
        self.assertEqual(game.removed_from_play, [])
        self.assertEqual(len(game.discard), before + 1)

    def test_full_games_keep_exactly_sixty_deck_cards(self):
        for lords in (
            ("Deimos", "Kanifous"),
            ("Orias", "Humbaba"),
            ("Kroni", "Kroni"),
            ("Kroni", "Gremory"),
        ):
            game = sim.Game([lords[0]], [lords[1]])
            game.run()

            # Kanifous Penitent temporary Guards are minted effect objects, not
            # members of the sixty-card physical deck, so they are excluded.
            total = sum(self._census(game).values())

            self.assertEqual(
                total,
                60,
                f"{lords}: physical deck census ended at {total}",
            )
            self.assertEqual(
                game.removed_from_play,
                [],
                f"{lords}: a deck card entered removed_from_play",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
