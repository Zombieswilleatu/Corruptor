"""Input-only complete games. The replaceable reference policy is not doctrine.

Generation uses Python to select decisions; Godot independently accepts every
decision and produces the reference. No rule state is imported between hooks.
"""

import hashlib
import json
from pathlib import Path

from . import economy as e
from .copying import copy_data
from .development import commission_eligible
from .full_match import FullMatch
from . import settlement_inputs

PATH = Path(__file__).with_name("full_match_inputs.json")
SCHEMA = "U13_FULL_MATCH_INPUTS_V1"
POLICY = "U13_REFERENCE_PAIR_WORK_V1"


def load():
    return json.loads(PATH.read_text(encoding="utf-8"))


def input_hash():
    return hashlib.sha256(PATH.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def observation(match, pid):
    """Only own hand and public board; no deck, enemy hand or sealed orders."""
    # Trusted adapter reads private storage; the policy receives only the
    # detached projection below, never a live-state escape.
    w = match._state["world"]
    hand = e.zones(w)["hands"][pid]
    return copy_data(dict(player_id=pid, round=match.clock.round,
        hand=[e.entity(w,key) for key in hand], players=w["players"],
        board=[row for row in w["entities"]["entities"] if row["kind"] != "card" or row["attributes"].get("role") == "guard"],
        work_target=w["data"]["guard_work"]["targets"][pid]))


def reference_plan(view, guard_cards=2, ward_period=4):
    """Deliberately simple coverage policy; arguments can be replaced/tuned.

    This is an input producer, not a scoring term embedded in the simulator.
    It has no shipping Godot doctrine counterpart or strength claim.
    """
    pid, n = view["player_id"], view["round"]
    hand, board = view["hand"][:], view["board"]
    own = [r for r in board if r["kind"] == "castle" and r["owner"] == pid]
    own.sort(key=lambda r:r["attributes"]["castle_slot"])
    order, choice, moves = {}, {}, []
    target = next((r for r in own if r["id"] == view["work_target"] and commission_eligible(r,pid)), None)
    if target:
        choice = dict(action="Activate", target_id=target["id"], card_ids=[], use_repair_token=False)
    else:
        # This policy chooses ordinary standing construction/repair only.
        candidates = [r for r in own if r["attributes"]["status"] not in ("ruined","profaned")
                      and (r["attributes"]["construction_state"] != "active"
                           or r["attributes"]["integrity"] < r["attributes"]["max_integrity"])]
        if candidates:
            target = min(candidates,key=lambda r:(r["attributes"]["construction_state"] == "active",r["attributes"]["castle_slot"]))
            choice = dict(action="Work", target_id=target["id"], card_ids=[], use_repair_token=False)
    for lane in (("Lord","Castle") if n % 2 else ("Castle","Lord")):
        occupied = {r["attributes"]["slot"] for r in board if r["kind"] == "card" and r["owner"] == pid
                    and r["attributes"].get("role") == "guard" and r["attributes"]["lane"] == lane}
        free = [slot for slot in range(3) if slot not in occupied]
        if len(free) >= 2 and len(hand) >= guard_cards+2 and guard_cards >= 2:
            pair = next(([a,b] for i,a in enumerate(hand) for b in hand[i+1:]
                         if a["attributes"]["suit"] == b["attributes"]["suit"]), [])
            if pair:
                for slot,row in zip(free,pair):
                    moves.append(dict(card_id=row["id"],lane=lane,slot=slot)); hand.remove(row)
                break
    if choice: order["castle_action"] = choice
    if moves: order["guard_moves"] = moves
    if hand:
        enemy_lord = next(r for r in board if r["kind"] == "lord" and r["owner"] == 1-pid)
        enemy_castles = [r for r in board if r["kind"] == "castle" and r["owner"] == 1-pid
                         and r["attributes"]["construction_state"] == "active"
                         and r["attributes"]["status"] in ("standing","defunct")]
        profane = next((r for r in own if r["attributes"]["castle_type"] != "Keep" and e.operational(r)
                        and r["attributes"]["integrity"] == r["attributes"]["max_integrity"]), None)
        own_lord = next(r for r in board if r["kind"] == "lord" and r["owner"] == pid)
        if n >= 10 and (n+pid) % 7 == 0 and profane and own_lord["attributes"]["alive"]:
            order.update(action="Profane",lane="Castle",target_id=profane["id"],card_ids=[])
        elif n <= 2 or (n+pid) % ward_period == 0:
            order.update(action="Ward",lane="Lord" if n % 2 else "Castle",card_ids=[r["id"] for r in hand])
        elif enemy_lord["attributes"]["alive"] and (n+pid) % 2:
            order.update(action="Hunt",lane="Lord",target_id=enemy_lord["id"],card_ids=[r["id"] for r in hand])
        else:
            target_id = min(enemy_castles,key=lambda r:r["attributes"]["castle_slot"])["id"] if enemy_castles else "castle_zone:"+str(1-pid)
            order.update(action="Siege",lane="Castle",target_id=target_id,card_ids=[r["id"] for r in hand])
    return dict(powers=[],order=order)


def next_operation(match, policy=reference_plan, weights=None):
    """Public choice driver; injected policy only receives per-player views."""
    if match.clock.completed:
        return dict(kind="next_round")
    w, hook = match._state["world"],match.clock.hook
    if hook == "present_public_state":
        pending = w["data"]["game_economy"]["stockpile_pending"]
        if pending:
            keep = max(pending["card_ids"],key=lambda key:e.entity(w,key)["attributes"]["value"])
            return dict(kind="stockpile",player_id=pending["player_id"],keep_id=keep)
        pid = w["data"]["game_market"]["seat"]
        if pid != 2:
            z = e.zones(w)
            choice = dict(market="Pass")
            if z["market"] and z["hands"][pid]:
                take = max(z["market"],key=lambda key:e.entity(w,key)["attributes"]["value"])
                give = min(z["hands"][pid],key=lambda key:e.entity(w,key)["attributes"]["value"])
                if e.entity(w,take)["attributes"]["value"] > e.entity(w,give)["attributes"]["value"]:
                    choice = dict(market="Swap",take_id=take,give_id=give)
            return dict(kind="market",player_id=pid,choice=choice)
    if hook == "submission_lock" and match._state["submissions"] == [None,None]:
        return dict(kind="submit",plans=[policy(observation(match,pid),**(weights or {})) for pid in (0,1)])
    return dict(kind="step",hook=hook)


def generate():
    castles = [["Keep","Stockpile","SummoningCircle","SiegeEngine","Bastion"]]*2
    cases = []
    for name,lords in (("bones_endurance",["Gremory","Humbaba"]),("spoils_rekindle",["Deimos","Kalligan"])):
        setup = dict(seed="u13-full-match:"+name,lords=lords,castles=castles)
        match, operations = FullMatch(setup),[]
        while match.outcome()["winner"] == -1:
            if match.clock.round > 40: raise ValueError("censored input game: "+name)
            op = next_operation(match)
            result = match.apply(op)
            if result["action"] == "invalid": raise ValueError(f"{name} round {match.clock.round} {op}: {result}")
            operations.append(op)
        cases.append(dict(name=name,setup=setup,operations=operations,
                          marching_probes=[next(i for i,op in enumerate(operations) if i > 60 and op.get("hook") == "marching")] if name == "spoils_rekindle" else []))
    return dict(schema=SCHEMA,policy=dict(id=POLICY,guard_cards=2,ward_period=4),round_cap=40,
                cases=cases,settlements=settlement_inputs.cases())
