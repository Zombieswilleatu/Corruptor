import unittest

import corruptor_sim as sim


class SuitIdentityV75Tests(unittest.TestCase):
    def setUp(self):
        sim.activate_ruleset("lab-v6.5")

    def test_profile_locks_canonical_suit_identity_flags(self):
        self.assertEqual(sim.SIM_VERSION, "7.5.0-suit-identities")
        self.assertEqual(sim.LAB_PROFILE_VERSION, "7.5.0-suit-identities")
        self.assertEqual(sim.AI_POLICY, "heuristic-2026.08-castle-contextual-v3")
        self.assertEqual(sim.VARIANT["ward_offsuit_penalty"], 1)
        self.assertEqual(sim.VARIANT["ward_penalty_exempt_suit"], "Penitent")
        self.assertEqual(sim.VARIANT["ward_offsuit_floor"], 1)
        self.assertFalse(sim.VARIANT["keep_ignores_ward_tax"])
        self.assertTrue(sim.VARIANT["vulture_recon"])

    def test_ward_tax_penitent_exempt_and_floor_one(self):
        player = sim.Player(0, ["Vanilla"])
        self.assertEqual(sim.effective_ward_value(player, sim.Card("Penitent", 4)), 4)
        self.assertEqual(sim.effective_ward_value(player, sim.Card("Butcher", 4)), 3)
        self.assertEqual(sim.effective_ward_value(player, sim.Card("Vulture", 1)), 1)
        player.committed = [
            sim.Card("Penitent", 4),
            sim.Card("Butcher", 4),
            sim.Card("Vulture", 1),
        ]
        self.assertEqual(player.ward_value(), 8)

    def test_recon_hunt_prefers_unattacked_castle_guard_area(self):
        game = sim.Game(["Vanilla"], ["Vanilla"], seed=10)
        player, opponent = game.players
        player.action = "Hunt"
        player.committed = [sim.Card("Vulture", 2)]
        opponent.lord_guards = [sim.Card("Butcher", 5)]
        opponent.castle_guards = [sim.Card("Wright", 1), sim.Card("Penitent", 4)]
        zone = game._resolve_vulture_recon(player)
        self.assertEqual(zone, "Castle")
        self.assertTrue(all(card.guard_revealed for card in opponent.castle_guards))
        self.assertFalse(opponent.lord_guards[0].guard_revealed)

    def test_recon_siege_prefers_unattacked_lord_guard_area(self):
        game = sim.Game(["Vanilla"], ["Vanilla"], seed=11)
        player, opponent = game.players
        player.action = "Siege"
        player.committed = [sim.Card("Vulture", 3)]
        opponent.lord_guards = [sim.Card("Butcher", 5), sim.Card("Wright", 2)]
        opponent.castle_guards = [sim.Card("Penitent", 4)]
        zone = game._resolve_vulture_recon(player)
        self.assertEqual(zone, "Lord")
        self.assertTrue(all(card.guard_revealed for card in opponent.lord_guards))
        self.assertFalse(opponent.castle_guards[0].guard_revealed)

    def test_recon_passive_action_chooses_more_unknown_cards(self):
        game = sim.Game(["Vanilla"], ["Vanilla"], seed=12)
        player, opponent = game.players
        player.action = "Ward"
        player.committed = [sim.Card("Vulture", 3)]
        opponent.lord_guards = [sim.Card("Butcher", 5)]
        opponent.castle_guards = [sim.Card("Penitent", 2), sim.Card("Wright", 3)]
        zone = game._resolve_vulture_recon(player)
        self.assertEqual(zone, "Castle")

    def test_recon_requires_committed_vulture_and_reveals_whole_current_area(self):
        game = sim.Game(["Vanilla"], ["Vanilla"], seed=13)
        player, opponent = game.players
        player.action = "Ward"
        player.committed = [sim.Card("Butcher", 5)]
        opponent.lord_guards = [sim.Card("Butcher", 5), sim.Card("Wright", 4)]
        self.assertIsNone(game._resolve_vulture_recon(player))
        self.assertFalse(any(card.guard_revealed for card in opponent.lord_guards))

        player.committed.append(sim.Card("Vulture", 1))
        self.assertEqual(game._resolve_vulture_recon(player), "Lord")
        self.assertTrue(all(card.guard_revealed for card in opponent.lord_guards))
        newly_added = sim.Card("Penitent", 5)
        opponent.lord_guards.append(newly_added)
        self.assertFalse(newly_added.guard_revealed)

    def test_recon_information_changes_guard_estimate_without_changing_pair_bonus(self):
        game = sim.Game(["Vanilla"], ["Vanilla"], seed=14)
        player, opponent = game.players
        guards = [sim.Card("Butcher", 5), sim.Card("Wright", 5)]
        opponent.castle_guards = guards
        exact = sum(sim.effective_guard_value(card) for card in guards)
        for card in guards:
            card.guard_revealed = True
        self.assertEqual(game._est_guards(guards, context="test"), exact)
        player.committed = [sim.Card("Vulture", 2), sim.Card("Vulture", 3)]
        self.assertEqual(player.suit_count("Vulture"), 2)


if __name__ == "__main__":
    unittest.main()
