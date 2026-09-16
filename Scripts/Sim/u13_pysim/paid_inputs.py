"""Explicit paid-development inputs, not a shipping or tuned doctrine.

Component preparation is labeled and kept outside complete games. The latter
start from ordinary setup and use only decisions; no expected state is loaded.
"""

import hashlib
import json
from pathlib import Path

from . import economy as e, opening, recruitment, paid_development as paid
from .copying import copy_data
from .full_match import FullMatch
from . import full_match_inputs as ordinary
from .development_fixtures import component_apply as development_component
from .lifecycle import RoundRules

PATH = Path(__file__).with_name("paid_inputs.json")
SCHEMA = "U13_PAID_DEVELOPMENT_INPUTS_V1"
POLICY = "U13_REFERENCE_PAID_DEVELOPMENT_V1"


def load():
    return json.loads(PATH.read_text(encoding="utf-8"))


def input_hash():
    return hashlib.sha256(PATH.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def setup(name, lords=("Gremory", "Humbaba")):
    return dict(seed="u13-paid:"+name, lords=list(lords),
                castles=[["Keep", "SummoningCircle", "SummoningCircle", "Stockpile", "Bastion"]]*2)


def component_apply(raw, op):
    w, result = copy_data(raw), {"action": "fixture_prepared"}
    kind, pid, n = op["kind"], op.get("player_id", 0), op.get("round", 1)
    try:
        if kind in ("fixture_give", "fixture_patch", "fixture_retire"):
            return development_component(raw, op)
        if kind == "fixture_data":
            w["data"].update(copy_data(op["data"]))
        elif kind == "fixture_resources":
            w["players"][pid]["resources"].update(op["resources"])
        elif kind == "fixture_waiters":
            for i in range(op["count"]):
                a = recruitment.profile("Butcher", op["lane"], pid, 0, 1)
                a.update(waiting=True, waiting_since_round=1, x_fp=2400 if pid == 0 else 0)
                recruitment.create(w, "paid-waiters:"+str(pid)+":"+op["lane"], i, pid, a)
        elif kind == "quote":
            result = paid.summon_quote(w, pid, op["card_ids"])
        elif kind in ("validate_rites", "validate_summon"):
            result = getattr(paid, kind)(w, pid, op["order"])
        elif kind in ("reserve_rites", "reserve_summon"):
            getattr(paid, kind)(w, pid, op["order"], n)
            result = dict(action="resolved", events=[])
        elif kind in ("resolve_rites", "resolve_summon"):
            events = getattr(paid, kind)(w, n, op.get("player_order", [0, 1]), op.get("hook", "development"))
            result = dict(action="resolved", events=events)
        elif kind == "accept":
            game = FullMatch(setup("component-admission"))
            game.clock.round = n
            events = game._accept_order(w, pid, op["order"])
            result = dict(action="resolved", events=events)
        elif kind == "development":
            rules = RoundRules(w,n,op["seed"],op.get("player_order",[0,1]),"development")
            result = dict(action="resolved", events=rules.run(op["orders"]))
            w = rules.w
        else:
            raise ValueError("Unknown paid component operation: "+kind)
    except e.Rejected as error:
        result = copy_data(error.result)
    return dict(result=result, world=copy_data(raw) if result["action"] == "invalid" else w)


def components():
    cases = []
    def begin(name, lords=("Gremory", "Humbaba")):
        spec = dict(name=name, setup=setup(name, lords), operations=[])
        world = opening.world(**dict(seed=spec["setup"]["seed"], lords=spec["setup"]["lords"], loadouts=spec["setup"]["castles"]))
        cases.append(spec)
        def add(kind, rejected=False, **kw):
            nonlocal world
            op = dict(kind=kind, **kw)
            changed = component_apply(world, op)
            if (changed["result"]["action"] == "invalid") != rejected:
                raise ValueError(f"Bad directed expectation {name}: {op}: {changed['result']}")
            spec["operations"].append(dict(operation=op, rejected=rejected))
            world = changed["world"]
            return world
        return spec, world, add
    def patch(add, key, **attrs):
        return add("fixture_patch", entity_id=key, attributes=attrs)
    def fund(add, w, pid=0):
        # Real physical cards; preparation is outside the game, never synthesis.
        keys = [r["id"] for r in w["entities"]["entities"] if r["kind"] == "card" and r["attributes"]["value"] == 5][:3]
        for key in keys: add("fixture_give", card_id=key, player_id=pid)
        return keys
    for lord in opening.LORDS:
        spec,w,add = begin("return_"+lord, (lord,"Orias" if lord != "Orias" else "Deimos"))
        actor = w["players"][0]["lord_entity_id"]
        add("quote", card_ids=[], rejected=True)
        w = patch(add, actor, alive=False)
        for slot in (1,2):
            w = patch(add, opening.castle_id(0,slot), construction_state="unbuilt", integrity=0)
        add("quote", card_ids=[], rejected=opening.COSTS[lord] > 4 or lord == "Humbaba")
        if opening.COSTS[lord] > 4 or lord == "Humbaba":
            add("reserve_summon",order=dict(summon=dict(card_ids=[])),rejected=True)
        w = add("fixture_data", data=dict(breach_lord=lord))
        w = patch(add, opening.castle_id(0,1), construction_state="active", integrity=7, status="standing")
        add("quote", card_ids=[], rejected=opening.COSTS[lord] > 4 or lord == "Humbaba")
        cards = fund(add,w)
        order = dict(summon=dict(card_ids=cards))
        add("validate_summon",order=dict(order,card_ids=cards[:1],action="Ward",lane="Lord"),rejected=True)
        add("validate_summon",order=dict(order,action="Profane"),rejected=True)
        add("reserve_summon",order=order)
        add("reserve_summon",order=order,rejected=True)
        add("reserve_summon",player_id=1,order={})
        add("resolve_summon",hook="combat_resolution",rejected=True)
        add("resolve_summon",player_order=[1,0])
        add("resolve_summon",rejected=True)
    # Mark penalty is quoted after the offering. Two Circles do not stack the
    # discount; Conduit can choose the other Circle if the first falls below 7.
    for integrity in (7,10):
        spec,w,add = begin("marked_circles_"+str(integrity), ("Gremory","Orias"))
        actor = w["players"][0]["lord_entity_id"]
        patch(add, actor, alive=False)
        patch(add, opening.castle_id(0,1), construction_state="active", integrity=integrity)
        patch(add, opening.castle_id(0,2), construction_state="active", integrity=10)
        add("fixture_data", data=dict(orias_marks=[dict(component_mark=True),None]))
        add("quote",card_ids=[])
        add("reserve_summon",order=dict(summon=dict(card_ids=[])))
        add("reserve_summon",player_id=1,order={})
        add("resolve_summon")
    spec,w,add = begin("rites_payments_timing_and_conflicts")
    cards = fund(add,w)
    order = dict(rites=dict(invocation=dict(card_ids=cards)))
    add("validate_rites",order=order,rejected=True)
    w=add("fixture_data",data=dict(neutral_tears=7,guard_public_round=1))
    add("validate_rites",order=dict(rites=dict(invocation=dict(card_ids=cards[:2]))),rejected=True)
    for part in (dict(card_ids=cards[:1]),dict(summon=dict(card_ids=cards[:1])),
                 dict(guard_moves=[dict(card_id=cards[0],lane="Lord",slot=0)])):
        add("validate_rites",order=dict(order,**part),rejected=True)
    add("accept",order=order)
    add("reserve_rites",player_id=1,order={})
    add("resolve_rites",hook="submission_lock",rejected=True)
    add("resolve_rites",player_order=[1,0])
    add("validate_rites",order=order,rejected=True)
    add("resolve_rites",rejected=True)
    spec,w,add = begin("supplicants_both_lanes_and_ruins")
    spends=[]
    for lane in ("Lord","Castle"):
        w=add("fixture_waiters",count=6,lane=lane,player_id=0)
        keys=[r["id"] for r in w["entities"]["entities"] if r["kind"]=="marcher" and r["attributes"]["lane"]==lane][:5]
        spends.append(dict(lane=lane,marcher_ids=keys))
    for slot in (1,2): patch(add,opening.castle_id(0,slot),integrity=0,status="ruined",construction_state="active")
    order=dict(rites=dict(waiter_spends=spends,profane_ruins=dict(castle_id=opening.castle_id(0,1))))
    add("validate_rites",order=order,rejected=True)
    add("fixture_resources",resources=dict(souls=2))
    add("validate_rites",order=dict(order,castle_action=dict(target_id=opening.castle_id(0,1))),rejected=True)
    add("validate_rites",order=dict(rites=dict(waiter_spends=[spends[0],spends[0]])),rejected=True)
    add("validate_rites",order=dict(rites=dict(waiter_spends=[dict(spends[0],lane="Castle")])),rejected=True)
    add("reserve_rites",order=order)
    add("reserve_rites",player_id=1,order={})
    add("resolve_rites")
    # Missing later targets must undo earlier retirements in the same call.
    for broken in ("waiter", "ruin", "circle", "lord"):
        spec,w,add=begin("resolution_rollback_"+broken)
        if broken in ("waiter","ruin"):
            w=add("fixture_waiters",count=5,lane="Lord",player_id=0)
            keys=[r["id"] for r in w["entities"]["entities"] if r["kind"]=="marcher"]
            order=dict(rites=dict(waiter_spends=[dict(lane="Lord",marcher_ids=keys)]))
            if broken=="ruin":
                for slot in (1,2): patch(add,opening.castle_id(0,slot),integrity=0,status="ruined",construction_state="active")
                add("fixture_resources",resources=dict(souls=2))
                order["rites"]["profane_ruins"]=dict(castle_id=opening.castle_id(0,1))
            add("reserve_rites",order=order);add("reserve_rites",player_id=1,order={})
            if broken=="waiter": add("fixture_retire",entity_id=keys[-1])
            else: patch(add,opening.castle_id(0,1),status="profaned")
            add("resolve_rites",rejected=True)
        else:
            actor=w["players"][0]["lord_entity_id"]
            patch(add,actor,alive=False)
            patch(add,opening.castle_id(0,1),construction_state="active",integrity=7)
            add("reserve_summon",order=dict(summon=dict(card_ids=[])))
            add("reserve_summon",player_id=1,order={})
            if broken=="circle": patch(add,opening.castle_id(0,1),integrity=2)
            else: patch(add,actor,alive=True)
            add("resolve_summon",rejected=True)
    spec,w,add=begin("combined_payments_guards_work")
    cards=fund(add,w)
    patch(add,w["players"][0]["lord_entity_id"],alive=False)
    w=add("fixture_data",data=dict(neutral_tears=7,guard_public_round=1))
    rest=[key for key in e.zones(w)["hands"][0] if key not in cards]
    for row in [r for r in w["entities"]["entities"] if r["kind"]=="card" and r["owner"]==-1][:max(0,3-len(rest))]:
        add("fixture_give",card_id=row["id"],player_id=0)
        rest.append(row["id"])
    order=dict(rites=dict(invocation=dict(card_ids=cards)),summon=dict(card_ids=rest[:1]),
               guard_moves=[dict(card_id=rest[1],lane="Lord",slot=0)],
               castle_action=dict(action="Work",target_id=opening.castle_id(0,3),card_ids=[],use_repair_token=False),
               action="Ward",lane="Castle",card_ids=rest[2:3])
    add("accept",order=dict(order,guard_moves=[dict(card_id=cards[0],lane="Lord",slot=0)]),rejected=True)
    # Rite and summon payments have both happened when the bad Guard is found;
    # rejection must roll them back together, including owner/pile changes.
    add("accept",order=dict(order,guard_moves=[dict(card_id="missing",lane="Lord",slot=0)]),rejected=True)
    add("accept",order=order)
    add("accept",player_id=1,order={})
    add("development",seed=spec["setup"]["seed"],orders=[order,{}])
    return cases


def paid_plan(view):
    pid, board = view["player_id"],view["board"]
    hand = view["hand"][:]
    extra, rites = {}, {}
    own=[r for r in board if r["kind"]=="castle" and r["owner"]==pid]
    actor=next(r for r in board if r["kind"]=="lord" and r["owner"]==pid)
    if not actor["attributes"]["alive"]:
        cost=opening.COSTS[actor["attributes"]["lord_id"]]+3*int(view["breach_lord"]==actor["attributes"]["lord_id"])
        if any(r["attributes"]["castle_type"]=="SummoningCircle" and e.operational(r) for r in own): cost=max(0,cost-3)
        # Sufficient payment, then leave the remaining hand to the ordinary driver.
        cards, total=[],0
        while hand and total<cost:
            row=hand.pop(0);cards.append(row["id"]);total+=row["attributes"]["value"]
        if total>=cost or (actor["attributes"]["lord_id"]!="Humbaba" and cost-total<=4):
            extra["summon"]=dict(card_ids=cards)
        else: hand=view["hand"][:]
    # A fixed directed-input schedule, not a strategic recommendation. Preserve
    # the original attack sequence long enough to exercise banishment/return;
    # earlier Rite spending otherwise ends these small games before any return.
    rites_enabled = view["round"] >= 12
    if rites_enabled and view["veil_total"]>=7 and view["invocation_rounds"][pid]==0 and sum(r["attributes"]["value"] for r in hand)>=11:
        cards,total=[],0
        while total<11:
            row=hand.pop(0);cards.append(row["id"]);total+=row["attributes"]["value"]
        rites["invocation"]=dict(card_ids=cards)
    for lane in ("Lord","Castle"):
        keys=sorted(r["id"] for r in board if r["kind"]=="marcher" and r["owner"]==pid
                    and r["attributes"]["waiting"] and r["attributes"]["hp"]>0 and r["attributes"]["lane"]==lane)
        for i in range(0,len(keys)-4,5) if rites_enabled else ():
            rites.setdefault("waiter_spends",[]).append(dict(lane=lane,marcher_ids=keys[i:i+5]))
    ruins=sorted(r["id"] for r in own if r["attributes"]["status"]=="ruined")
    if rites_enabled and len(ruins)>=2 and view["players"][pid]["resources"]["souls"]>=2:
        rites["profane_ruins"]=dict(castle_id=ruins[0])
    plan=ordinary.reference_plan(dict(view,hand=hand))
    plan["order"].update(extra)
    if rites: plan["order"]["rites"]=rites
    return plan


def next_operation(game):
    if game.clock.hook=="submission_lock" and game._state["submissions"]==[None,None]:
        plans=[]
        for pid in (0,1):
            view=ordinary.observation(game,pid)
            d=game._state["world"]["data"]
            view.update(veil_total=paid.veil(game._state["world"]),breach_lord=d["breach_lord"],
                        invocation_rounds=d["dominion_rites"]["invocation_rounds"][:])
            plans.append(paid_plan(view))
        return dict(kind="submit",plans=plans)
    return ordinary.next_operation(game)


def generate():
    base=ordinary.load()
    result=dict(schema=SCHEMA, policy=POLICY, round_cap=40, cases=copy_data(base["cases"]),
                settlements=base["settlements"], components=components())
    for case in base["cases"]:
        game,ops=FullMatch(case["setup"]),[]
        while game.outcome()["winner"]==-1:
            if game.clock.round>40: raise ValueError("paid game censored")
            op=next_operation(game)
            applied=game.apply(op)
            if applied["action"]=="invalid": raise ValueError((case["name"],game.clock.round,op,applied))
            ops.append(op)
        result["cases"].append(dict(name="paid_"+case["name"],setup=case["setup"],operations=ops,marching_probes=[]))
    return result
