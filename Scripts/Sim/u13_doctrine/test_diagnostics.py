"""Behavior and instrumentation risks, independent of scoring preferences."""

from copy import deepcopy
import json
import unittest

from u13_pysim import economy, full_match_inputs, opening, settlement_inputs
from u13_pysim.full_match import FullMatch
from u13_pysim.lifecycle import evaluate, settle

from .budget import Budget, Limits
from .coverage import POWERS, ORDINARY_FULL_MATCH_LORDS, report, require_full_roster_tuning
from .diagnostics import Recorder, fingerprint
from .reference_probe import ReferenceObserver


class DiagnosticsTests(unittest.TestCase):
    def test_coordinated_ruin_outside_standalone_shortlist_is_counted(self):
        from pathlib import Path
        from .common import CommonSmartCore
        fixture = json.loads((Path(__file__).parent/'fixtures/gremory_variant_diagnostics.json').read_text())
        # Only the plan actually admitted by the original engine is accepted.
        decision = CommonSmartCore().decide(fixture['view'], lambda plan:
            {'action': 'legal' if plan == fixture['plan'] else 'invalid'})
        self.assertEqual(decision['plan'], fixture['plan'])
        self.assertEqual(decision['rejected_previews'], [])
        recorder = Recorder('variant-regression', ('Gremory', 'Gremory'), ('test', 'test'))
        for assessment in decision['assessments']:
            recorder.assess(fixture['view']['round'], fixture['view']['player_id'], **assessment)
        ruin = next(a for a in decision['assessments'] if a['term'] == 'InevitableRuin')
        self.assertTrue(ruin['selected'])
        self.assertGreater(ruin['retained'], 0)
        self.assertGreaterEqual(ruin['generated'], ruin['retained'])

    def test_assembled_recipe_outside_shortlist_is_counted(self):
        from pathlib import Path
        from .common import CommonSmartCore
        fixture = json.loads((Path(__file__).parent/'fixtures/assembled_recipe_diagnostics.json').read_text())
        decision = CommonSmartCore().decide(fixture['view'], lambda plan:
            {'action': 'legal' if plan == fixture['plan'] else 'invalid'})
        self.assertEqual(decision['plan'], fixture['plan'])
        self.assertEqual(decision['rejected_previews'], [])
        recorder = Recorder('recipe-regression', ('Kalligan', 'Deimos'), ('test', 'test'))
        for assessment in decision['assessments']:
            recorder.assess(fixture['view']['round'], fixture['view']['player_id'], **assessment)
        recipe = next(a for a in decision['assessments'] if a['term'] == 'Lemek')
        self.assertTrue(recipe['selected'])
        self.assertGreater(recipe['retained'], 0)
        self.assertGreaterEqual(recipe['generated'], recipe['retained'])

    def recorder(self, **kwargs):
        return Recorder("case", ("Kroni", "Orias"), ("experimental:v1", "basic:frozen"), **kwargs)

    def selected(self, recorder, number=2, term="Consume"):
        return recorder.assess(number, 0, "powers", term, opportunity=True,
            legal=True, affordable=True, generated=3, retained=2, selected=True,
            reason="best_complete_plan")

    def test_unknown_and_unsupported_never_become_zero_opportunities(self):
        recorder = self.recorder()
        recorder.assess(1, 0, "powers", "Consume", supported=False, reason="unported")
        recorder.assess(1, 0, "combat", "Hunt", selected=False, reason="search_unobserved")
        recorder.assess(2, 0, "combat", "Hunt", opportunity=False, legal=False,
                        generated=0, retained=0, selected=False, reason="no_living_target")
        groups = {g["term"]: g for g in recorder.report()["groups"]}
        self.assertIsNone(groups["Consume"]["flags"])
        self.assertIsNone(groups["Consume"]["effect_records"])
        self.assertEqual(dict(true=0, false=1, unknown=1), groups["Hunt"]["flags"]["opportunity"])
        self.assertEqual(dict(measured_decisions=1, total=0), groups["Hunt"]["candidates"]["generated"])
        with self.assertRaisesRegex(ValueError, "not a measured zero"):
            recorder.assess(2, 0, "powers", "Consume", supported=False, selected=False, reason="unported")

    def test_delayed_effects_keep_original_selection_and_do_not_double_count(self):
        recorder = self.recorder()
        selection = self.selected(recorder)
        # A later decision has the same ability; the delayed event still belongs
        # to the original decision, never whichever power was selected last.
        later = self.selected(recorder, 3)
        self.assertNotEqual(selection, later)
        self.assertTrue(recorder.outcome(selection, "r3:resolved", 3, "resolved"))
        self.assertTrue(recorder.effect(selection, "r3:devoured", 3, {"enemy_guards_removed": 1}))
        self.assertFalse(recorder.effect(selection, "r3:devoured", 3, {"enemy_guards_removed": 1}))
        self.assertFalse(recorder.outcome(selection, "r3:resolved", 3, "resolved"))
        group = recorder.report()["groups"][0]
        self.assertEqual({"enemy_guards_removed": 1}, group["metrics"])
        self.assertEqual({"resolved": 1}, group["outcomes"])
        self.assertEqual(1, group["outcome_unobserved"])
        with self.assertRaisesRegex(ValueError, "conflicting duplicate"):
            recorder.effect(selection, "r3:devoured", 3, {"enemy_guards_removed": 2})
        with self.assertRaisesRegex(ValueError, "terminal outcome"):
            recorder.outcome(selection, "r3:other", 3, "fizzled")

    def test_resolution_is_distinct_from_measured_zero_and_unobserved_effect(self):
        recorder = self.recorder()
        first = self.selected(recorder)
        second = self.selected(recorder, 3)
        recorder.outcome(first, "resolved:1", 3, "resolved")
        recorder.effect(first, "effect:1", 3, {"enemy_guards_removed": 0})
        recorder.outcome(second, "resolved:2", 4, "resolved")
        group = recorder.report()["groups"][0]
        self.assertEqual(2, group["outcomes"]["resolved"])
        self.assertEqual(1, group["effect_records"])
        self.assertEqual(0, group["nonzero_effect_records"])

    def test_budget_drops_and_scoring_passes_have_separate_denominators(self):
        recorder = self.recorder()
        for n, kept, why in ((1, 0, "generation_budget"), (2, 2, "better_alternative")):
            recorder.assess(n, 0, "powers", "Consume", opportunity=True, legal=True,
                affordable=True, generated=3, retained=kept, selected=False, reason=why)
        group = recorder.report()["groups"][0]
        self.assertEqual(2, group["flags"]["opportunity"]["true"])
        self.assertEqual(2, group["flags"]["selected"]["false"])
        self.assertEqual({"generation_budget": 1, "better_alternative": 1}, group["reasons"])

    def test_corrupt_accounting_fails_without_changing_records(self):
        recorder = self.recorder()
        selection = self.selected(recorder)
        before = recorder.report()
        attempts = [
            lambda: self.selected(recorder),
            lambda: recorder.effect("missing", "x", 3, {"kills": 1}),
            lambda: recorder.effect(selection, "x", 1, {"kills": 1}),
            lambda: recorder.effect(selection, "x", 3, {"kills": float("nan")}),
            lambda: recorder.assess(3, 0, "powers", "Consume", retained=4, generated=2, reason="bad"),
            lambda: recorder.assess(3, 0, "powers", "Consume", selected=True, legal=False, reason="bad"),
        ]
        for action in attempts:
            with self.assertRaises(ValueError): action()
            self.assertEqual(before, recorder.report())

    def test_reports_are_detached_and_explanation_samples_are_bounded(self):
        recorder = self.recorder(sample_limit=1)
        selection = self.selected(recorder)
        metrics = {"enemy_removed": 2, "friendly_removed": 1}
        recorder.effect(selection, "effect", 2, metrics)
        metrics["enemy_removed"] = 100
        self.selected(recorder, 3)
        exported = recorder.report()
        self.assertEqual(1, len(exported["samples"]))
        exported["groups"][0]["metrics"]["enemy_removed"] = 99
        exported["samples"][0]["reason"] = "changed"
        self.assertEqual(2, recorder.report()["groups"][0]["metrics"]["enemy_removed"])
        self.assertEqual("best_complete_plan", recorder.report()["samples"][0]["reason"])
        json.dumps(recorder.report(), allow_nan=False)

    def test_seats_and_matchups_are_not_pooled(self):
        recorder = self.recorder()
        recorder.assess(1, 0, "combat", "Ward", selected=False, reason="not_selected")
        recorder.assess(1, 1, "combat", "Ward", selected=False, reason="not_selected")
        groups = recorder.report()["groups"]
        self.assertEqual([(0, "Kroni", "Orias"), (1, "Orias", "Kroni")],
                         [(g["seat"], g["lord"], g["opponent"]) for g in groups])

    def test_reference_observer_never_claims_unseen_alternatives(self):
        spec = full_match_inputs.load()["cases"][0]
        observer = ReferenceObserver(spec)
        observer.accepted_submission(1, [{"powers": [], "order": {}}, {"powers": [], "order": {}}])
        observer.hook_completed("combat_resolution", 1)
        groups = observer.report()["groups"]
        passed = next(g for g in groups if g["seat"] == 0 and g["term"] == "Pass")
        self.assertEqual(1, passed["flags"]["selected"]["true"])
        self.assertEqual(1, passed["flags"]["opportunity"]["unknown"])
        self.assertEqual(0, passed["candidates"]["generated"]["measured_decisions"])
        self.assertEqual({"resolved": 1}, passed["outcomes"])

    def test_generation_stops_before_constructing_extra_proposals(self):
        constructed = []
        budget = Budget(Limits(generated_per_category=4, retained_per_category=2))
        for number in range(1000000):
            if not budget.take("generated", "powers"):
                break
            constructed.append(number)
        self.assertEqual([0, 1, 2, 3], constructed)
        self.assertEqual({"generated:powers": 1}, budget.report()["refused"])
        self.assertTrue(budget.take("generated", "combat"))

    def test_all_work_limits_are_deterministic_and_reset_per_decision(self):
        first, second = Budget(), Budget()
        for kind, category, count in (("generated", "powers", 16), ("retained", "powers", 4),
                                      ("complete_plans", None, 32), ("previews", None, 8)):
            self.assertEqual([True]*count+[False], [first.take(kind, category) for _ in range(count+1)])
            self.assertEqual([True]*count+[False], [second.take(kind, category) for _ in range(count+1)])
        self.assertEqual(first.report(), second.report())
        self.assertTrue(Budget().take("previews"))
        for kwargs in ({"previews": True}, {"complete_plans": 0}, {"generated_per_category": 3}):
            with self.assertRaises(ValueError): Limits(**kwargs)
        with self.assertRaises(ValueError): first.take("generated", "typo")

    def test_coverage_matches_actual_full_match_rejections(self):
        self.assertEqual(set(opening.LORDS), set(POWERS))
        setup = full_match_inputs.load()["cases"][0]["setup"]
        for lord in POWERS:
            fixture = dict(setup, lords=[lord, "Gremory"])
            if lord in ORDINARY_FULL_MATCH_LORDS:
                FullMatch(fixture)
            else:
                with self.assertRaises(economy.Unsupported): FullMatch(fixture)
        self.assertFalse(report()["ready_for_full_roster_tuning"])
        with self.assertRaisesRegex(ValueError, "tuning is blocked"):
            require_full_roster_tuning()

    def test_persistent_work_is_attributed_to_its_earlier_selection(self):
        observer = ReferenceObserver(full_match_inputs.load()["cases"][0])
        work = {"powers": [], "order": {"castle_action": {"action": "Work", "target_id": "castle"}}}
        empty = {"powers": [], "order": {}}
        observer.accepted_submission(1, [work, empty])
        observer.accepted_submission(2, [empty, empty])
        event = dict(type="WORK_RESOLVED", data=dict(round=2, player_id=0, castle_id="castle",
                     before=3, after=6, work=0, passive=3))
        observer.event(7, event, 2)
        group = next(g for g in observer.report()["groups"] if g["seat"] == 0 and g["term"] == "Work")
        self.assertEqual(1, group["flags"]["selected"]["true"])
        self.assertEqual(3, group["metrics"]["applied_work"])

    def test_unrelated_activation_and_orphaned_effects_are_not_credited(self):
        observer = ReferenceObserver(full_match_inputs.load()["cases"][0])
        activate = {"powers": [], "order": {"castle_action": {"action": "Activate", "target_id": "chosen"}}}
        observer.accepted_submission(1, [activate, {"powers": [], "order": {}}])
        observer.event(0, dict(type="CASTLE_ACTIVATED", data=dict(round=1, player_id=0, castle_id="other")), 1)
        group = next(g for g in observer.report()["groups"] if g["seat"] == 0 and g["term"] == "Activate")
        self.assertEqual({}, group["outcomes"])
        self.assertEqual(1, group["outcome_unobserved"])
        with self.assertRaisesRegex(ValueError, "no observed selection"):
            observer.event(1, dict(type="COMBAT_ORDER_FIZZLED", data=dict(round=2, player_id=0)), 2)


class VeilContractTests(unittest.TestCase):
    """Reference situations for the future planner, not a new safety heuristic.

    These complete-information settlement fixtures cannot certify a win/loss
    prediction from a player's incomplete planning observation.
    """

    def world(self, **changes):
        base = dict(round=1, souls=[2, 2], personal_tears=[2, 6], neutral_tears=3,
                    alive=[True, True], present=[True, True], prior_counts=[0, 0])
        base.update(changes)
        return settlement_inputs.initial(full_match_inputs.load()["cases"][0]["setup"], base)

    def finish(self, world, number=1):
        settle(world, number)
        return world["data"]["victory"]["winner"], world["data"]["victory"]["win_by"]

    def test_one_tear_can_be_avoidable_loss_or_own_win(self):
        passing = self.world()
        losing = self.world(personal_tears=[3, 6])
        winning = self.world(personal_tears=[6, 2], neutral_tears=4)
        self.assertEqual((-1, ""), self.finish(passing))
        self.assertEqual((1, "Dominion"), self.finish(losing))
        self.assertEqual((0, "Dominion"), self.finish(winning))

    def test_intermediate_dominion_does_not_override_final_ritual(self):
        world = self.world(personal_tears=[3, 6])
        self.assertEqual(dict(winner=1, win_by="Dominion"), evaluate(world))
        world["players"][0]["resources"]["souls"] = 12
        self.assertEqual((0, "Ritual"), self.finish(world))

    def test_shared_clock_can_advance_without_awarding_enemy_a_win(self):
        world = self.world(personal_tears=[3, 4], neutral_tears=4)
        world["data"]["neutral_tears"] += 1  # e.g. a banishment's clock contribution
        self.assertEqual((-1, ""), self.finish(world))

    def test_pass_can_already_lose_due_to_scheduled_round_pressure(self):
        world = self.world(round=13)
        self.assertEqual(dict(winner=-1, win_by=""), evaluate(world))
        self.assertEqual((1, "Dominion"), self.finish(world, 13))

    def test_collapse_compares_souls_and_ritual_requires_living_lord(self):
        collapse = self.world(souls=[8, 7], personal_tears=[2, 6], neutral_tears=18)
        self.assertEqual((0, "FinalCollapse"), self.finish(collapse))
        absent = self.world(souls=[12, 2], personal_tears=[3, 6], alive=[False, True])
        self.assertEqual((1, "Dominion"), self.finish(absent))


class RuntimeComparisonTests(unittest.TestCase):
    def reports(self):
        semantic = dict(failures=0, all_operations_and_final_digests_matched=True,
                        counts={"selected": 3}, final_state="accepted")
        first = dict(semantic=semantic, semantic_report_sha256=fingerprint(semantic))
        for key in ("source_revision", "engine_source_sha256", "harness_source_sha256",
                    "inputs_sha256", "reference_revision", "reference_evidence_sha256"):
            first[key] = key + ":fixture"
        return first, deepcopy(first)

    def test_runtime_comparison_rejects_changed_counter_even_if_rehashed(self):
        from run_u13_doctrine_diagnostics import compare_reports
        first, second = self.reports()
        compare_reports(first, second)
        second["semantic"]["counts"]["selected"] += 1
        second["semantic_report_sha256"] = fingerprint(second["semantic"])
        with self.assertRaises(ValueError): compare_reports(first, second)

    def test_runtime_comparison_rejects_stale_identity_and_false_success(self):
        from run_u13_doctrine_diagnostics import compare_reports
        first, second = self.reports()
        second["engine_source_sha256"] = "stale"
        with self.assertRaises(ValueError): compare_reports(first, second)
        first, second = self.reports()
        second["semantic"]["all_operations_and_final_digests_matched"] = False
        second["semantic_report_sha256"] = fingerprint(second["semantic"])
        with self.assertRaises(ValueError): compare_reports(first, second)
