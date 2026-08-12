import random
import unittest

import corruptor_sim as sim


class LabV65RulesTests(unittest.TestCase):
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
        sim.activate_ruleset("lab-v6.5")

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant_before)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features_before)
        sim.ACTIVE_RULESET = self.ruleset_before
        for name, value in self.constants_before.items():
            setattr(sim, name, value)

    def test_profile_uses_the_measured_clock_bundle(self):
        self.assertEqual(sim.WIN_SOULS, 12)
        self.assertEqual(sim.DOMINION_TRACK, 12)
        self.assertEqual(sim.DOMINION_REQUIREMENT, 5)
        self.assertEqual(sim.FINAL_COLLAPSE_TRACK, 26)
        self.assertFalse(sim.VARIANT["reflex_bid"])
        self.assertTrue(sim.VARIANT["momentum"])
        self.assertTrue(sim.VARIANT["marching"])
        self.assertTrue(sim.ACTIVE_FEATURES["market_refresh"])
        self.assertTrue(sim.VARIANT["castle_loadout"])
        self.assertEqual(sim.VARIANT["starting_castles"], 3)
        self.assertFalse(sim.VARIANT["castle_scarring"])
        self.assertFalse(sim.VARIANT["castle_permanent_loss"])
        self.assertTrue(sim.ACTIVE_FEATURES["castle_integrity"])
        self.assertTrue(sim.ACTIVE_FEATURES["castle_granular_repair"])
        self.assertTrue(sim.ACTIVE_FEATURES["castle_construction"])
        self.assertTrue(sim.ACTIVE_FEATURES["castle_irreparable"])
        self.assertEqual(sim.LAB_PROFILE_VERSION, "7.4.0-castle-rules-lock")
        self.assertTrue(sim.VARIANT["fix_b"])
        self.assertEqual(sim.VARIANT["invocation_gate"], 7)
        self.assertEqual(sim.VARIANT["profane_ruins_req"], 2)
        self.assertFalse(sim.VARIANT["ai_dominion_drive"])
        self.assertFalse(sim.VARIANT["kroni_hunger_decay"])
        self.assertFalse(sim.VARIANT["neutral_tear_on_banish"])
        self.assertEqual(sim.VARIANT["gremory_summon_cost"], 0)
        self.assertTrue(sim.VARIANT["sigil_flat"])
        self.assertFalse(sim.VARIANT["humbaba_seal"])
        self.assertTrue(sim.VARIANT["humbaba_gate4"])
        self.assertFalse(sim.VARIANT["humbaba_patient"])
        self.assertFalse(sim.VARIANT["humbaba_sigil_commit"])
        self.assertTrue(sim.ACTIVE_FEATURES["humbaba_reactive_lane"])
        self.assertTrue(sim.ACTIVE_FEATURES["kani_hand_cost"])
        self.assertFalse(sim.ACTIVE_FEATURES["kani_threat_cost"])
        self.assertEqual(sim.ACTIVE_FEATURES["momentum_refund"], 1)
        self.assertEqual(sim.ACTIVE_FEATURES["veil_drift_after"], 15)
        self.assertEqual(sim.ACTIVE_FEATURES["veil_drift_growth"], 0.25)
        self.assertFalse(sim.ACTIVE_FEATURES["kal_inferno_threat"])
        self.assertTrue(sim.ACTIVE_FEATURES["kal_flame_tokens"])
        self.assertTrue(sim.ACTIVE_FEATURES["kal_scorch_escalate"])
        self.assertTrue(sim.ACTIVE_FEATURES["kal_lane_scorch"])

    def test_threshold_ward_is_frontline_instead_of_binary_turn(self):
        game = sim.Game(["Orias"], ["Valak"])
        defender, attacker = game.players
        defender.alive = True
        attacker.alive = True
        defender.action = "Ward"
        defender.ward_target = "Lord"
        defender.committed = [sim.Card("Penitent", 4)]
        guard = sim.Card("Vulture", 1)
        defender.lord_guards = [guard]
        attacker.action = "Hunt"
        attacker.tgt_pid = defender.pid
        attacker.tgt_type = "Lord"
        attacker.committed = [sim.Card("Butcher", 4)]

        game._phase_reveal([0, 1])
        game._resolve_hunt(attacker, defender)

        # Front-line Ward no longer writes the historical ward_turned cancel.
        # Equal incoming Strength is stopped at Ward before touching the Guard.
        self.assertNotIn("Lord", defender.ward_turned)
        self.assertTrue(defender.was_hunted)
        self.assertTrue(defender.alive)
        self.assertEqual(defender.lord_guards, [guard])

    def test_humbaba_no_longer_gets_a_free_sigil_commitment(self):
        game = sim.Game(["Humbaba"], ["Valak"])
        defender, attacker = game.players
        defender.alive = True
        attacker.alive = True
        defender.action = "Ward"
        defender.ward_target = "Lord"
        defender.committed = []
        attacker.action = "Hunt"
        attacker.tgt_pid = defender.pid
        attacker.tgt_type = "Lord"
        attacker.committed = [sim.Card("Butcher", 2)]

        game._phase_reveal([0, 1])

        self.assertNotIn("Lord", defender.ward_turned)
        self.assertEqual(defender.sigils["Lord"], "fresh")

    def test_uncontested_ward_refunds_only_its_lowest_card_to_garrison(self):
        game = sim.Game(["Orias"], ["Valak"])
        warder, opponent = game.players
        warder.alive = True
        opponent.alive = True
        warder.action = "Ward"
        warder.ward_target = "Castle"
        low = sim.Card("Penitent", 1)
        high = sim.Card("Wright", 4)
        warder.committed = [high, low]
        opponent.action = "Ward"
        opponent.ward_target = "Lord"

        game._phase_reveal([0, 1])

        self.assertEqual(warder.garrison, [low])
        self.assertEqual(warder.committed, [high])

    def test_flat_ward_ignores_keep_and_omen_modifiers(self):
        game = sim.Game(["Orias"], ["Valak"])
        player = game.players[0]
        player.castles = {"Keep"}
        game.neutral_tears = 3

        self.assertEqual(game._sigil_value(player, "fresh"), 2)
        self.assertEqual(game._sigil_value(player, "flipped"), 1)

    def test_fix_b_allows_profane_through_a_fresh_sigil(self):
        game = sim.Game(["Orias"], ["Valak"])
        player, opponent = game.players
        player.alive = True
        opponent.alive = True
        player.castles = {"Keep", "Stockpile", "SiegeEngine"}
        player.pending_profane = "Stockpile"
        opponent.sigils["Lord"] = "fresh"

        game._resolve_profane(player, opponent)

        self.assertNotIn("Stockpile", player.castles)
        self.assertIn("Stockpile", player.profaned_castles)
        self.assertTrue(player.profane_this_round)

    def test_marching_clash_awards_a_soul_and_keeps_card_conservation(self):
        game = sim.Game(["Orias"], ["Valak"])
        first, second = game.players
        first.marchers = [{
            "card": sim.Card("Butcher", 2),
            "value": 2,
            "lane": "Lord",
            "pos": 0,
        }]
        second.marchers = [{
            "card": sim.Card("Butcher", 2),
            "value": 2,
            "lane": "Lord",
            "pos": 0,
        }]

        game._march_advance()

        self.assertEqual(first.souls, 1)
        self.assertEqual(second.souls, 1)
        self.assertEqual(len(first.marchers), 0)
        self.assertEqual(len(second.marchers), 0)
        self.assertEqual(len(game.discard), 2)

    def test_march_arrival_at_threshold_gains_a_personal_tear(self):
        game = sim.Game(["Orias"], ["Valak"])
        player = game.players[0]
        marcher = sim.Card("Vulture", 5)
        player.marchers = [{
            "card": marcher,
            "value": 3,
            "lane": "Castle",
            "pos": 2,
        }]

        game._march_advance()

        self.assertEqual(player.tears, 1)
        self.assertIn(marcher, game.discard)
        self.assertEqual(player.marchers, [])

    def test_complete_ruination_is_permanent_without_scar_state(self):
        game = sim.Game(["Deimos"], ["Valak"])
        attacker, defender = game.players
        attacker.alive = True
        defender.alive = True
        defender.castles = {"Keep"}
        defender.castle_integrity = {"Keep": 1}
        attacker.committed = [sim.Card("Butcher", 5)]

        game._resolve_siege(attacker, defender, forced_target="Keep")

        self.assertNotIn("Keep", defender.castles)
        self.assertIn("Keep", defender.ruined_castles)
        self.assertNotIn("Keep", defender.lost_castles)
        self.assertEqual(defender.castle_integrity["Keep"], 0)
        self.assertEqual(defender.castle_scars, {})

    def test_banished_lord_uses_the_retained_threat_on_resummon(self):
        game = sim.Game(["Deimos"], ["Valak"])
        attacker, defender = game.players
        attacker.alive = True
        defender.alive = True
        defender.threat = 4

        game._lord_killed(attacker, defender)

        self.assertEqual(defender.return_threat_override, 3)
        defender.hand = [sim.Card("Butcher", 5), sim.Card("Wright", 5)]
        game._ai_summon(defender)

        self.assertTrue(defender.alive)
        self.assertEqual(defender.threat, 3)
        self.assertIsNone(defender.return_threat_override)

    def test_momentum_awards_the_second_action_for_a_precise_clear(self):
        game = sim.Game(["Deimos"], ["Kalligan"])
        attacker, defender = game.players
        attacker.alive = True
        defender.alive = True
        defender.threat = 4  # Kalligan base 4 -> defense 1.
        attacker.committed = [sim.Card("Butcher", 4)]

        game._resolve_hunt(attacker, defender)

        self.assertEqual(game.reflex_winner, attacker.pid)

    def test_granular_repair_does_not_create_scar_history(self):
        game = sim.Game(["Orias"], ["Valak"])
        player = game.players[0]
        player.castles = set(sim.CASTLES)
        player.castle_integrity = {castle: 14 for castle in sim.CASTLES}
        player.castle_integrity["Keep"] = 6
        player.hand = [sim.Card("Butcher", 5), sim.Card("Wright", 3)]

        game._ai_repair_only(player)

        # Strict Repair spends only the Wright:3; Butcher:5 remains in hand.
        self.assertEqual(player.castle_integrity["Keep"], 9)
        self.assertEqual(len(player.hand), 1)
        self.assertEqual(player.hand[0].suit, "Butcher")
        self.assertEqual(player.castle_repairs, {"Keep": 1})
        self.assertEqual(player.castle_scars, {})

    def test_market_rolls_unclaimed_offers_from_round_two(self):
        game = sim.Game(["Orias"], ["Valak"])
        game._setup()
        opening_offers = list(game.market)

        game.round = 1
        game._refresh_market_offers()
        self.assertEqual(game.market, opening_offers)

        # Market rollover is a separately declared lab feature.  Turning off
        # Marching for isolation must not silently turn off the Market.
        sim.VARIANT["marching"] = False
        game.round = 2
        game._refresh_market_offers()

        self.assertEqual(len(game.market), sim.MARKET_SIZE)
        self.assertFalse(any(card in game.market for card in opening_offers))
        self.assertFalse(any(card in game.discard for card in opening_offers))

    def test_market_refresh_recycles_discard_before_reusing_old_offers(self):
        game = sim.Game(["Orias"], ["Valak"])
        game._setup()
        rolled_offers = list(game.market)
        fresh_offers = [
            sim.Card("Butcher", 5),
            sim.Card("Penitent", 4),
            sim.Card("Vulture", 3),
        ]

        game.deck = []
        game.discard = list(fresh_offers)
        game.round = 2
        game._refresh_market_offers()

        self.assertCountEqual(game.market, fresh_offers)
        self.assertEqual(game.discard, [])
        self.assertCountEqual(game.deck, rolled_offers)


class DefaultRulesetIsolationTests(unittest.TestCase):
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

    def test_banishment_resets_threat_when_retention_is_off(self):
        game = sim.Game(["Deimos"], ["Orias"])
        attacker, defender = game.players
        attacker.alive = True
        defender.alive = True
        defender.threat = sim.MAX_THREAT

        game._lord_killed(attacker, defender)

        self.assertEqual(
            defender.threat,
            sim.LORD_STATS[defender.lord]["r"],
        )
        self.assertIsNone(defender.return_threat_override)

    def test_repair_history_stays_empty_when_its_mechanic_is_off(self):
        game = sim.Game(["Orias"], ["Valak"])
        player = game.players[0]
        player.castles = set(sim.CASTLES)
        player.castles.discard("SiegeEngine")
        player.ruined_castles = {"SiegeEngine"}
        player.hand = [sim.Card("Butcher", 5) for _ in range(3)]

        game._ai_repair_only(player)

        self.assertEqual(player.castle_repairs, {})
        self.assertEqual(player.castle_scars, {})

    def test_canonical_market_does_not_roll_offers(self):
        game = sim.Game(["Orias"], ["Valak"])
        game._setup()
        opening_offers = list(game.market)

        game.round = 2
        game._refresh_market_offers()

        self.assertEqual(game.market, opening_offers)
        self.assertFalse(sim.ACTIVE_FEATURES["market_refresh"])


if __name__ == "__main__":
    unittest.main()
