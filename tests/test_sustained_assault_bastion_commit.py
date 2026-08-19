import random
import unittest

import corruptor_sim as sim


class SustainedAssaultAndBastionCommitTests(unittest.TestCase):
    def setUp(self):
        self.variant_before = sim.VARIANT.copy()
        self.features_before = sim.ACTIVE_FEATURES.copy()
        self.ruleset_before = sim.ACTIVE_RULESET
        self.lock_lords_before = sim.LOCK_LORDS
        random.seed(74001)
        sim.activate_ruleset("lab-v6.5")
        sim.LOCK_LORDS = True

    def tearDown(self):
        sim.VARIANT.clear()
        sim.VARIANT.update(self.variant_before)
        sim.ACTIVE_FEATURES.clear()
        sim.ACTIVE_FEATURES.update(self.features_before)
        sim.ACTIVE_RULESET = self.ruleset_before
        sim.LOCK_LORDS = self.lock_lords_before

    @staticmethod
    def _cards(*ids):
        result = []
        for card_id in ids:
            suit, value = card_id.split(":")
            result.append(sim.Card(suit, int(value)))
        return result

    def test_sustained_assault_primary_action_threat(self):
        game = sim.Game(["Deimos"], ["Valak"], seed=74001)
        attacker, defender = game.players
        attacker.lord = "Deimos"
        defender.lord = "Valak"
        attacker.alive = defender.alive = True

        defender.action = "Profane"
        defender.tgt_pid = 1

        game.round = 1
        attacker.action = "Hunt"
        attacker.tgt_pid = 1
        game._phase_reveal()
        self.assertEqual(attacker.threat, 1)

        game.round = 2
        attacker.action = "Hunt"
        attacker.tgt_pid = 1
        game._phase_reveal()
        self.assertEqual(attacker.threat, 3)

        game.round = 3
        attacker.action = "Profane"
        attacker.tgt_pid = 0
        game._phase_reveal()

        attacker.threat = 0
        game.round = 4
        attacker.action = "Siege"
        attacker.tgt_pid = 1
        game._phase_reveal()
        self.assertEqual(attacker.threat, 0)

        game.round = 5
        attacker.action = "Siege"
        attacker.tgt_pid = 1
        game._phase_reveal()
        self.assertEqual(attacker.threat, 1)

        game.round = 6
        attacker.action = "Profane"
        attacker.tgt_pid = 0
        game._phase_reveal()

        attacker.threat = 0
        game.round = 7
        attacker.action = "Hunt"
        attacker.tgt_pid = 1
        game._phase_reveal()
        self.assertEqual(attacker.threat, 1)

        game.round = 8
        attacker.action = "Siege"
        attacker.tgt_pid = 1
        game._phase_reveal()
        self.assertEqual(attacker.threat, 2)

    def test_bastion_is_immediate_commitment_objective(self):
        game = sim.Game(["Valak"], ["Orias"], seed=74002)
        attacker, defender = game.players
        game.round = 2
        game.breach = None

        attacker.lord = "Valak"
        attacker.alive = True
        attacker.castles = set()
        attacker.hand = self._cards(
            "Butcher:5",
            "Butcher:4",
            "Vulture:5",
            "Wright:5",
            "Penitent:5",
        )

        defender.lord = "Orias"
        defender.alive = True
        # Exercise the canonical live screening switch explicitly. Keep the
        # historical alias false so this test catches accidental old-key reads.
        sim.VARIANT["bastion_fortified"] = False
        sim.VARIANT["bastion_wall"] = True
        defender.castles = {"Bastion", "Stockpile"}
        defender.ruined_castles = set()
        defender.profaned_castles = set()
        defender.disabled_castle_powers = set()
        defender.castle_integrity = {
            "Bastion": 9,
            "Stockpile": 14,
        }
        defender.castle_guards = []
        defender.sigils["Castle"] = ""

        game._commit_for_attack(
            attacker,
            defender,
            "Castle",
            "neutral",
        )

        self.assertEqual(len(attacker.committed), 3)
        effective = sum(
            sim.effective_attack_value(attacker, card, "Castle")
            for card in attacker.committed
        )
        self.assertGreaterEqual(effective, 11)
        self.assertEqual(len(attacker.hand), 2)


if __name__ == "__main__":
    unittest.main()
