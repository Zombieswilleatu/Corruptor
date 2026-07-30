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

    def test_harvest_attempt_is_spent_when_no_eligible_card_exists(self):
        game = sim.Game(
            ["Gremory"],
            ["Orias"],
        )

        gremory = game.players[0]
        gremory.alive = True
        gremory.gremory_veil_draw_done = False
        game.discard = [
            sim.Card("Butcher", 1),
            sim.Card("Wright", 3),
        ]

        game._gremory_ruinous_harvest()

        self.assertTrue(
            gremory.gremory_veil_draw_done,
            "The first Tear must consume Harvest even when recovery misses.",
        )

        game.discard.append(
            sim.Card("Vulture", 5),
        )
        game._gremory_ruinous_harvest()

        self.assertEqual(
            gremory.hand,
            [],
            "A later Tear in the same round must not reopen a missed Harvest.",
        )


class LordPowerRegressionTests(unittest.TestCase):
    def setUp(self):
        self.variant_before = sim.VARIANT.copy()
        sim.VARIANT.update({
            "recoil_hunts_only": True,
            "recoil_lowest": True,
            "kroni_hunger_decay": True,
            "neutral_tear_on_banish": True,
            "reconfig_strict": True,
            "reconfig_tokens_needed": 5,
            "reconfig_neutral": False,
        })

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(
            self.variant_before,
        )

    def test_kanifous_butcher_is_not_a_guard_defeat(self):
        game = sim.Game(
            ["Kanifous"],
            ["Odradek"],
        )

        kanifous, odradek = game.players
        kanifous.alive = True
        kanifous.action = "Hunt"
        kanifous.tgt_pid = odradek.pid
        kanifous.tgt_type = "Lord"
        kanifous.kanifous_invoked_suit = "Butcher"
        kanifous.committed = [
            sim.Card("Wright", 2),
        ]

        suppressed = sim.Card("Butcher", 1)
        surviving = sim.Card("Vulture", 5)
        odradek.alive = True
        odradek.lord_guards = [
            suppressed,
            surviving,
        ]

        game._resolve_hunt(
            kanifous,
            odradek,
        )

        self.assertEqual(
            odradek.lord_guards,
            [surviving],
        )
        self.assertIn(
            suppressed,
            game.discard,
        )
        self.assertEqual(
            odradek.odradek_guards_defeated,
            0,
            "Butcher's already-Defeated Guard must not feed Reconfiguration.",
        )
        self.assertFalse(
            game.any_destruction_this_round,
            "Butcher's removal alone must not establish a destruction trigger.",
        )

    def test_lord_banishment_does_not_trigger_gremory_predator(self):
        game = sim.Game(
            ["Deimos"],
            ["Gremory"],
        )

        attacker, gremory = game.players
        attacker.alive = True
        attacker.action = "Hunt"
        attacker.tgt_pid = gremory.pid
        attacker.tgt_type = "Lord"
        attacker.committed = [
            sim.Card("Butcher", 5),
            sim.Card("Wright", 5),
        ]

        gremory.alive = True
        gremory.gremory_ruin_done = False
        low_discard = sim.Card("Penitent", 1)
        game.discard = [
            low_discard,
        ]

        game._resolve_hunt(
            attacker,
            gremory,
        )

        self.assertFalse(
            gremory.gremory_ruin_done,
        )
        self.assertNotIn(
            low_discard,
            gremory.hand,
        )

    def test_offer_vessel_defeats_lord_guards_for_predator(self):
        game = sim.Game(
            ["Gremory"],
            ["Orias"],
        )

        gremory, opponent = game.players
        gremory.alive = True
        gremory.threat = 3
        gremory.tears = 2
        gremory.lord_guards = [
            sim.Card("Butcher", 2),
        ]
        opponent.alive = True
        game.neutral_tears = 9
        game.deck = [
            sim.Card("Vulture", 5),
        ]

        game._ai_offer_vessel(
            gremory,
        )

        self.assertTrue(
            gremory.vessel_used,
        )
        self.assertTrue(
            gremory.gremory_lord_guard_draw_done,
            "Offer the Vessel must trigger the first-Lord-Guard Predator effect.",
        )

    def test_scorch_defeats_count_for_odradek_reconfiguration(self):
        game = sim.Game(
            ["Odradek"],
            ["Orias"],
        )

        odradek, opponent = game.players
        odradek.alive = True
        odradek.action = "Ward"
        odradek.ward_target = "Lord"
        odradek.lord_guards = [
            sim.Card("Butcher", 1),
            sim.Card("Wright", 2),
        ]
        opponent.alive = True
        opponent.action = "Ward"
        opponent.ward_target = "Castle"

        game.persist_scorch_pid = odradek.pid
        game.persist_scorch_type = "Lord"

        game._phase_resolution(
            [0, 1],
        )

        self.assertEqual(
            odradek.odradek_guards_defeated,
            2,
        )
        self.assertEqual(
            odradek.odradek_reconfig_tokens,
            0,
            "Two Scorch defeats must block the round's Reconfiguration token.",
        )

    def test_inferno_lord_scorch_replaces_wildfire_castle_scorch(self):
        game = sim.Game(
            ["Kalligan"],
            ["Orias"],
        )

        kalligan, defender = game.players
        kalligan.alive = True
        kalligan.action = "Siege"
        kalligan.tgt_pid = defender.pid
        kalligan.tgt_type = "Castle"
        kalligan.committed = [
            sim.Card("Butcher", 5),
            sim.Card("Vulture", 5),
            sim.Card("Wright", 5),
        ]

        defender.alive = True
        defender.castles = {
            "Bastion",
            "Keep",
        }
        defender.lord_guards = []

        game._resolve_siege(
            kalligan,
            defender,
            forced_target="Bastion",
        )

        self.assertEqual(
            game.persist_scorch_pid,
            defender.pid,
        )
        self.assertEqual(
            game.persist_scorch_type,
            "Lord",
            "Inferno's later Lord Scorch must remain after Wildfire.",
        )

    def test_consume_waits_for_finale_and_fallback_removes_from_play(self):
        game = sim.Game(
            ["Kroni"],
            ["Orias"],
        )

        kroni, opponent = game.players
        kroni.alive = True
        kroni.action = "Ward"
        kroni.ward_target = "Lord"
        kroni.kroni_hunger = 0
        kroni.kroni_consume_done = False
        removed = sim.Card("Penitent", 1)
        kroni.lord_guards = [
            removed,
        ]

        opponent.alive = True
        opponent.action = "Ward"
        opponent.ward_target = "Castle"

        game._phase_resolution(
            [0, 1],
        )

        self.assertTrue(
            kroni.kroni_consume_done,
        )
        self.assertEqual(
            kroni.kroni_hunger,
            1,
        )
        self.assertNotIn(
            removed,
            game.discard,
            "Fallback Consume must remove its subject from play, not recycle it.",
        )
        self.assertNotIn(
            removed,
            kroni.lord_guards + kroni.castle_guards + kroni.garrison + kroni.hand,
        )

    def test_after_reveal_lord_powers_use_locked_committed_order(self):
        game = sim.Game(
            ["Kroni"],
            ["Odradek"],
        )

        kroni, odradek = game.players
        kroni.alive = True
        kroni.kroni_hunger = 3
        kroni.action = "Hunt"
        kroni.tgt_pid = odradek.pid
        kroni.tgt_type = "Lord"
        kroni_low = sim.Card("Wright", 2)
        kroni.committed = [
            sim.Card("Vulture", 5),
            kroni_low,
        ]

        odradek.alive = True
        odradek.action = "Ward"
        odradek.ward_target = "Lord"
        odradek_low = sim.Card("Butcher", 3)
        odradek.committed = [
            odradek_low,
        ]

        game._phase_reveal(
            [0, 1],
        )

        self.assertEqual(
            game.discard,
            [
                odradek_low,
                kroni_low,
            ],
            "Aura and Recoil must follow the locked committed-value queue.",
        )
        self.assertTrue(
            odradek.odradek_recoil_done,
        )


if __name__ == "__main__":
    unittest.main()
