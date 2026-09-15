"""Integration risks exposed by repeated rounds and full-world Marching."""

import unittest

from . import economy as e, opening, recruitment, marching, marching_game
from .copying import copy_data
from .development import validate_choice, work
from .full_match import FullMatch
from .full_match_inputs import load, next_operation
from .lifecycle import RoundRules, settle
from . import settlement_inputs


class FullMatchTests(unittest.TestCase):
    def at(self, number, hook):
        spec = load()["cases"][0]
        game = FullMatch(spec["setup"])
        for op in spec["operations"]:
            if game.clock.round == number and game.clock.hook == hook: return game
            self.assertNotEqual("invalid",game.apply(op)["action"])
        self.fail("requested prefix unavailable")

    def test_cleanup_and_next_round_preserve_cards_and_reset_only_sealed_inputs(self):
        game = self.at(1,"aftermath")
        committed = copy_data(e.zones(game.state["world"])["committed"])
        self.assertTrue(any(committed))
        game.apply(dict(kind="step",hook="aftermath"))
        world = game.state["world"]
        self.assertTrue(e.cards_valid(world))
        for pid in (0,1):
            for key in committed[pid]:
                self.assertIn(key,e.zones(world)["discard"])
                self.assertEqual(-1,e.entity(world,key)["owner"])
        before = game.snapshot()
        game.apply(dict(kind="next_round"))
        self.assertEqual(before["world"],game.state["world"])
        self.assertEqual(before["presentation_world"],game.state["presentation_world"])
        self.assertEqual(before["events"],game.state["events"])
        self.assertEqual([None,None],game.state["submissions"])
        self.assertEqual([{},{}],game.state["combat_orders"])
        self.assertEqual(2,game.clock.round)

    def test_stockpile_stops_below_seven_integrity(self):
        world = FullMatch(load()["cases"][0]["setup"]).state["world"]
        stockpile = e.stockpile(world,1)
        for integrity,active in ((7,True),(6,False),(1,False),(8,True)):
            stockpile["attributes"]["integrity"] = integrity
            self.assertEqual(active,bool(e.stockpile(world,1)))

    def test_commission_uses_existing_work_without_passive_construction_gain(self):
        world = FullMatch(load()["cases"][0]["setup"]).state["world"]
        target = e.entity(world,opening.castle_id(0,3))
        target["attributes"].update(integrity=7,status="standing",construction_state="building")
        choice = dict(action="Activate",target_id=target["id"],card_ids=[],use_repair_token=False)
        validate_choice(world,0,choice)
        world["data"]["guard_work"]["targets"][0] = target["id"]
        world["data"]["castle_orders"] = [dict(choice=choice),dict(choice={})]
        world["data"]["guard_orders"] = [dict(moves=[]),dict(moves=[])]
        events = work(world,1,[0,1])
        self.assertEqual((7,"active"),(target["attributes"]["integrity"],target["attributes"]["construction_state"]))
        self.assertEqual(["CASTLE_ACTIVATED","WORK_RESOLVED"],[r["event"]["type"] for r in events])
        self.assertEqual(0,events[1]["event"]["data"]["passive"])

    def test_commission_rechecks_target_and_does_not_revive_ruins(self):
        world = FullMatch(load()["cases"][0]["setup"]).state["world"]
        target = e.entity(world,opening.castle_id(0,3))
        target["attributes"].update(integrity=7,status="standing",construction_state="building")
        choice = dict(action="Activate",target_id=target["id"],card_ids=[],use_repair_token=False)
        validate_choice(world,0,choice)
        world["data"]["guard_work"]["targets"][0] = target["id"]
        world["data"]["castle_orders"] = [dict(choice=choice),dict(choice={})]
        world["data"]["guard_orders"] = [dict(moves=[]),dict(moves=[])]
        target["attributes"].update(integrity=0,status="ruined")
        events = work(world,1,[0,1])
        self.assertEqual("COMMISSION_FIZZLED",events[0]["event"]["type"])
        self.assertEqual("ruined",target["attributes"]["status"])
        self.assertEqual("",world["data"]["guard_work"]["targets"][0])

    def test_settlement_precedence_grace_and_living_lord_gate(self):
        expected = [(0,"Ritual"),(0,"FinalCollapse"),(0,"FinalCollapse"),(0,"Dominion"),
                    (-1,""),(0,"Ritual"),(-1,""),(-1,"")]
        for spec,outcome in zip(settlement_inputs.cases(),expected):
            world = settlement_inputs.initial(load()["cases"][0]["setup"],spec)
            events = settle(world,spec["round"])
            self.assertEqual(outcome,(world["data"]["victory"]["winner"],world["data"]["victory"]["win_by"]),spec["name"])
            self.assertEqual(["VACANT_THRONE_RESOLVED"]*2,[r["event"]["type"] for r in events[:2]])
            if spec["name"].endswith("is_grace"):
                self.assertEqual(0,events[0]["event"]["data"]["soul_gain"])
            if spec["name"].startswith("banishment_round"):
                self.assertEqual(0,world["data"]["vacant_throne"]["counts"][0])

    def test_policy_is_injected_and_cannot_see_or_mutate_hidden_state(self):
        game = self.at(1,"submission_lock")
        before,seen = game.snapshot(),[]
        def policy(view, marker):
            self.assertEqual(17,marker)
            self.assertEqual({"player_id","round","hand","players","board","work_target"},set(view))
            self.assertTrue(all(r["owner"] == view["player_id"] for r in view["hand"]))
            self.assertTrue(all(r["kind"] != "card" or r["attributes"].get("role") == "guard" for r in view["board"]))
            seen.append(view["player_id"])
            view["hand"].clear();view["players"].clear()
            return dict(powers=[],order={})
        op = next_operation(game,policy,dict(marker=17))
        self.assertEqual([0,1],seen)
        self.assertEqual(before,game.snapshot())
        self.assertEqual("game_submitted",game.apply(op)["action"])

    def test_new_full_match_boundary_rejects_unported_choices_atomically(self):
        game = self.at(2,"submission_lock")
        before = game.snapshot()
        plans = [dict(powers=[],order={}),dict(powers=[],order=dict(summon={}))]
        with self.assertRaises(e.Unsupported): game.apply(dict(kind="submit",plans=plans))
        self.assertEqual(before,game.snapshot())
        setup = copy_data(load()["cases"][0]["setup"]);setup["lords"][0] = "Odradek"
        with self.assertRaises(e.Unsupported): FullMatch(setup)

    def test_full_world_marching_preserves_cards_and_rolls_back_reactions(self):
        setup = load()["cases"][0]["setup"]
        world = opening.world(setup["seed"],setup["lords"],setup["castles"])
        for pid in (0,1):
            a = recruitment.profile("Butcher","Lord",pid,0,1)
            a.update(x_fp=1150+100*pid,hp=1)
            recruitment.create(world,"full-world-contact",pid,pid,a)
        context = dict(world=world,round=1,seed=setup["seed"],hook="marching",player_order=[0,1],persistent_effects=[])
        before = copy_data(world)
        def reject(w,fact,seed,order):
            w["data"]["card_zones"]["deck"].clear()
            return dict(action="invalid",reason="injected")
        result = marching_game.resolve(context,reject)
        self.assertEqual("invalid",result["action"])
        self.assertEqual(before,world)
        result = marching_game.resolve(context,RoundRules.march_reaction)
        self.assertEqual("resolved",result["action"])
        self.assertTrue(e.cards_valid(result["world"]))
        self.assertTrue(any(r["event"]["type"] == "MARCHER_DEFEATED" for r in result["events"]))
        self.assertEqual(before,world)

    def test_native_ranged_nearest_includes_initial_squared_range_sentinel(self):
        # The complete Deimos/Kalligan game first exposed 799^2 + 40^2
        # = 640001 at round 3 tick 172. Native nearest() admits this tie;
        # using only distance <= 800^2 changes the shot and later movement.
        for x,y,fires in ((800,0,True),(799,40,True),(800,2,False)):
            setup = load()["cases"][1]["setup"]
            world = opening.world(setup["seed"],setup["lords"],setup["castles"])
            for pid,suit,px,py in ((0,"Vulture",0,0),(1,"Butcher",x,y)):
                a = recruitment.profile(suit,"Castle",pid,0,1);a.update(x_fp=px,y_fp=py)
                recruitment.create(world,"range-sentinel",pid,pid,a)
            ctx = dict(world=world,round=1,seed=setup["seed"],hook="marching",player_order=[0,1],persistent_effects=[])
            phase = marching.Phase(ctx,False,None,keep_background=True)
            phase.volley({},0)
            self.assertEqual(int(fires),len(phase.events),(x,y))


if __name__ == "__main__": unittest.main()
