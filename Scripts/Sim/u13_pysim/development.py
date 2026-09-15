"""U13 Guard deployment, Work and stable bonds; no paid repairs or combat."""

from copy import deepcopy
import json

from . import economy as e
from .planning import PlanningMatch
from .primitives import instance_id

VERSION = "U13_PYSIM_DEVELOPMENT_V1"
SUITS = ("Butcher", "Penitent", "Wright", "Vulture")
LANES = ("Lord", "Castle")


def reconstructible(world, pid, castle):
    if not castle or castle["kind"] != "castle" or castle["owner"] != pid:
        return False
    player = world["players"][pid]
    lord = e.entity(world, player["lord_entity_id"])
    return (player["lord_id"] == "Deimos" and lord["attributes"]["alive"]
            and castle["attributes"]["combat_profile"] == "siege_engine"
            and castle["attributes"]["status"] == "ruined")


def eligible(world, pid, target):
    if not target or target["kind"] != "castle" or target["owner"] != pid:
        return False
    a = target["attributes"]
    if a["status"] == "profaned":
        return False
    if a["status"] == "ruined":
        return reconstructible(world, pid, target)
    return a["integrity"] < a["max_integrity"] or a["construction_state"] != "active"


def validate_choice(world, pid, choice):
    # The caller supplies the Construction.choice_shape data contract, as in
    # Godot GuardWork.validate_choice. This function is the Work admission rule.
    if choice:
        e.require(choice.get("action") == "Work" and choice.get("card_ids") == []
                  and choice.get("use_repair_token") is False, "choose_work_target_without_payment")
        if choice["target_id"]:
            target = e.entity(world, choice["target_id"])
            e.require(eligible(world, pid, target), "work_target_unavailable")
            return dict(action="legal", paid_value=0, reconstruction=target["attributes"]["status"] == "ruined")
    return dict(action="legal", paid_value=0, reconstruction=False)


def intact(world, pair):
    if not pair["active"]:
        return False
    for index, identity in enumerate(pair["ids"]):
        row = e.entity(world, identity)
        if (not row or row["owner"] != pair["player_id"] or row["attributes"].get("role") != "guard"
                or row["attributes"].get("lane") != pair["lane"]
                or row["attributes"].get("slot") != pair["slots"][index]
                or row["attributes"].get("suit") != pair["suit"]):
            return False
    return True


def reconcile(world):
    for pair in world["data"]["guard_work"]["pairs"]:
        if pair["active"] and not intact(world, pair):
            pair["active"] = False


def deploy(raw, number, player_order, hook="development"):
    """Pure counterpart of GuardDeployment.resolve, after validated reservations."""
    e.require(hook == "development" and raw["data"]["guard_deployment_round"] < number,
              "guard_development_timing_invalid")
    world, events = deepcopy(raw), []
    for pid in player_order:
        record = world["data"]["guard_orders"][pid]
        e.require(record is not None and record["round"] == number, "guard_order_missing")
        for move in record["moves"]:
            card = e.entity(world, move["card_id"])
            e.require(card and card["id"] in e.zones(world)["hands"][pid] and card["owner"] == pid,
                      "reserved_guard_missing")
            e.zones(world)["hands"][pid].remove(card["id"])
            card["attributes"].update(role="guard", lane=move["lane"], slot=int(move["slot"]))
            events.append(e.event("GUARD_DEPLOYED", dict(player_id=pid, card_id=card["id"],
                                 lane=move["lane"], slot=move["slot"], round=number, hook=hook)))
    world["data"]["guard_deployment_round"] = number
    return dict(action="resolved", world=world, events=events)


def work(world, number, player_order):
    """Mutate an owned world exactly as GuardWork.develop does."""
    reconcile(world)
    state, events = world["data"]["guard_work"], []
    if state["developed_round"] >= number:
        return events
    for pid in player_order:
        moves = world["data"]["guard_orders"][pid]["moves"]
        amount = len(moves)
        for lane in LANES:
            for suit in SUITS:
                fresh = sorted((m for m in moves if m["lane"] == lane
                                and e.entity(world, m["card_id"])["attributes"]["suit"] == suit),
                               key=lambda m: m["slot"])
                if len(fresh) < 2:
                    continue
                pair = dict(player_id=pid, lane=lane, suit=suit, ids=[m["card_id"] for m in fresh[:2]],
                            slots=[m["slot"] for m in fresh[:2]], round=number, active=True)
                state["pairs"].append(pair)
                if suit == "Wright":
                    amount += 5
                events.append(e.event("GUARD_PAIR_FORMED", dict(player_id=pid, round=number,
                                      lane=lane, suit=suit, card_ids=pair["ids"])))
        selected = world["data"]["castle_orders"][pid]["choice"]
        if selected:
            state["targets"][pid] = selected["target_id"]
        if not state["targets"][pid]:
            continue
        target = e.entity(world, state["targets"][pid])
        if not eligible(world, pid, target):
            state["targets"][pid] = ""
            continue
        a = target["attributes"]
        reconstruction = a["status"] == "ruined"
        build = a["construction_state"] != "active" or reconstruction
        passive = 3 if build else 0
        gain = amount + passive
        if not build and a.get("repair_lock_until_round", 0) >= number:
            gain = 0
        before = a["integrity"]
        a["integrity"] = min(a["max_integrity"], before + gain)
        if build:
            a["construction_state"] = "active" if a["integrity"] >= a["max_integrity"] else "building"
            a.pop("repair_lock_until_round", None)
            a["artillery_target"] = ""
        if a["integrity"] > 0:
            a["status"] = "standing"
        details = dict(player_id=pid, round=number, castle_id=target["id"], before=before,
                       after=a["integrity"], work=amount, passive=passive, reconstruction=reconstruction)
        events.append(e.event("WORK_RESOLVED", details))
        if build and a["construction_state"] == "active":
            events.append(e.event("CASTLE_ACTIVATED", details))
        if a["integrity"] >= a["max_integrity"]:
            state["targets"][pid] = ""
    state["developed_round"] = number
    return events


def draw_pairs(world, number, seed):
    reconcile(world)
    state, events = world["data"]["guard_work"], []
    if state["draw_round"] >= number:
        return events
    for pair in state["pairs"]:
        if not pair["active"] or pair["suit"] != "Vulture" or pair["round"] >= number:
            continue
        key = instance_id("guard_draw", str(number), json.dumps(pair["ids"], ensure_ascii=False, separators=(",", ":")))
        drawn = e.draw(world, pair["player_id"], seed, key)
        if drawn["drawn"]:
            # Authority publishes the gain, not the newly drawn card identity.
            events.append(e.event("GUARD_PAIR_DRAW", dict(player_id=pair["player_id"], round=number,
                                 amount=1, lane=pair["lane"])))
    state["draw_round"] = number
    return events


class DevelopmentMatch(PlanningMatch):
    """Fresh-game six-hook adapter; later phase semantics remain unsupported."""
    HOOK_LIMIT = 6

    def _hook(self):
        if self.clock.hook != "development":
            return super()._hook()
        w, number = self.state["world"], self.clock.round
        d = w["data"]
        if (number != 1 or self.state["pending"]["pending"] or self.state["persistent"]["active"]
                or self.state["cooldowns"]["locks"]):
            raise e.Unsupported("DevelopmentMatch requires the supported fresh-game planning prefix")
        # Empty Rites -> empty Resummon -> construction clock -> deployed Guards
        # -> Work/pairs. The adapter has already rejected paid Rites and powers.
        for ledger in (d["dominion_rites"]["orders"], d["summon_orders"]):
            if any(record and record["choice"] for record in ledger):
                raise e.Unsupported("Paid Rites and Resummon resolution are not implemented")
        e.require(d["dominion_rites"]["resolved_round"] == number - 1
                  and d["summon_round"] < number and d["construction_round"] < number,
                  "transform_contract_error")
        for ledger in (d["dominion_rites"]["orders"], d["summon_orders"]):
            e.require(all(record and record["round"] == number for record in ledger), "transform_contract_error")
        d["dominion_rites"]["resolved_round"] = number
        d["summon_round"] = number
        d["construction_round"] = number
        try:
            deployed = deploy(w, number, self.state["player_order"])
        except e.Rejected as error:
            # Match._apply_transform wraps the content rejection at this hook.
            raise e.Rejected("transform_contract_error") from error
        self.state["world"] = deployed["world"]
        rows = self.state["events"]["rows"]
        rows.extend(deployed["events"])
        rows.extend(work(self.state["world"], number, self.state["player_order"]))
        self.state["world"]["data"]["vacant_throne"]["present"] = [True, True]
