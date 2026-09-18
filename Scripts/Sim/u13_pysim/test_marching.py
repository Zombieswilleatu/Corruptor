"""Ownership, phase atomicity, boundaries and deterministic spatial regressions."""

import unittest
import random
from unittest.mock import patch

from . import marching as m
from . import marching_fixtures as f
from .copying import copy_data
from .economy import Rejected, Unsupported
from .marching_columns import Columns
from .marching_spatial import gravity, speed, swept


class MarchingTests(unittest.TestCase):
    def spec(self, name):
        return next(c for c in f.load()["cases"] if c["name"] == name)

    def test_gravity_tracks_ids_after_death_callback_compacts_columns(self):
        s = Columns(f.initial(self.spec('keyed_ties'))['entities'])
        for i in s.active(): s.x_fp[i], s.y_fp[i], s.movement_ready_round[i] = 1200, 300, 1
        before = [(s.ids[i], s.x_fp[i], s.y_fp[i], s.lane[i], s.movement_ready_round[i]) for i in s.active()]
        victim = s.ids[0]; survivors = s.ids[1:]
        s.retire(0)
        s = Columns(s.snapshot())  # A real reaction rebuild removes the dead slot.
        events = []
        orbs = [dict(id=lane, owner=0, target=dict(lane=lane, field_position=dict(x_fp=1200, y_fp=300)),
                     consumed=0, rewarded=False) for lane in ('Lord', 'Castle')]
        gravity(s, orbs, before, 1, 0, False, lambda kind, data: events.append(data))
        self.assertEqual(survivors, [r['unit']['id'] for r in events])
        self.assertNotIn(victim, [r['unit']['id'] for r in events])
        self.assertEqual([], s.active())

    def test_gravity_uses_pre_tick_readiness_after_monster_wakes_recruit(self):
        s = Columns(f.initial(self.spec('keyed_ties'))['entities'])
        i = 0; s.x_fp[i], s.y_fp[i] = 1000, 300
        before = [(s.ids[i], 1000, 300, s.lane[i], 2)]
        s.movement_ready_round[i] = 1
        orb = dict(id='orb', owner=0, target=dict(lane=s.lane[i], field_position=dict(x_fp=1200, y_fp=300)), consumed=0, rewarded=False)
        gravity(s, [orb], before, 1, 0, False, lambda *args: self.fail('unexpected consumption'))
        self.assertEqual(1000, s.x_fp[i])
        gravity(s, [orb], [(s.ids[i], 1000, 300, s.lane[i], 1)], 1, 1, False, lambda *args: self.fail('unexpected consumption'))
        self.assertEqual(1007, s.x_fp[i])

    def test_attacked_recruit_closes_distance_while_untouched_recruit_holds(self):
        for pid in (0, 1):
            spec = self.spec("ordinary_mixed")
            start = 100 if pid == 0 else 2300
            spec['ranged'] = True
            spec['units'] = [
                dict(origin='defender', ordinal=0, owner=pid, suit='Penitent', lane='Castle', birth=1, ready=2, attributes=dict(x_fp=start)),
                dict(origin='untouched', ordinal=0, owner=pid, suit='Penitent', lane='Castle', birth=1, ready=2, attributes=dict(x_fp=0 if pid == 0 else 2400, y_fp=0)),
                dict(origin='attacker', ordinal=0, owner=1-pid, suit='Vulture', lane='Castle', attributes=dict(x_fp=start+(300 if pid == 0 else -300), hp=1, armor=0)),
            ]
            context = f.context(spec, f.initial(spec), 1)
            result = m.resolve(context)
            self.assertEqual('resolved', result['action'])
            rows = {r['origin']: r['attributes'] for r in result['world']['entities']['entities']}
            self.assertNotEqual(start, rows['defender']['x_fp'])
            self.assertEqual(1, rows['defender']['movement_ready_round'])
            self.assertEqual(2, rows['untouched']['movement_ready_round'])
            self.assertEqual(0 if pid == 0 else 2400, rows['untouched']['x_fp'])
            shots = [r['event'] for r in result['events'] if r['event']['type'] == 'MARCHER_RANGED_ATTACK']
            self.assertEqual(0, shots[0]['data']['damage_dealt'])
            self.assertTrue(any(r['event']['type'] == 'MARCHER_CLASH' for r in result['events']))
            self.assertEqual(result, m.resolve(context))

    def test_nearest_pruning_keeps_two_dimensional_and_equal_distance_ties(self):
        # The first examined x coordinate need not contain the nearest point.
        # A later point exactly on the pruning boundary can win the ID tie.
        for xs, ys, expected in (([1000, 1400, 999], [0, 0, 600], (160000, 1)),
                                 ([1000, 1400, 600], [0, 0, 0], (160000, 1)),
                                 ([1000, 1000, 1000], [0, 0, 0], (0, 1)),
                                 ([1000], [0], ((1 << 63)-1, None))):
            candidates = sorted(range(1, len(xs)), key=xs.__getitem__)
            self.assertEqual(expected, m.nearest_target(0, candidates, [xs[j] for j in candidates], xs, ys))

    def test_nearest_pruning_matches_exhaustive_search_with_retired_slots(self):
        rng = random.Random(41729)
        for sample in range(120):
            xs = [rng.randrange(2401) for _ in range(67)]
            ys = [rng.randrange(601) for _ in xs]
            if sample % 3 == 0:
                xs = [1200] * len(xs)  # Vertical fronts cannot be pruned by x.
            if sample % 5 == 0:
                ys = [300] * len(xs)
            # Sparse immutable slots model retired Marchers without recycling IDs.
            live = [i for i in range(1, len(xs)) if rng.randrange(3)]
            rng.shuffle(live)
            candidates = sorted(live, key=xs.__getitem__)
            for i in range(0, len(xs), 11):
                eligible = [j for j in candidates if j != i]
                expected = min((((xs[i]-xs[j])**2+(ys[i]-ys[j])**2, j) for j in eligible),
                               default=((1 << 63)-1, None))
                self.assertEqual(expected, m.nearest_target(i, eligible, [xs[j] for j in eligible], xs, ys))

    def ranged_phase(self, reaction):
        spec = self.spec("ordinary_mixed")
        spec["units"] = [dict(origin="volley-boundary", ordinal=pid, owner=pid,
            suit=suit, lane="Lord", attributes=dict(x_fp=400*pid, y_fp=300,
            hp=3, max_hp=3, armor=0, attack=1, step_fp=0))
            for pid, suit in ((0, "Vulture"), (1, "Wright"))]
        spec["ranged"] = True
        ctx = f.context(spec, f.initial(spec), 1)
        return m.Phase(ctx, False, reaction), ctx

    def test_vulture_range_is_400_for_both_sides(self):
        for pid in (0, 1):
            for gap in (400, 401):
                spec = self.spec("ordinary_mixed")
                spec['ranged'] = True
                spec['units'] = [
                    dict(origin='bird', ordinal=0, owner=pid, suit='Vulture', lane='Lord', attributes=dict(x_fp=1200,step_fp=0)),
                    dict(origin='target', ordinal=0, owner=1-pid, suit='Penitent', lane='Lord', attributes=dict(x_fp=1200+gap*(1 if pid==0 else -1),step_fp=0,hp=100,max_hp=100)),
                ]
                phase = m.Phase(f.context(spec, f.initial(spec), 1), False, None)
                phase.volley({}, 0)
                shots = [r for r in phase.events if r['event']['type']=='MARCHER_RANGED_ATTACK']
                self.assertEqual(bool(shots), gap == 400)

    def test_nonlethal_volley_keeps_columns_until_callback_sees_accumulated_state(self):
        callbacks = []
        def react(world, fact, seed, order):
            callbacks.append(copy_data(world))
            # A real callback still gets validated and imported, including edits.
            world["entities"]["entities"][0]["attributes"]["armor"] = 7
            return dict(action="resolved", world=world, events=[])
        phase, ctx = self.ranged_phase(react)
        before = copy_data(ctx)
        initial = phase.s.snapshot()
        victim = next(i for i in phase.s.active() if phase.s.owner[i] == 1)
        attacker_id = next(phase.s.ids[i] for i in phase.s.active() if phase.s.owner[i] == 0)
        # The first two shots cannot require registry validation: no callback ran.
        with patch.object(m, "Columns", side_effect=AssertionError("nonlethal registry rebuild")):
            phase.volley({}, 0)
            self.assertEqual(2, phase.s.hp[victim])
            phase.volley({}, 32)
            self.assertEqual(1, phase.s.hp[victim])
        self.assertEqual([], callbacks)
        retained_events = copy_data(phase.events)
        phase.volley({}, 64)
        self.assertEqual(1, len(callbacks))
        self.assertEqual([attacker_id], [r["id"] for r in callbacks[0]["entities"]["entities"]])
        self.assertEqual(296, callbacks[0]["entities"]["entities"][0]["attributes"]["ranged_next_tick"])
        self.assertEqual(7, phase.s.armor[phase.s.live(attacker_id)])
        self.assertEqual(retained_events, phase.events[:len(retained_events)])
        self.assertEqual(before, ctx)
        self.assertEqual([3, 3], [r["attributes"]["hp"] for r in initial["entities"]])

    def test_lethal_volley_still_rejects_invalid_callback_registry(self):
        def corrupt(world, fact, seed, order):
            world["entities"]["entities"][0]["id"] = "invalid-id"
            return dict(action="resolved", world=world, events=[])
        phase, ctx = self.ranged_phase(corrupt)
        phase.s.hp[next(i for i in phase.s.active() if phase.s.owner[i] == 1)] = 1
        before = copy_data(ctx)
        with self.assertRaisesRegex(Rejected, "ranged_entities_invalid"):
            phase.volley({}, 0)
        self.assertEqual(before, ctx)

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
