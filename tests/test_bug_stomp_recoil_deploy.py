import pathlib
import unittest

import corruptor_sim as sim


ROOT = pathlib.Path(__file__).resolve().parents[1]


class PsychicRecoilMinimumCommitmentTests(unittest.TestCase):
    def setUp(self):
        sim.activate_ruleset("lab-v6.5")

    def tearDown(self):
        # Do not leak the lab profile into the rest of unittest discovery.
        sim.activate_ruleset("de-v2")

    def _fixture(self):
        game = sim.Game(["Humbaba"], ["Odradek"], seed=20260729)
        game._setup()
        attacker = game.players[0]
        odradek = game.players[1]
        attacker.lord = "Humbaba"
        attacker.alive = True
        odradek.lord = "Odradek"
        odradek.alive = True
        odradek.odradek_recoil_done = False
        odradek.odradek_bank = None
        odradek.souls = 0
        cards = list(attacker.hand[:3])
        self.assertGreaterEqual(len(cards), 2)
        return game, attacker, odradek, cards

    def test_zero_cards_do_not_fire_or_spend_recoil(self):
        game, attacker, odradek, _ = self._fixture()
        attacker.committed = []
        result = game._odradek_recoil(attacker, odradek)
        self.assertFalse(result["fired"])
        self.assertFalse(odradek.odradek_recoil_done)
        self.assertEqual(odradek.souls, 0)
        self.assertIsNone(odradek.odradek_bank)

    def test_one_card_does_not_fire_and_later_two_card_attack_can(self):
        game, attacker, odradek, cards = self._fixture()
        attacker.committed = [cards[0]]
        result = game._odradek_recoil(attacker, odradek)
        self.assertFalse(result["fired"])
        self.assertFalse(odradek.odradek_recoil_done)
        self.assertEqual(attacker.committed, [cards[0]])
        self.assertEqual(odradek.souls, 0)
        self.assertIsNone(odradek.odradek_bank)

        attacker.committed = [cards[0], cards[1]]
        result = game._odradek_recoil(attacker, odradek)
        self.assertTrue(result["fired"])
        self.assertTrue(odradek.odradek_recoil_done)
        self.assertEqual(odradek.souls, 1)
        self.assertEqual(len(attacker.committed), 1)

    def test_two_cards_remove_second_highest_in_lab_rules(self):
        game, attacker, odradek, cards = self._fixture()
        committed = [cards[0], cards[1]]
        expected = sorted(committed, key=lambda c: c.value, reverse=True)[1]
        attacker.committed = list(committed)
        result = game._odradek_recoil(attacker, odradek)
        self.assertTrue(result["fired"])
        self.assertIs(odradek.odradek_bank, expected)
        self.assertNotIn(expected, attacker.committed)


class BugStompSourceContractTests(unittest.TestCase):
    def test_godot_recoil_has_current_two_card_gate(self):
        text = (ROOT / "Scripts/Sim/OdradekInterlockEngine.gd").read_text(encoding="utf-8")
        gate = text.index("if attacker.committed.size() < 2:")
        spend = text.index("odradek.odradek_recoil_done = true")
        self.assertLess(gate, spend)
        self.assertNotIn("if committed.size() == 1:", text)

    def test_deploy_ui_obeys_repair_rule_flag(self):
        text = (ROOT / "Prototype/PlayablePrototype.gd").read_text(encoding="utf-8")
        self.assertIn("not bool(controller.rules.repair_blocks_hand_deploy)", text)

    def test_deploy_reservation_is_occurrence_aware(self):
        text = (ROOT / "Prototype/PlayablePrototype.gd").read_text(encoding="utf-8")
        self.assertIn('"Hand",\n\t\t\t\t\tcard_identifier,\n\t\t\t\t\thand_index', text)
        self.assertIn('"Garrison",\n\t\t\t\t\tgarrison_identifier,\n\t\t\t\t\tgarrison_index', text)
        self.assertIn("var reserved_count: int = 0", text)
        self.assertIn("var occurrence: int = 0", text)
        self.assertIn("occurrence <= reserved_count", text)

    def test_doctrine_does_not_assume_one_card_is_eaten(self):
        godot = (ROOT / "Scripts/Sim/BotDoctrine.gd").read_text(encoding="utf-8")
        python_sim = (ROOT / "corruptor_sim.py").read_text(encoding="utf-8")
        softmax = (ROOT / "corruptor_softmax_policy.py").read_text(encoding="utf-8")
        self.assertIn("var unopposed_total: int = 0", godot)
        self.assertNotIn("if len(committed) <= 1:\n                    return 0", python_sim)
        self.assertNotIn("if len(committed) <= 1:\n                return 0", softmax)


if __name__ == "__main__":
    unittest.main()
