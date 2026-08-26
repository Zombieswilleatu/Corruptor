import unittest

import corruptor_sim as sim


class FractureSystemTests(unittest.TestCase):
    def setUp(self):
        if hasattr(sim, "activate_ruleset"):
            try:
                sim.activate_ruleset("lab-v6.5")
            except Exception:
                pass

    def _game(self, target_lord="Gremory"):
        game = sim.Game(["Deimos"], [target_lord])
        attacker = game.players[0]
        target = game.players[1]
        attacker.lord = "Deimos"
        attacker.alive = True
        target.lord = target_lord
        target.alive = True
        target.lord_guards.clear()
        target.castle_guards.clear()
        target.garrison.clear()
        target.marchers.clear()
        target.hand.clear()
        if hasattr(target, "castle_integrity"):
            target.castle_integrity.clear()
        return game, attacker, target

    def test_fracture_values_reuse_old_printed_resets(self):
        expected = {
            "Orias": 0,
            "Deimos": 0,
            "Valak": 1,
            "Kroni": 1,
            "Kalligan": 1,
            "Gremory": 2,
            "Odradek": 2,
            "Kanifous": 1,
            "Humbaba": 2,
        }
        self.assertEqual({k: sim.fracture_value(k) for k in expected}, expected)

    def test_subject_fracture_spreads_and_never_touches_hand(self):
        game, attacker, target = self._game("Gremory")
        lord_card = sim.Card("Penitent", 5)
        castle_card = sim.Card("Penitent", 3)
        hand_card = sim.Card("Butcher", 5)
        target.lord_guards.append(lord_card)
        target.castle_guards.append(castle_card)
        target.hand.append(hand_card)

        event = game._resolve_fracture(attacker, target, "subjects")
        self.assertEqual(lord_card.value, 3)
        self.assertEqual(castle_card.value, 1)
        self.assertEqual(hand_card.value, 5)
        self.assertEqual(len(event["events"]), 2)

    def test_garrison_is_a_subject_target(self):
        game, attacker, target = self._game("Valak")
        card = sim.Card("Penitent", 5)
        target.garrison.append(card)
        game._resolve_fracture(attacker, target, "subjects")
        self.assertEqual(card.value, 3)

    def test_marcher_is_a_subject_target_and_current_force_drops(self):
        game, attacker, target = self._game("Valak")
        card = sim.Card("Vulture", 5)
        target.marchers.append({
            "card": card,
            "value": 4,
            "lane": "Lord",
            "pos": 1,
        })
        event = game._resolve_fracture(attacker, target, "subjects")
        self.assertEqual(card.value, 3)
        self.assertEqual(target.marchers[0]["value"], 2)
        self.assertEqual(event["events"][0]["zone"], "Marcher")
        self.assertEqual(event["events"][0]["march_before"], 4)
        self.assertEqual(event["events"][0]["march_after"], 2)

    def test_infrastructure_fracture_spreads(self):
        game, attacker, target = self._game("Gremory")
        if not hasattr(target, "castle_integrity"):
            target.castle_integrity = {}
        target.castles = set(["Keep", "Bastion"]) if isinstance(target.castles, set) else ["Keep", "Bastion"]
        target.castle_integrity["Keep"] = 10
        target.castle_integrity["Bastion"] = 8
        event = game._resolve_fracture(attacker, target, "infrastructure")
        self.assertEqual(target.castle_integrity["Keep"], 8)
        self.assertEqual(target.castle_integrity["Bastion"], 6)
        self.assertEqual(len(event["events"]), 2)

    def test_infrastructure_can_ruin_without_siege_rewards(self):
        game, attacker, target = self._game("Valak")
        if not hasattr(target, "castle_integrity"):
            target.castle_integrity = {}
        target.castles = set(["Bastion"]) if isinstance(target.castles, set) else ["Bastion"]
        if hasattr(target.ruined_castles, "clear"):
            target.ruined_castles.clear()
        target.castle_integrity["Bastion"] = 2
        souls_before = attacker.souls
        game._resolve_fracture(attacker, target, "infrastructure")
        self.assertNotIn("Bastion", target.castles)
        self.assertIn("Bastion", target.ruined_castles)
        self.assertEqual(target.castle_integrity["Bastion"], 0)
        self.assertEqual(attacker.souls, souls_before)

    def test_summon_return_baseline_is_zero_but_explicit_returns_survive(self):
        game, attacker, target = self._game("Gremory")
        target.return_threat_override = None
        target.vessel_offered_lord = ""
        self.assertEqual(game._summon_return_threat(target, "Gremory"), 0)
        target.return_threat_override = 2
        self.assertEqual(game._summon_return_threat(target, "Gremory"), 2)
        target.return_threat_override = None
        target.vessel_offered_lord = "Gremory"
        self.assertEqual(game._summon_return_threat(target, "Gremory"), 2)

    def test_lord_killed_resets_threat_and_records_fracture(self):
        game, attacker, target = self._game("Valak")
        target.threat = 3
        target.return_threat_override = 2
        target.garrison.append(sim.Card("Penitent", 5))
        game._lord_killed(attacker, target, "subjects")
        self.assertEqual(target.threat, 0)
        self.assertIsNone(target.return_threat_override)
        self.assertEqual(target.garrison[0].value, 3)
        self.assertEqual(game.last_fracture_event["fracture"], 1)


if __name__ == "__main__":
    unittest.main()
