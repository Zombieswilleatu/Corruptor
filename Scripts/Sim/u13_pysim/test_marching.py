"""Ownership, phase atomicity, boundaries and deterministic spatial regressions."""

import unittest

from . import marching as m
from . import marching_fixtures as f
from .copying import copy_data
from .economy import Unsupported
from .marching_columns import Columns
from .marching_spatial import speed, swept


class MarchingTests(unittest.TestCase):
    def spec(self, name):
        return next(c for c in f.load()["cases"] if c["name"] == name)

    def test_columns_own_inputs_and_outputs_without_recycling_ids(self):
        world = f.initial(self.spec("keyed_ties"))
        world["entities"]["entities"][0]["attributes"]["sentinel"] = {"nested": [0.1]}
        s = Columns(world["entities"])
        old = s.snapshot()
        world["entities"]["entities"][0]["attributes"]["sentinel"]["nested"][0] = 99
        first = s.row(0)
        first["attributes"]["sentinel"]["nested"][0] = 88
        self.assertEqual(old, s.snapshot())
        used = s.used_ids[:]
        s.retire(0)
        self.assertEqual(used, s.snapshot()["used_ids"])
        self.assertEqual(old["entities"][1]["id"], s.row(1)["id"])

    def test_rejected_reaction_rolls_back_all_prior_tick_work(self):
        spec = self.spec("reaction_rejects_whole_phase")
        ctx = f.context(spec, f.initial(spec), 1)
        before = copy_data(ctx)
        result = m.resolve(ctx, reaction=f.reject_reaction)
        self.assertEqual(dict(action="invalid", reason="marching_reaction_invalid"), result)
        self.assertEqual(before, ctx)

    def test_exception_in_reaction_cannot_mutate_caller(self):
        spec = self.spec("keyed_ties")
        ctx = f.context(spec, f.initial(spec), 1)
        before = copy_data(ctx)
        def fail(world, fact, seed, order):
            world["data"]["unexpected"] = [123]
            fact["data"]["victim"]["attributes"]["hp"] = -999
            raise RuntimeError("injected")
        with self.assertRaisesRegex(RuntimeError, "injected"):
            m.resolve(ctx, reaction=fail)
        self.assertEqual(before, ctx)

    def test_flat_column_kernel_keeps_registry_permutations_equivalent(self):
        spec = self.spec("ordinary_mixed")
        ctx = f.context(spec, f.initial(spec), 1)
        reverse = copy_data(ctx)
        reverse["world"]["entities"]["entities"].reverse()
        reverse["world"]["entities"]["used_ids"].reverse()
        self.assertEqual(m.resolve(ctx), m.resolve(reverse))

    def test_batch_path_keeps_every_semantic_event_and_final_field(self):
        for name in ("reciprocal_volley_and_overkill", "gravity_pull_consumption_and_sweep", "duel_across_phase_boundary"):
            spec = self.spec(name)
            ctx = f.context(spec, f.initial(spec), 1)
            full, batch = m.resolve(ctx), m.resolve(ctx, capture_ticks=False)
            self.assertEqual(f.strip_ticks(full), batch)
            self.assertEqual(200, sum(e["event"]["type"] == "MARCHING_TICK" for e in full["events"]))

    def test_earliest_contact_precedes_keyed_front_tie(self):
        spec = self.spec("earliest_contact_ticket")
        ctx = f.context(spec, f.initial(spec), 1)
        result = m.contact(Columns(ctx["world"]["entities"]), "Lord", ctx, 200, True)
        self.assertEqual(5, result["earliest"])
        self.assertEqual(1, result["bound"])
        self.assertTrue(all(row["attributes"]["contact_tick"] == 5 for row in result["selected"]))

    def test_ranged_reciprocal_lethal_shots_are_not_cancelled(self):
        spec = self.spec("reciprocal_volley_and_overkill")
        result = m.resolve(f.context(spec, f.initial(spec), 1))
        first = [r["event"] for r in result["events"] if r["event"]["data"].get("tick") == 0]
        shots = [r for r in first if r["type"] == "MARCHER_RANGED_ATTACK"]
        self.assertEqual(4, len(shots))
        self.assertEqual(2, sum(r["type"] == "MARCHER_DEFEATED" for r in first))
        self.assertEqual(2, sum(r["data"]["damage_dealt"] == 0 for r in shots))

    def test_persistent_duel_resume_and_whole_phase_exchange_limit(self):
        spec = self.spec("exchange_limit_is_atomic")
        world = f.initial(spec)
        for number in (1, 2):
            world = m.resolve(f.context(spec, world, number))["world"]
        saved = copy_data(world)
        result = m.resolve(f.context(spec, world, 3))
        self.assertEqual(dict(action="invalid", reason="marching_exchange_limit"), result)
        self.assertEqual(saved, world)

    def test_spatial_rounding_and_swept_destruction_boundary(self):
        self.assertEqual(94, sum(speed(3, 25, True, clock, True, True) for clock in range(200, 400)))
        self.assertTrue(swept(0, 65, 100, 65, 50, 0))
        self.assertFalse(swept(0, 66, 100, 66, 50, 0))
        self.assertTrue(swept(900, 300, 1500, 300, 1200, 300))

    def test_complete_games_and_unported_actors_fail_explicitly(self):
        spec = self.spec("ordinary_mixed")
        ctx = f.context(spec, f.initial(spec), 1)
        ctx["world"]["players"] = []
        with self.assertRaises(Unsupported):
            m.resolve(ctx)
        del ctx["world"]["players"]
        ctx["world"]["data"]["kroni_actors"] = [{"id": "unported"}]
        with self.assertRaises(Unsupported):
            m.resolve(ctx)
