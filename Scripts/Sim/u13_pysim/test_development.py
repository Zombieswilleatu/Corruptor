"""Directed regressions for transactions, one-time Work and stable pair identity."""

from copy import deepcopy
import unittest

from . import development as d, economy as e, opening
from .development_fixtures import component_world, component_apply, choice, move, setup, scripted_operations
from .planning import PlanningMatch


class DevelopmentTests(unittest.TestCase):
    def setUp(self):
        self.world = component_world()

    def apply(self, op):
        applied = component_apply(self.world, op)
        self.assertNotEqual(applied["result"]["action"], "invalid")
        self.world = applied["world"]
        return applied["result"]

    def give(self, suit, pid=0):
        identity = next(row["id"] for row in self.world["entities"]["entities"]
                        if row["kind"] == "card" and row["owner"] == -1 and row["attributes"]["suit"] == suit)
        self.apply(dict(kind="fixture_give", card_id=identity, player_id=pid))
        return identity

    def stage(self, number, moves=None, selected=None, other=None):
        self.apply(dict(kind="fixture_stage", round=number, moves=[moves or [], other or []], choices=[selected or {}, {}]))

    def settle(self, number):
        self.apply(dict(kind="deploy", round=number, player_order=[0, 1]))
        return self.apply(dict(kind="work", round=number, player_order=[0, 1]))

    def make_pair(self, suit="Wright", target=""):
        identities = [self.give(suit) for _ in range(2)]
        self.stage(1, [move(identities[0], "Lord", 2), move(identities[1], "Lord", 0)], choice(target))
        self.settle(1)
        return identities

    def test_bad_second_guard_rolls_back_first_and_ledger(self):
        first, second = self.give("Wright"), self.give("Penitent", 1)
        self.stage(1, [move(first, "Lord", 0)], other=[move(second, "Castle", 0)])
        e.discard(self.world, 1, [second])
        before = deepcopy(self.world)
        with self.assertRaisesRegex(e.Rejected, "reserved_guard_missing"):
            d.deploy(self.world, 1, [0, 1])
        self.assertEqual(before, self.world)
        self.assertIn(first, e.zones(self.world)["hands"][0])
        self.assertEqual(0, self.world["data"]["guard_deployment_round"])

    def test_wright_and_guards_pay_once_passive_persists_until_clear(self):
        target = opening.castle_id(0, 3)
        self.make_pair(target=target)
        self.assertEqual(10, e.entity(self.world, target)["attributes"]["integrity"])
        self.stage(2)
        self.settle(2)
        self.assertEqual(13, e.entity(self.world, target)["attributes"]["integrity"])
        self.assertEqual([], d.work(self.world, 2, [0, 1]))
        self.stage(3, selected=choice(""))
        self.settle(3)
        self.assertEqual(13, e.entity(self.world, target)["attributes"]["integrity"])

    def test_wright_build_repair_reconstruction_and_bot_projection(self):
        from types import SimpleNamespace
        from u13_doctrine.defensive_plans import development as project
        for mode, expected in (("building", 10), ("active", 5), ("ruined", 10)):
            for lane in ("Lord", "Castle"):
                with self.subTest(mode=mode, lane=lane):
                    self.world = component_world()
                    target = opening.castle_id(0, 4)
                    castle = e.entity(self.world, target)
                    castle["attributes"].update(integrity=0 if mode != "active" else 5,
                        construction_state="building" if mode == "building" else "active",
                        status="ruined" if mode == "ruined" else "standing")
                    first, second = self.give("Wright"), self.give("Wright")
                    moves = [move(first, lane, 0), move(second, lane, 1)]
                    f = SimpleNamespace(world=deepcopy(self.world), pid=0, v={"round":1},
                        by_id={row["id"]:row for row in self.world["entities"]["entities"]})
                    predicted, details = project(f, {"order":{"guard_moves":moves, "castle_action":choice(target)}})
                    before = castle["attributes"]["integrity"]
                    self.stage(1, moves, choice(target)); self.settle(1)
                    after = e.entity(self.world, target)["attributes"]["integrity"]
                    self.assertEqual(expected, after-before)
                    self.assertEqual(after, e.entity(predicted, target)["attributes"]["integrity"])
                    self.assertEqual(7 if mode != "active" else 5, details["guard_work"])

    def test_every_identity_dimension_can_break_pair_permanently(self):
        self.make_pair()
        before = deepcopy(self.world)
        first = self.world["data"]["guard_work"]["pairs"][0]["ids"][0]
        for field, value in [("owner", 1), ("role", "marcher"), ("lane", "Castle"), ("slot", 1), ("suit", "Vulture")]:
            with self.subTest(field=field):
                self.world = deepcopy(before)
                card = e.entity(self.world, first)
                container = card if field == "owner" else card["attributes"]
                original = container[field]
                container[field] = value
                d.reconcile(self.world)
                container[field] = original
                d.reconcile(self.world)
                self.assertFalse(self.world["data"]["guard_work"]["pairs"][0]["active"])

    def test_repeated_work_reconciles_broken_pair_before_clock_return(self):
        identities = self.make_pair()
        self.apply(dict(kind="fixture_retire", entity_id=identities[0]))
        self.assertEqual([], d.work(self.world, 1, [0, 1]))
        self.assertFalse(self.world["data"]["guard_work"]["pairs"][0]["active"])
        self.assertIn(identities[0], self.world["entities"]["used_ids"])

    def test_vulture_draw_is_once_per_later_round_and_private_identity(self):
        self.make_pair("Vulture")
        count = len(e.zones(self.world)["hands"][0])
        self.assertEqual([], d.draw_pairs(self.world, 1, "test"))
        events = d.draw_pairs(self.world, 2, "test")
        self.assertEqual(count + 1, len(e.zones(self.world)["hands"][0]))
        self.assertEqual(1, len(events))
        self.assertNotIn("card_id", events[0]["event"]["data"])
        self.assertEqual([], d.draw_pairs(self.world, 2, "test"))
        self.assertEqual(count + 1, len(e.zones(self.world)["hands"][0]))

    def test_reconstruction_exception_requires_live_owner_deimos(self):
        for pid in (0, 1):
            engine = e.entity(self.world, opening.castle_id(pid, 4))
            engine["attributes"].update(status="ruined", integrity=0, construction_state="active")
            self.assertEqual(pid == 0, d.eligible(self.world, pid, engine))
        engine = e.entity(self.world, opening.castle_id(0, 4))
        e.entity(self.world, self.world["players"][0]["lord_entity_id"])["attributes"]["alive"] = False
        self.assertFalse(d.eligible(self.world, 0, engine))
        with self.assertRaisesRegex(e.Rejected, "choose_work_target_without_payment"):
            d.validate_choice(self.world, 0, dict(choice(engine["id"]), use_repair_token=True))

    def test_match_stops_at_supported_boundary_and_detaches_inputs(self):
        operations = scripted_operations(0)
        original = deepcopy(operations)
        game = d.DevelopmentMatch(setup(0))
        planning = PlanningMatch(setup(0))
        for op in operations:
            self.assertNotEqual(game.apply(op)["action"], "invalid")
        for op in operations[:-1]:
            self.assertNotEqual(planning.apply(op)["action"], "invalid")
        with self.assertRaises(e.Unsupported):
            planning.apply(operations[-1])
        before = game.snapshot()
        with self.assertRaises(e.Unsupported):
            game.apply(dict(kind="step", hook="post_repair_artillery"))
        self.assertEqual(before, game.snapshot())
        self.assertEqual(original, operations)
        operations[6]["plans"][0]["order"]["guard_moves"].clear()
        self.assertEqual(before, game.snapshot())


if __name__ == "__main__":
    unittest.main()
