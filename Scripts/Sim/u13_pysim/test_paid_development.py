"""Payment, timing and rollback boundaries beyond the ordinary-game corpus."""

import unittest
from unittest.mock import patch

from . import economy as e, opening, paid_development as paid, paid_inputs
from .copying import copy_data
from .full_match import FullMatch
from .full_match_inputs import next_operation
from .planning import PlanningMatch
from .lifecycle import RoundRules


class PaidDevelopmentTests(unittest.TestCase):
    def test_unaffordable_return_preserves_native_quote_and_both_submission_slots(self):
        game=FullMatch(paid_inputs.setup("shortfall",("Gremory","Humbaba")))
        while game.clock.hook!="submission_lock":
            self.assertNotEqual("invalid",game.apply(next_operation(game))["action"])
        w=game._state["world"]
        e.entity(w,w["players"][1]["lord_entity_id"])["attributes"]["alive"]=False
        quote=paid.summon_quote(w,1,[])
        before=game.snapshot()
        result=game.apply(dict(kind="submit",plans=[dict(powers=[],order={}),dict(powers=[],order=dict(summon=dict(card_ids=[])))]))
        self.assertEqual("invalid",quote["action"])
        self.assertEqual(quote,result)
        self.assertEqual(before,game.snapshot())
        result["return_threat"]=99
        self.assertEqual(before,game.snapshot())

    def prepared(self):
        game=FullMatch(paid_inputs.setup("unit-payments"))
        while game.clock.hook!="submission_lock":
            self.assertNotEqual("invalid",game.apply(next_operation(game))["action"])
        w=game._state["world"]
        e.entity(w,w["players"][0]["lord_entity_id"])["attributes"]["alive"]=False
        w["data"]["neutral_tears"]=7
        hand=sorted(e.zones(w)["hands"][0],key=lambda k:-e.entity(w,k)["attributes"]["value"])
        cards,total=[],0
        while hand and total<11:
            key=hand.pop(0);cards.append(key);total+=e.entity(w,key)["attributes"]["value"]
        self.assertGreaterEqual(total,11)
        return game,dict(rites=dict(invocation=dict(card_ids=cards)),summon=dict(card_ids=[]))

    def test_preview_does_not_pay_expose_or_mutate_presentation(self):
        game,order=self.prepared();before=game.snapshot()
        for _ in range(2): game._accept_order(game._state["world"],0,order,reserve=False)
        self.assertEqual(before,game.snapshot())
        self.assertFalse(game._state_exposed)
        result=game.apply(dict(kind="submit",plans=[dict(powers=[],order=order),dict(powers=[],order={})]))
        self.assertEqual("game_submitted",result["action"])
        self.assertEqual(before["world"],game.snapshot()["world"])
        self.assertEqual([],game.snapshot()["submissions"][0])

    def test_joint_lock_restores_first_payment_when_second_player_fails(self):
        game,order=self.prepared()
        plans=[dict(powers=[],order=order),dict(powers=[],order={})]
        self.assertEqual("game_submitted",game.apply(dict(kind="submit",plans=plans))["action"])
        # Failure after accepted previews, during the second authoritative lock.
        game._state["combat_orders"][1]=dict(guard_moves=[dict(card_id="missing",lane="Lord",slot=0)])
        before=game.snapshot()
        self.assertEqual("handler_rejected_hook",game.apply(dict(kind="step",hook="submission_lock"))["reason"])
        self.assertEqual(before,game.snapshot())
        game._state["combat_orders"][1]={}
        self.assertNotEqual("invalid",game.apply(dict(kind="step",hook="submission_lock"))["action"])
        w=game._state["world"]
        self.assertTrue(all(k in e.zones(w)["discard"] for k in order["rites"]["invocation"]["card_ids"]))
        self.assertFalse(e.entity(w,w["players"][0]["lord_entity_id"])["attributes"]["alive"])
        self.assertEqual(0,w["data"]["dominion_rites"]["invocation_rounds"][0])

    def test_late_development_failure_rolls_back_tears_return_clocks_and_events(self):
        game,order=self.prepared()
        game.apply(dict(kind="submit",plans=[dict(powers=[],order=order),dict(powers=[],order={})]))
        game.apply(dict(kind="step",hook="submission_lock"))
        before=game.snapshot(); original=RoundRules.run; seen=[]
        def fail(rules,orders):
            events=original(rules,orders)
            seen.extend(row["event"]["type"] for row in events)
            raise e.Rejected("after_return_and_rites")
        with patch.object(RoundRules,"run",fail):
            self.assertEqual("handler_rejected_hook",game.apply(dict(kind="step",hook="development"))["reason"])
        self.assertIn("LORD_RESUMMONED",seen);self.assertIn("PERSONAL_TEAR_CREATED",seen)
        self.assertEqual(before,game.snapshot())
        self.assertNotEqual("invalid",game.apply(dict(kind="step",hook="development"))["action"])
        w=game._state["world"]
        self.assertEqual(1,w["data"]["dominion_rites"]["invocation_rounds"][0])
        self.assertEqual(8,w["data"]["neutral_tears"])
        self.assertEqual(2,w["data"]["summon_counts"][0])
        self.assertTrue(w["data"]["vacant_throne"]["present"][0])
        self.assertEqual(-1,game.outcome()["winner"])
        self.assertEqual(before["presentation_world"],game.snapshot()["presentation_world"])

    def test_malformed_rites_and_overlapping_costs_reject_without_mutation(self):
        game,order=self.prepared();before=game.snapshot()
        candidates=[dict(rites=x) for x in (False,[],dict(unknown=True),dict(invocation=dict(card_ids=[True])),
                                          dict(waiter_spends=[dict(lane="Lord",marcher_ids=["x"]*5)]))]
        candidates.append(dict(order,summon=dict(card_ids=order["rites"]["invocation"]["card_ids"][:1])))
        for bad in candidates:
            with self.subTest(order=bad):
                result=game.apply(dict(kind="submit",plans=[dict(powers=[],order={}),dict(powers=[],order=bad)]))
                self.assertEqual("invalid",result["action"])
                self.assertEqual(before,game.snapshot())

    def test_humbaba_cannot_buy_shortfall_and_never_acquires_threat(self):
        w=opening.world(**dict(seed="humbaba-return",lords=["Humbaba","Gremory"],loadouts=[opening.CASTLES]*2))
        actor=e.entity(w,w["players"][0]["lord_entity_id"]);actor["attributes"]["alive"]=False
        self.assertEqual("invalid",paid.summon_quote(w,0,[])["action"])
        cards=e.zones(w)["hands"][0][:]
        self.assertEqual("legal",paid.summon_quote(w,0,cards)["action"])
        paid.reserve_summon(w,0,dict(summon=dict(card_ids=cards)),1);paid.reserve_summon(w,1,{},1)
        paid.resolve_summon(w,1,[0,1])
        self.assertNotIn("threat",actor["attributes"])

    def test_circle_discount_and_blood_conduit_use_post_offering_board(self):
        w=opening.world(**dict(seed="circle-return",lords=["Gremory","Orias"],loadouts=[opening.CASTLES]*2))
        actor=e.entity(w,w["players"][0]["lord_entity_id"]);actor["attributes"]["alive"]=False
        circle=e.entity(w,opening.castle_id(0,2));circle["attributes"].update(construction_state="active",integrity=7)
        w["data"]["orias_marks"][0]={"component_mark":True}
        before=copy_data(w)
        q=paid.summon_quote(w,0,[])
        self.assertEqual((3,3,4),(q["cost"],q["shortfall"],q["return_threat"]))
        self.assertEqual(before,w)
        paid.reserve_summon(w,0,dict(summon=dict(card_ids=[])),1);paid.reserve_summon(w,1,{},1)
        events=paid.resolve_summon(w,1,[0,1])
        self.assertEqual(4,circle["attributes"]["integrity"])
        self.assertEqual(2,circle["attributes"]["repair_lock_until_round"])
        self.assertEqual(4,actor["attributes"]["threat"])
        self.assertNotIn("BLOOD_CONDUIT",[r["event"]["type"] for r in events])

    def test_rite_reservations_leave_bodies_until_development_and_keep_used_ids(self):
        cfg=paid_inputs.setup("waiters")
        w=opening.world(cfg["seed"],cfg["lords"],cfg["castles"])
        w=paid_inputs.component_apply(w,dict(kind="fixture_waiters",player_id=0,count=6,lane="Lord"))["world"]
        keys=[r["id"] for r in w["entities"]["entities"] if r["kind"]=="marcher"]
        order=dict(rites=dict(waiter_spends=[dict(lane="Lord",marcher_ids=keys[:5])]))
        paid.reserve_rites(w,0,order,1);paid.reserve_rites(w,1,{},1)
        self.assertTrue(all(e.entity(w,k) for k in keys))
        used=w["entities"]["used_ids"][:]
        paid.resolve_rites(w,1,[0,1])
        self.assertTrue(e.entity(w,keys[-1]));self.assertFalse(any(e.entity(w,k) for k in keys[:5]))
        self.assertEqual(used,w["entities"]["used_ids"])
        self.assertEqual(1,w["players"][0]["resources"]["personal_tears"])

    def test_earlier_adapter_and_full_roster_boundaries_stay_explicit(self):
        game=PlanningMatch(paid_inputs.setup("early-boundary"))
        with self.assertRaises(e.Unsupported): game._accept_order(game._state["world"],0,dict(summon=dict(card_ids=[])))
        with self.assertRaises(e.Unsupported): FullMatch(paid_inputs.setup("missing-lord",("Valak","Humbaba")))

    def test_directed_corpus_expectations_and_detached_component_results(self):
        specs=paid_inputs.components()
        self.assertEqual(specs,paid_inputs.load()["components"])
        for spec in specs:
            cfg=spec["setup"];w=opening.world(cfg["seed"],cfg["lords"],cfg["castles"])
            for entry in spec["operations"]:
                before=copy_data(w);result=paid_inputs.component_apply(w,entry["operation"])
                self.assertEqual(before,w)
                self.assertEqual(entry["rejected"],result["result"]["action"]=="invalid")
                w=result["world"]
