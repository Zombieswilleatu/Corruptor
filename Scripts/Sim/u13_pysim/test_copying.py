"""Exact data ownership and failure rollback regressions for faster copying."""

from copy import deepcopy
import unittest

from . import codec, economy as e
from .copying import copy_data
from .development import DevelopmentMatch
from .development_fixtures import setup, scripted_operations


class CopyingTests(unittest.TestCase):
    def game_at(self, count):
        game = DevelopmentMatch(setup(0))
        operations = scripted_operations(0)
        for op in operations[:count]:
            self.assertNotEqual("invalid", game.apply(op)["action"])
        return game, operations

    def test_float_bits_types_and_aliases_are_preserved_without_sharing_input(self):
        shared = [0.0, -0.0, 1, 1.0, True, None, "é", (1 << 63) - 1]
        source = {"a": shared, "b": shared, "nested": [{"ordered": [3, 1, 2]}]}
        result = copy_data(source)
        self.assertIsNone(codec.first_difference(deepcopy(source), result))
        self.assertIs(result["a"], result["b"])
        self.assertIsNot(shared, result["a"])
        result["a"].clear()
        result["nested"][0]["ordered"].reverse()
        self.assertEqual(8, len(shared))
        self.assertEqual([3, 1, 2], source["nested"][0]["ordered"])
        with self.assertRaises(TypeError):
            copy_data({"unexpected_object": object()})

    def test_preview_validates_without_reserving_or_emitting(self):
        game, operations = self.game_at(6)
        before = game.snapshot()
        for pid, plan in enumerate(operations[6]["plans"]):
            self.assertEqual([], game._accept_order(game.state["world"], pid, plan["order"], reserve=False))
        invalid = dict(action="Hunt", lane="Lord", card_ids=[e.zones(game.state["world"])["hands"][0][0]], target_id="missing")
        with self.assertRaisesRegex(e.Rejected, "hunt_target_invalid"):
            game._accept_order(game.state["world"], 0, invalid, reserve=False)
        self.assertEqual(before, game.snapshot())

    def test_development_second_guard_failure_restores_first_and_all_hook_clocks(self):
        game, operations = self.game_at(8)
        card = operations[6]["plans"][1]["order"]["guard_moves"][0]["card_id"]
        e.discard(game.state["world"], 1, [card])
        before, clock = game.snapshot(), game.clock.snapshot()
        failed = game.apply(operations[8])
        self.assertEqual("handler_rejected_hook", failed["reason"])
        self.assertEqual("transform_contract_error", failed["result"]["reason"])
        self.assertEqual(before, game.snapshot())
        self.assertEqual(clock, game.clock.snapshot())
        self.assertFalse(any(row["attributes"].get("role") == "guard" for row in game.state["world"]["entities"]["entities"]))

    def test_submission_lock_second_failure_restores_first_reservations(self):
        game, operations = self.game_at(7)
        card = operations[6]["plans"][1]["order"]["guard_moves"][0]["card_id"]
        e.discard(game.state["world"], 1, [card])
        before = game.snapshot()
        result = game.apply(operations[7])
        self.assertEqual("handler_rejected_hook", result["reason"])
        self.assertEqual(before, game.snapshot())

    def test_hook_failure_restores_nested_world_presentation_and_existing_events(self):
        for failure in (e.Rejected, e.Unsupported, RuntimeError):
            with self.subTest(failure=failure.__name__):
                game, _ = self.game_at(3)
                before = game.snapshot()
                def fail():
                    game.state["world"]["players"][0]["resources"]["souls"] += 1
                    game.state["presentation_world"]["data"]["card_zones"]["deck"].clear()
                    game.state["events"]["rows"][0]["event"]["data"].clear()
                    game.state["events"]["rows"].append(e.event("FAULT", {"value": 1}))
                    game.state["persistent"]["used_ids"].append("fault")
                    raise failure("directed_failure")
                game._hook = fail
                operation = dict(kind="step", hook=game.clock.hook)
                if failure is e.Rejected:
                    result = game.apply(operation)
                    self.assertEqual("handler_rejected_hook", result["reason"])
                else:
                    with self.assertRaises(failure):
                        game.apply(operation)
                self.assertEqual(before, game.snapshot())

    def test_exception_after_clock_change_restores_clock_too(self):
        game, _ = self.game_at(0)
        before, clock = game.snapshot(), game.clock.snapshot()
        def fail():
            game.clock.run(game.clock.hook)
            raise RuntimeError("after_clock")
        game._hook = fail
        with self.assertRaisesRegex(RuntimeError, "after_clock"):
            game.apply(dict(kind="step", hook=game.clock.hook))
        self.assertEqual(before, game.snapshot())
        self.assertEqual(clock, game.clock.snapshot())

    def test_public_views_and_snapshots_are_detached_after_later_mutations(self):
        game, operations = self.game_at(7)
        retained = game.snapshot()
        frozen = deepcopy(retained)
        game.apply(operations[7])
        game.apply(operations[8])
        self.assertEqual(frozen, retained)
        state = game.snapshot()
        row = state["events"]["rows"][-1]
        event_before = deepcopy(row["event"])
        row["views"][0]["data"].clear()
        self.assertEqual(event_before, row["event"])
        self.assertEqual(event_before, row["views"][1])
        self.assertNotEqual({}, game.state["events"]["rows"][-1]["views"][0]["data"])


if __name__ == "__main__":
    unittest.main()
