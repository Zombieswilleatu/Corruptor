import random
import unittest

import corruptor_sim as sim


class CastleRulesV74Tests(unittest.TestCase):
    """Python mirror of Scripts/Sim/CastleRulesV74Tests.gd.

    These tests intentionally exercise the locked seams directly rather than
    blessing whole-game snapshots.  The Godot suite and this suite should tell
    the same story even though their orchestration APIs differ.
    """

    def setUp(self):
        self.variant_before = sim.VARIANT.copy()
        self.features_before = sim.ACTIVE_FEATURES.copy()
        self.ruleset_before = sim.ACTIVE_RULESET
        self.lock_lords_before = sim.LOCK_LORDS
        self.constants_before = {
            name: getattr(sim, name)
            for name in (
                "WIN_SOULS", "DOMINION_TRACK", "DOMINION_REQUIREMENT",
                "FINAL_COLLAPSE_TRACK", "HAND_LIMIT", "GARRISON_MAX",
                "MAX_THREAT", "MARKET_SIZE", "MAX_ROUNDS",
            )
        }
        random.seed(7400)
        sim.activate_ruleset("lab-v6.5")
        sim.LOCK_LORDS = False

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant_before)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features_before)
        sim.ACTIVE_RULESET = self.ruleset_before
        sim.LOCK_LORDS = self.lock_lords_before
        for name, value in self.constants_before.items():
            setattr(sim, name, value)

    @staticmethod
    def _cards(*ids):
        out = []
        for card_id in ids:
            suit, value = card_id.split(":")
            out.append(sim.Card(suit, int(value)))
        return out

    @staticmethod
    def _set_castles(player, *names):
        player.castles = set(names)
        player.castle_integrity = {
            name: sim.castle_max_integrity(name) for name in names
        }
        player.ruined_castles = set()
        player.profaned_castles = set()
        player.lost_castles = set()

    @staticmethod
    def _prepare_game(game):
        game.round = 2
        game.winner = None
        game.win_by = ""
        game.breach = None
        game.breach_owner = -1
        game.reflex_winner = None
        game.neutral_tears = 0
        game.first_castle_neutral_done = False
        for player in game.players:
            player.souls = 0
            player.tears = 0
            player.threat = 0
            player.action = "Pass"
            player.tgt_pid = -1
            player.tgt_type = ""
            player.ward_target = ""
            player.committed = []
            player.lord_guards = []
            player.castle_guards = []
            player.sigils = {"Lord": "", "Castle": ""}
            player.ruined_castles = set()
            player.profaned_castles = set()
            player.lost_castles = set()
            player.ward_turned = set()

    def test_v74_profile(self):
        self.assertEqual(sim.SIM_VERSION, "7.5.0-suit-identities")
        self.assertEqual(sim.LAB_PROFILE_VERSION, "7.5.0-suit-identities")
        self.assertEqual(sim.AI_POLICY, "heuristic-2026.08-castle-contextual-v3")

        self.assertTrue(sim.VARIANT["ward_frontline"])
        self.assertEqual(sim.VARIANT["ward_offsuit_penalty"], 1)
        self.assertEqual(sim.VARIANT["castle_power_gate_mode"], "operational")
        self.assertEqual(sim.VARIANT["castle_operational_floor"], 7)
        self.assertTrue(sim.VARIANT["keep_sanctuary"])
        self.assertTrue(sim.VARIANT["bastion_wall"])
        self.assertEqual(sim.VARIANT["bastion_lord_def_bonus"], 0)
        self.assertTrue(sim.VARIANT["stockpile_filter"])
        self.assertTrue(sim.VARIANT["circle_blood_conduit"])
        self.assertEqual(sim.VARIANT["circle_conduit_cost"], 3)
        self.assertTrue(sim.VARIANT["circle_blood_summon"])
        self.assertEqual(sim.VARIANT["circle_blood_summon_cost"], 3)
        self.assertEqual(sim.VARIANT["circle_blood_summon_discount"], 3)
        self.assertEqual(sim.VARIANT["resummon_tear_mode"], "none")

        self.assertEqual(sim.VARIANT["attack_offsuit_penalty"], 1)
        self.assertEqual(sim.VARIANT["attack_penalty_exempt_suit"], "Butcher")

        self.assertEqual(sim.VARIANT["repair_wright_mode"], "tax")

        self.assertEqual(sim.VARIANT["construction_action_cap"], 5)
        self.assertTrue(sim.VARIANT["profane_requires_full_integrity"])
        self.assertFalse(sim.VARIANT["siege_engine_bypass"])
        self.assertEqual(sim.VARIANT["siege_engine_scope"], "siege")

        self.assertEqual(sim.VARIANT["resummon_delay_rounds"], 0)
        self.assertFalse(sim.VARIANT["circle_ignores_delay"])
        self.assertEqual(sim.VARIANT["stockpile_tokens"], 0)
        self.assertEqual(sim.VARIANT["reinforce_cap"], 0)
        self.assertEqual(sim.VARIANT["circle_discount"], 0)
        self.assertEqual(sim.CASTLE_COST, sim.CASTLE_DEF)
        self.assertIsNot(sim.CASTLE_COST, sim.CASTLE_DEF)
        self.assertTrue(sim.ACTIVE_FEATURES["castle_identity"])

    def test_ward_frontline_lifetime(self):
        game = sim.Game(["Deimos"], ["Valak"])
        self._prepare_game(game)
        attacker, defender = game.players

        attacker.lord = "Deimos"
        attacker.alive = True
        attacker.action = "Hunt"
        attacker.tgt_pid = 1
        attacker.tgt_type = "Lord"
        attacker.committed = self._cards("Butcher:5", "Butcher:1")

        defender.lord = "Valak"
        defender.alive = True
        defender.action = "Ward"
        defender.tgt_pid = 1
        defender.tgt_type = "Lord"
        defender.ward_target = "Lord"
        defender.committed = self._cards("Penitent:5", "Wright:3")
        defender.lord_guards = []
        defender.sigils["Lord"] = ""

        self.assertEqual(attacker.attack_value() + attacker.suit_bonus("Butcher"), 7)
        self.assertEqual(defender.ward_reinforcement_value(), 7)
        # Ward resolves first by committed initiative. Its cards must still be
        # present when the later Hunt reaches combat.
        game._phase_resolution([1, 0])

        self.assertTrue(defender.alive)
        self.assertEqual(defender.committed, [])
        self.assertEqual(attacker.committed, [])

    def test_keep_exact_excess(self):
        game = sim.Game(["Deimos"], ["Valak"])
        self._prepare_game(game)
        attacker, defender = game.players

        attacker.lord = "Deimos"
        attacker.alive = True
        attacker.committed = self._cards("Butcher:5", "Wright:2")
        defender.lord = "Valak"
        defender.alive = True
        defender.threat = 0
        defender.lord_guards = []
        defender.sigils["Lord"] = ""
        self._set_castles(defender, "Keep")
        defender.castle_integrity["Keep"] = 14

        game._resolve_hunt(attacker, defender)

        self.assertTrue(defender.alive)
        self.assertEqual(defender.castle_integrity["Keep"], 13)
        self.assertTrue(defender.castle_operational("Keep"))

    def test_bastion_wall_overflow(self):
        game = sim.Game(["Orias"], ["Valak"])
        self._prepare_game(game)
        attacker, defender = game.players

        attacker.lord = "Orias"
        attacker.alive = True
        attacker.committed = self._cards("Butcher:5", "Butcher:2")
        defender.lord = "Valak"
        defender.alive = True
        defender.castle_guards = []
        defender.sigils["Castle"] = ""
        self._set_castles(defender, "Bastion", "Stockpile")
        defender.castle_integrity["Bastion"] = 3  # Defunct but standing.
        defender.castle_integrity["Stockpile"] = 8

        game._resolve_siege(attacker, defender, forced_target="Stockpile")

        self.assertNotIn("Bastion", defender.castles)
        self.assertIn("Bastion", defender.ruined_castles)
        self.assertIn("Stockpile", defender.castles)
        self.assertEqual(defender.castle_integrity["Stockpile"], 3)
        self.assertEqual(game.neutral_tears, 1)

    def test_bastion_direct_target(self):
        game = sim.Game(["Orias"], ["Valak"])
        self._prepare_game(game)
        attacker, defender = game.players

        attacker.lord = "Orias"
        attacker.alive = True
        attacker.committed = self._cards("Butcher:5", "Butcher:5")
        self._set_castles(defender, "Bastion", "Stockpile")
        defender.castle_integrity["Bastion"] = 3
        defender.castle_integrity["Stockpile"] = 8

        game._resolve_siege(attacker, defender, forced_target="Bastion")

        self.assertNotIn("Bastion", defender.castles)
        self.assertEqual(defender.castle_integrity["Stockpile"], 8)

    def test_circle_blood_conduit(self):
        game = sim.Game(["Orias"], ["Valak"])
        self._prepare_game(game)
        player = game.players[0]
        self._set_castles(player, "SummoningCircle")
        player.castle_integrity["SummoningCircle"] = 14
        player.threat = 1

        game._gain_threat(player, 1)
        self.assertEqual(player.threat, 1)
        self.assertEqual(player.castle_integrity["SummoningCircle"], 11)

        # The 0 -> 1 step is not a meaningful defense breakpoint and should
        # not consume Circle Integrity.
        player.threat = 0
        player.castle_integrity["SummoningCircle"] = 14
        game._gain_threat(player, 1)
        self.assertEqual(player.threat, 1)
        self.assertEqual(player.castle_integrity["SummoningCircle"], 14)

    def test_circle_blood_offering_no_resummon_tear(self):
        game = sim.Game(["Kalligan"], ["Valak"])
        self._prepare_game(game)
        player = game.players[0]
        player.alive = False
        player.lord = "Kalligan"
        player.lord_pool = ["Kalligan"]
        player.first_summon_done = True
        player.hand = self._cards("Butcher:1")
        self._set_castles(player, "SummoningCircle")
        player.castle_integrity["SummoningCircle"] = 14
        game.neutral_tears = 0

        sim.LOCK_LORDS = True
        game._ai_summon(player)

        self.assertTrue(player.alive)
        self.assertEqual(player.hand, [])
        self.assertEqual(player.castle_integrity["SummoningCircle"], 11)
        self.assertEqual(game.neutral_tears, 0)

        # Blood Offering also applies to the opening forced Summon.
        opening = sim.Game(["Kalligan"], ["Valak"])
        self._prepare_game(opening)
        opener = opening.players[0]
        opener.alive = False
        opener.lord = "Kalligan"
        opener.lord_pool = ["Kalligan"]
        opener.first_summon_done = False
        opener.hand = self._cards("Butcher:1")
        self._set_castles(opener, "SummoningCircle")
        opener.castle_integrity["SummoningCircle"] = 14
        opening._ai_summon(opener, forced=True)
        self.assertTrue(opener.alive)
        self.assertEqual(opener.castle_integrity["SummoningCircle"], 11)
        self.assertEqual(opening.neutral_tears, 0)

    def test_stockpile_selective_stores(self):
        game = sim.Game(["Orias"], ["Valak"])
        self._prepare_game(game)
        player = game.players[0]
        player.hand = []
        self._set_castles(player, "Stockpile")
        player.castle_integrity["Stockpile"] = 14
        game.deck = self._cards(
            "Butcher:1", "Wright:2", "Vulture:3", "Penitent:4",
            "Butcher:5", "Wright:1", "Vulture:2",
        )
        game.discard = []

        game._run_draw_step(player)

        self.assertEqual(len(player.hand), 6)
        self.assertEqual(len(game.discard), 1)
        self.assertEqual(len(game.deck), 0)


    def test_profane_requires_full_integrity(self):
        player = sim.Player(0, ["Orias"])
        self._set_castles(player, "Stockpile")
        player.castle_integrity["Stockpile"] = 14
        self.assertTrue(sim.profane_eligible(player, "Stockpile"))
        player.castle_integrity["Stockpile"] = 13
        self.assertFalse(sim.profane_eligible(player, "Stockpile"))

    def test_bot_targets_through_bastion_and_budgets_for_wall(self):
        game = sim.Game(["Orias"], ["Valak"])
        self._prepare_game(game)
        attacker, defender = game.players
        attacker.lord = "Orias"
        attacker.alive = True
        defender.alive = True
        self._set_castles(defender, "Bastion", "Stockpile")
        defender.castle_integrity["Bastion"] = 3  # Defunct still screens.
        defender.castle_integrity["Stockpile"] = 8

        self.assertEqual(game._pick_siege_target(attacker, defender), "Stockpile")

        # Momentum doctrine sorts low-to-high. With the rear Stockpile (8),
        # standing Bastion (3), one-point Sigil hedge and one-point padding,
        # the target budget is 13. These four Butchers reach 16 only after the
        # fourth card; forgetting Bastion would stop at 11 after three.
        attacker.hand = self._cards(
            "Butcher:1", "Butcher:5", "Butcher:5", "Butcher:5"
        )
        game._commit_for_attack(attacker, defender, "Castle", "pressure_souls")
        self.assertEqual(len(attacker.committed), 4)

    def test_siege_engine_operational_gate(self):
        game = sim.Game(["Orias"], ["Valak"])
        self._prepare_game(game)
        player = game.players[0]
        self._set_castles(player, "SiegeEngine")
        player.committed = self._cards("Wright:5")

        player.castle_integrity["SiegeEngine"] = 14
        self.assertEqual(player.attack_value(siege=True), 5)
        self.assertEqual(player.attack_value(siege=False), 4)

        player.castle_integrity["SiegeEngine"] = 6
        self.assertEqual(player.attack_value(siege=True), 4)
        self.assertEqual(player.attack_value(siege=False), 4)


if __name__ == "__main__":
    unittest.main(verbosity=2)
