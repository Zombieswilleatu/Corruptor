"""Ownership, rejection and boundary regressions for the ordinary slice."""

import unittest
from unittest.mock import patch

from . import codec, economy as e, recruitment
from .full_match_inputs import next_operation
from .copying import copy_data
from .resolution import ResolutionMatch, Ordinary
from .resolution_fixtures import inputs, component_initial, component_apply


def prepared(name):
    spec = next(c for c in inputs()["components"] if c["name"] == name)
    w = component_initial(spec)
    for op in spec["operations"]:
        if op["kind"] == "resolve": return w, op
        w = component_apply(w, op)["world"]
    raise AssertionError("component missing resolution")


class ResolutionTests(unittest.TestCase):
    def same(self, left, right):
        self.assertIsNone(codec.first_difference(left, right))

    def test_second_player_spawn_collision_rolls_back_sigils_and_first_army(self):
        w, op = prepared("reveal_second_player_rejection")
        before = copy_data(w)
        result = component_apply(w, op)
        self.assertEqual(result["result"], dict(action="invalid", reason="entity_identity_already_used"))
        self.same(before, result["world"])
        self.same(before, w)

    def test_owned_match_failure_restores_world_events_and_cursor(self):
        spec = inputs()["games"][0]
        game = ResolutionMatch(spec["setup"])
        while game.clock.hook != "commitment_reveal":
            self.assertNotEqual("invalid", game.apply(next_operation(game))["action"])
        before = game.snapshot()
        original = Ordinary.reveal
        def fail_after_recruitment(owner):
            original(owner)
            raise RuntimeError("after spawning")
        with patch.object(Ordinary, "reveal", fail_after_recruitment):
            with self.assertRaisesRegex(RuntimeError, "after spawning"):
                game.apply(dict(kind="step", hook="commitment_reveal"))
        self.same(before, game.snapshot())
        self.same(before["runtime"], game.clock.snapshot())
        self.assertNotEqual(game.apply(dict(kind="step", hook="commitment_reveal"))["action"], "invalid")

    def test_post_resolution_boundary_fails_without_advancing(self):
        spec = inputs()["games"][0]
        game = ResolutionMatch(spec["setup"])
        while game.clock.hook != "post_resolution_spawns":
            self.assertNotEqual("invalid", game.apply(next_operation(game))["action"])
        before = game.snapshot()
        with self.assertRaises(e.Unsupported): game.apply(dict(kind="step", hook="post_resolution_spawns"))
        self.same(before, game.snapshot())

    def test_pure_result_and_event_views_do_not_alias_world_or_inputs(self):
        w, op = prepared("bastion_overflow_rewards")
        before, original_op = copy_data(w), copy_data(op)
        result = component_apply(w, op)
        self.same(before, w); self.same(original_op, op)
        facts = copy_data(result["result"])
        for row in result["world"]["entities"]["entities"]:
            if row["kind"] == "castle": row["attributes"]["integrity"] = 123
        self.same(facts, result["result"])

    def test_strict_guard_threshold_survives_equality(self):
        for strength, lost in ((5, 0), (6, 1)):
            w, op = prepared("guard_threshold_"+str(strength))
            result = component_apply(w, op)
            fact = next(r["event"] for r in result["result"]["events"] if r["event"]["type"] == "SIEGE_RESOLVED")
            self.assertEqual(fact["data"]["guards_defeated"], lost)

    def test_spawn_positions_ignore_registry_order_without_rewriting_ids(self):
        w, _ = prepared("recruitment_other_suits")
        for ordinal in range(8):
            row = recruitment.create(w, "spawn-test", ordinal, 0, recruitment.profile("Wright", "Castle", 0, 1, 2))
            recruitment.place_spawn(w, row, "position:é")
        other = copy_data(w)
        other["entities"]["entities"].reverse()
        for world in (w, other):
            row = recruitment.create(world, "spawn-test", 8, 0, recruitment.profile("Wright", "Castle", 0, 1, 2))
            recruitment.place_spawn(world, row, "position:é")
        self.same(w, other)

    def test_second_hunt_resolves_after_its_own_lord_is_banished(self):
        w, op = prepared("opposing_hunts_after_banishment")
        result = component_apply(w, op)
        hunts = [r["event"]["data"] for r in result["result"]["events"] if r["event"]["type"] == "HUNT_RESOLVED"]
        self.assertEqual([r["player_id"] for r in hunts], [0, 1])
        self.assertTrue(all(r["banished"] for r in hunts))

    def test_artillery_kill_awards_two_souls_to_engine_owner(self):
        w, op = prepared("artillery_disables_later_engine")
        target = next(c for c in w["entities"]["entities"] if c["kind"] == "castle" and c["owner"] == 1 and c["attributes"]["combat_profile"] == "siege_engine")
        target["attributes"]["integrity"] = 2
        before = [p["resources"]["souls"] for p in w["players"]]
        result = component_apply(w, op)
        shots = [r["event"]["data"] for r in result["result"]["events"] if r["event"]["type"] == "ARTILLERY_FIRED"]
        self.assertEqual(shots[0]["soul_gain"], 2)
        self.assertEqual(result["world"]["players"][0]["resources"]["souls"], before[0] + 2)
        self.assertEqual(result["world"]["players"][1]["resources"]["souls"], before[1])
        self.assertEqual(w["players"][0]["resources"]["souls"], before[0])

    def test_engine_disabled_by_earlier_shot_does_not_fire(self):
        w, op = prepared("artillery_disables_later_engine")
        result = component_apply(w, op)
        shots = [r["event"]["data"] for r in result["result"]["events"] if r["event"]["type"] == "ARTILLERY_FIRED"]
        self.assertEqual([r["player_id"] for r in shots], [0])

    def test_gem_dagger_draw_id_is_private_and_trigger_is_once_per_round(self):
        w, op = prepared("gem_dagger_private_draws")
        result = component_apply(w, op)
        rows = [r for r in result["result"]["events"] if r["event"]["type"] == "GEM_DAGGER"]
        self.assertEqual(len(rows), 2)
        for row in rows:
            pid = row["event"]["data"]["player_id"]
            self.assertIn("card_id", row["views"][pid]["data"])
            self.assertNotIn("card_id", row["views"][1-pid]["data"])


if __name__ == "__main__": unittest.main()
