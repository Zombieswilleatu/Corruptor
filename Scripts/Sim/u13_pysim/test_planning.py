"""Boundary tests supplement full Godot differential fixtures."""

from copy import deepcopy
import unittest

from . import economy as e
from .planning import PlanningMatch
from .timeline import Timeline, HOOKS
from .verify_planning import setup, SPECS, packed_world, component_apply


class PlanningTests(unittest.TestCase):
    def planning_match(self):
        game = PlanningMatch(setup(0))
        while game.clock.hook != "submission_lock":
            d = game.state["world"]["data"]
            pending = d["game_economy"]["stockpile_pending"]
            if pending:
                op = dict(kind="stockpile", player_id=pending["player_id"], keep_id=pending["card_ids"][0])
            elif game.clock.hook == "present_public_state" and d["game_market"]["seat"] != 2:
                op = dict(kind="market", player_id=d["game_market"]["seat"], choice={"market": "Pass"})
            else:
                op = dict(kind="step", hook=game.clock.hook)
            self.assertNotEqual("invalid", game.apply(op)["action"])
        return game

    def test_second_plan_rejection_is_atomic_and_retryable(self):
        game = self.planning_match()
        hand = game.state["world"]["data"]["card_zones"]["hands"][0]
        plan = dict(powers=[], order=dict(action="Ward", lane="Lord", card_ids=[hand[0]]))
        before = game.snapshot()
        failed = game.apply(dict(kind="submit", plans=[plan, dict(powers=[], order={"action": "bogus"})]))
        self.assertEqual("invalid", failed["action"])
        self.assertEqual(before, game.snapshot())
        self.assertEqual("game_submitted", game.apply(dict(kind="submit", plans=[plan, dict(powers=[], order={})]))["action"])
        staged = game.snapshot()
        self.assertEqual(before["world"], staged["world"])
        self.assertEqual(before["events"], staged["events"])
        # Caller mutation cannot change the sealed input or a returned snapshot.
        plan["order"]["card_ids"].clear()
        staged["combat_orders"][0].clear()
        self.assertEqual(1, len(game.state["combat_orders"][0]["card_ids"]))
        game.apply(dict(kind="step", hook="submission_lock"))
        self.assertEqual(before["world"], game.state["presentation_world"])
        self.assertEqual(1, len(game.state["world"]["data"]["card_zones"]["committed"][0]))
        sealed = game.state["events"]["rows"][-1]
        self.assertIsNone(sealed["views"][1])
        self.assertEqual("COMBAT_ORDER_SEALED", sealed["event"]["type"])

    def test_future_hooks_and_powers_fail_explicitly_without_mutation(self):
        game = self.planning_match()
        before = game.snapshot()
        with self.assertRaises(e.Unsupported):
            game.apply(dict(kind="submit", plans=[dict(powers=[{"power_id": "GemDagger"}], order={}), dict(powers=[], order={})]))
        self.assertEqual(before, game.snapshot())
        game.apply(dict(kind="submit", plans=[dict(powers=[], order={}), dict(powers=[], order={})]))
        game.apply(dict(kind="step", hook="submission_lock"))
        before = game.snapshot()
        with self.assertRaisesRegex(e.Unsupported, "development"):
            game.apply(dict(kind="step", hook="development"))
        self.assertEqual(before, game.snapshot())

    def test_full_hand_recycles_before_limit_and_discard_draw_does_not(self):
        world = packed_world(SPECS[0])
        result = e.draw(world, 0, "seed", "draw-full")
        self.assertFalse(result["drawn"])
        self.assertEqual(8, len(e.zones(world)["deck"]))
        self.assertEqual([], e.zones(world)["discard"])
        world = packed_world(SPECS[1])
        self.assertTrue(e.draw(world, 0, "seed", "sift", True)["drawn"])
        self.assertFalse(e.draw(world, 1, "seed", "sift", True)["drawn"])
        self.assertEqual([], e.zones(world)["deck"])

    def test_stockpile_discard_is_available_to_next_seat(self):
        world = packed_world(SPECS[3])
        e.start_draw(world, setup(0)["seed"], 1)
        pending = deepcopy(world["data"]["game_economy"]["stockpile_pending"])
        self.assertEqual(0, pending["player_id"])
        self.assertEqual([], e.zones(world)["hands"][1])
        discarded = pending["card_ids"][0]
        events = e.choose_stockpile(world, 0, {"keep_id": pending["card_ids"][1]}, setup(0)["seed"], 1, "present_public_state")
        self.assertEqual([discarded], e.zones(world)["hands"][1])
        self.assertNotIn("keep_id", events[0]["views"][1]["data"])
        self.assertNotIn("card_id", events[1]["views"][0]["data"])
        self.assertTrue(e.cards_valid(world))

    def test_exhausted_market_preserves_physical_ids(self):
        world = packed_world(SPECS[5])
        old = e.zones(world)["market"][:]
        e.market_begin(world, setup(0)["seed"], 2)
        self.assertEqual(old, e.zones(world)["market"])
        self.assertEqual([], e.zones(world)["market_reserve"])
        self.assertTrue(e.cards_valid(world))

    def test_discard_rejects_duplicate_and_foreign_cards_atomically(self):
        world = packed_world(SPECS[0])
        identity = e.zones(world)["hands"][0][0]
        for pid, selected in [(0, [identity, identity]), (1, [identity])]:
            result = component_apply(world, dict(kind="discard", player_id=pid, card_ids=selected), 1)
            self.assertEqual("invalid", result["result"]["action"])
            self.assertEqual(world, result["world"])

    def test_cursor_rejections_and_completed_round_reset(self):
        clock = Timeline()
        clock.begin(1)
        before = clock.snapshot()
        for hook, payload in [("aftermath", None), (HOOKS[0], {"action": "invalid", "reason": "fixture"})]:
            self.assertEqual("invalid", clock.run(hook, payload)["action"])
            self.assertEqual(before, clock.snapshot())
        for hook in HOOKS:
            self.assertNotEqual("invalid", clock.run(hook)["action"])
        self.assertTrue(clock.completed)
        self.assertEqual("invalid", clock.run("aftermath")["action"])
        clock.begin(2)
        self.assertFalse(clock.completed)
        self.assertEqual([], clock.log)


if __name__ == "__main__":
    unittest.main()
