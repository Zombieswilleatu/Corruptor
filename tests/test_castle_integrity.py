import random
import unittest

import corruptor_sim as sim


class CastleIntegrityCanonicalTests(unittest.TestCase):
    def setUp(self):
        self.variant_before = sim.VARIANT.copy()
        self.features_before = sim.ACTIVE_FEATURES.copy()
        self.ruleset_before = sim.ACTIVE_RULESET
        self.constants_before = {
            name: getattr(sim, name)
            for name in (
                "WIN_SOULS", "DOMINION_TRACK", "DOMINION_REQUIREMENT",
                "FINAL_COLLAPSE_TRACK", "HAND_LIMIT", "GARRISON_MAX",
                "MAX_THREAT", "MARKET_SIZE", "MAX_ROUNDS",
            )
        }
        random.seed(6900)
        sim.activate_ruleset("lab-v6.5")

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant_before)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features_before)
        sim.ACTIVE_RULESET = self.ruleset_before
        for name, value in self.constants_before.items():
            setattr(sim, name, value)

    def test_current_profile_contract(self):
        self.assertEqual(sim.SIM_VERSION, "6.9.0-castle-integrity")
        self.assertEqual(sim.LAB_PROFILE_VERSION, "6.9.0-castle-integrity")
        self.assertEqual(sim.AI_POLICY, "heuristic-2026.08-castle-integrity")
        self.assertTrue(sim.VARIANT["castle_loadout"])
        self.assertEqual(sim.VARIANT["starting_castles"], 3)
        self.assertEqual(sim.VARIANT["castle_type_count"], 5)
        self.assertTrue(sim.VARIANT["castle_unique_types"])
        self.assertEqual(sim.VARIANT["castle_doctrine_denominator"], 5)
        self.assertEqual(sim.VARIANT["castle_damage_mode"], "arriving_strength")
        self.assertEqual(sim.VARIANT["castle_construction_mode"], "granular")
        self.assertEqual(sim.VARIANT["ruination_soul_bonus"], 1)
        self.assertEqual(sim.VARIANT["ruination_soul_source"], "enemy_siege")
        self.assertTrue(sim.VARIANT["castle_ruination_irreparable"])
        self.assertTrue(sim.VARIANT["profane_no_castle_gate"])
        self.assertFalse(sim.VARIANT["castle_scarring"])
        self.assertFalse(sim.VARIANT["castle_permanent_loss"])
        self.assertTrue(sim.ACTIVE_FEATURES["castle_integrity"])
        self.assertTrue(sim.ACTIVE_FEATURES["castle_granular_repair"])
        self.assertTrue(sim.ACTIVE_FEATURES["castle_construction"])
        self.assertTrue(sim.ACTIVE_FEATURES["castle_irreparable"])

    def test_setup_starts_with_any_three_and_flat_fourteen(self):
        game = sim.Game(["Orias"], ["Valak"])
        game._setup()
        orias = game.players[0]
        self.assertEqual(
            orias.castles,
            set(sim.CASTLE_PRIORITIES["Orias"][:3]),
        )
        self.assertNotIn("Keep", orias.castles)
        self.assertEqual(
            orias.castle_integrity,
            {castle: 14 for castle in orias.castles},
        )

    def test_arriving_strength_directly_damages_integrity(self):
        game = sim.Game(["Orias"], ["Valak"])
        attacker, defender = game.players
        attacker.alive = defender.alive = True
        defender.castles = {"Keep"}
        defender.castle_integrity = {"Keep": 14}
        attacker.committed = [sim.Card("Vulture", 5)]

        game._resolve_siege(attacker, defender, forced_target="Keep")

        self.assertEqual(game._structure_hit, 5)
        self.assertEqual(game._structure_damage, 5)
        self.assertEqual(game._structure_spill, 0)
        self.assertEqual(defender.castle_integrity["Keep"], 9)
        self.assertIn("Keep", defender.castles)

    def test_equal_arriving_strength_ruins_and_awards_only_siege_bonus(self):
        game = sim.Game(["Orias"], ["Valak"])
        attacker, defender = game.players
        attacker.alive = defender.alive = True
        defender.castles = {"Keep"}
        defender.castle_integrity = {"Keep": 14}
        attacker.committed = [
            sim.Card("Butcher", 5),
            sim.Card("Butcher", 4),
            sim.Card("Butcher", 4),
        ]  # 13 + Butcher pair = 14

        game._resolve_siege(attacker, defender, forced_target="Keep")

        self.assertEqual(game._structure_hit, 14)
        self.assertEqual(game._structure_damage, 14)
        self.assertEqual(defender.castle_integrity["Keep"], 0)
        self.assertNotIn("Keep", defender.castles)
        self.assertIn("Keep", defender.ruined_castles)
        self.assertEqual(attacker.souls, 2)  # base 1 + Ruination bonus 1
        self.assertEqual(game.stat_ruination_soul_bonus, 1)

    def test_structure_first_bypass_absorbs_then_spills_to_guards(self):
        game = sim.Game(["Orias"], ["Valak"])
        attacker, defender = game.players
        attacker.alive = defender.alive = True
        attacker.castles = {"SiegeEngine"}
        defender.castles = {"Keep"}
        defender.castle_integrity = {"Keep": 4}
        guard = sim.Card("Penitent", 3)
        defender.castle_guards = [guard]
        attacker.committed = [sim.Card("Vulture", 5), sim.Card("Wright", 3)]

        game._resolve_siege(attacker, defender, forced_target="Keep")

        self.assertEqual(game._structure_hit, 8)
        self.assertEqual(game._structure_damage, 4)
        self.assertEqual(game._structure_spill, 4)
        self.assertEqual(defender.castle_integrity["Keep"], 0)
        self.assertEqual(defender.castle_guards, [])
        self.assertIn(guard, game.discard)

    def test_granular_repair_uses_multiple_cards_and_one_action(self):
        game = sim.Game(["Orias"], ["Valak"])
        player = game.players[0]
        player.castles = set(sim.CASTLES)
        player.castle_integrity = {castle: 14 for castle in sim.CASTLES}
        player.castle_integrity["Keep"] = 4
        paid = [
            sim.Card("Wright", 4),
            sim.Card("Butcher", 3),
            sim.Card("Vulture", 3),
        ]
        player.hand = list(paid)

        game._ai_repair_only(player)

        self.assertEqual(player.castle_integrity["Keep"], 14)
        self.assertEqual(player.hand, [])
        self.assertTrue(all(card in game.discard for card in paid))
        self.assertEqual(game.stat_castle_repair_actions, 1)
        self.assertEqual(game.stat_repair_cards, 3)
        self.assertTrue(player.castle_action_used_this_round)

        player.hand = [sim.Card("Penitent", 5)]
        player.castle_integrity["Bastion"] = 5
        game._ai_repair_only(player)
        self.assertEqual(player.castle_integrity["Bastion"], 5)

    def test_bounded_repair_modifiers_trigger_once_per_action(self):
        game = sim.Game(["Kalligan"], ["Valak"])
        player = game.players[0]
        player.lord = "Kalligan"
        player.alive = True
        player.castles = set(sim.CASTLES)
        player.castle_integrity = {castle: 14 for castle in sim.CASTLES}
        player.castle_integrity["Keep"] = 7
        player.repair_token = 1
        player.hand = [sim.Card("Wright", 1)]
        game.breach = "Kalligan"

        game._ai_repair_only(player)

        self.assertEqual(player.castle_integrity["Keep"], 14)
        self.assertEqual(player.repair_token, 0)
        self.assertTrue(player.kalligan_repair_used)
        self.assertEqual(game.stat_repair_value, 1)

    def test_granular_construction_expands_beyond_three_to_all_five(self):
        game = sim.Game(["Orias"], ["Valak"])
        player = game.players[0]
        player.castles = set(sim.CASTLE_PRIORITIES["Orias"][:3])
        player.castle_integrity = {castle: 14 for castle in player.castles}

        player.hand = [sim.Card("Butcher", 5), sim.Card("Wright", 3)]
        game._ai_repair_only(player)
        self.assertEqual(player.castle_construction_progress["SummoningCircle"], 8)
        self.assertEqual(len(player.castles), 3)

        player.castle_action_used_this_round = False
        player.hand = [sim.Card("Vulture", 5), sim.Card("Penitent", 1)]
        game._ai_repair_only(player)
        self.assertIn("SummoningCircle", player.castles)
        self.assertEqual(player.castle_integrity["SummoningCircle"], 14)
        self.assertEqual(len(player.castles), 4)

        player.castle_action_used_this_round = False
        player.hand = [
            sim.Card("Butcher", 5), sim.Card("Wright", 5),
            sim.Card("Vulture", 4),
        ]
        game._ai_repair_only(player)
        self.assertEqual(player.castles, set(sim.CASTLES))
        self.assertEqual(game.stat_castles_built, 2)

    def test_ruined_type_cannot_be_repaired_or_reconstructed(self):
        game = sim.Game(["Orias"], ["Valak"])
        player = game.players[0]
        player.castles = {"Bastion", "Stockpile", "SiegeEngine"}
        player.ruined_castles = {"Keep"}
        player.castle_integrity = {
            "Keep": 0, "Bastion": 14, "Stockpile": 14, "SiegeEngine": 14,
        }
        player.hand = [sim.Card("Butcher", 5) for _ in range(3)]

        game._ai_repair_only(player)

        self.assertNotIn("Keep", player.castles)
        self.assertIn("Keep", player.ruined_castles)
        self.assertEqual(player.castle_integrity["Keep"], 0)
        self.assertNotIn("Keep", player.castle_construction_progress)

    def test_non_siege_ruination_gets_no_bonus_soul(self):
        game = sim.Game(["Gremory"], ["Valak"])
        gremory, opponent = game.players
        gremory.alive = True
        opponent.castles = {"Keep"}
        opponent.castle_integrity = {"Keep": 7}
        opponent.was_sieged = True
        opponent.last_sieged_castle = "Keep"
        gremory.hand = [
            sim.Card("Butcher", 1), sim.Card("Wright", 1),
            sim.Card("Vulture", 2), sim.Card("Penitent", 2),
        ]
        gremory.action = opponent.action = "Pass"

        game._phase_resolution([0, 1])

        self.assertEqual(gremory.souls, 0)
        self.assertEqual(game.stat_ruination_soul_bonus, 0)
        self.assertEqual(opponent.castle_integrity["Keep"], 0)

    def test_castle_doctrine_denominator_is_all_five_types(self):
        self.assertEqual(sim.castle_board_fraction(0), 0.0)
        self.assertEqual(sim.castle_board_fraction(3), 0.6)
        self.assertEqual(sim.castle_board_fraction(4), 0.8)
        self.assertEqual(sim.castle_board_fraction(5), 1.0)
        self.assertEqual(sim.castle_board_fraction(6), 1.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
