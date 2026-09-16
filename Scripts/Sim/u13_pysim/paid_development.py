"""Paid Rites and Resummon, in native wrapper order.

Helpers mutate only an owned world inside the caller's transaction. A quote or
validation never pays; FullMatch stages previews separately. This implements
rules, not choices, and does not enable the five unsupported Lord integrations.
"""

from . import economy as e
from .opening import COSTS
from .copying import copy_data
from .battle import Battle, defense, note_loss, operational, threat
from .recruitment import retire


def ids_shape(value, count=None):
    return (type(value) is list and (count is None or len(value) == count)
            and all(type(key) is str and key for key in value) and len(set(value)) == len(value))


def rites_shape(choice):
    if type(choice) is not dict or set(choice) - {"invocation", "profane_ruins", "waiter_spends"}:
        return False
    if "invocation" in choice:
        part = choice["invocation"]
        if type(part) is not dict or set(part) != {"card_ids"} or not ids_shape(part["card_ids"]):
            return False
    if "profane_ruins" in choice:
        part = choice["profane_ruins"]
        if type(part) is not dict or set(part) != {"castle_id"} or type(part["castle_id"]) is not str or not part["castle_id"]:
            return False
    spends, used = choice.get("waiter_spends", []), set()
    if type(spends) is not list:
        return False
    for part in spends:
        if (type(part) is not dict or set(part) != {"lane", "marcher_ids"}
                or part["lane"] not in ("Lord", "Castle") or not ids_shape(part["marcher_ids"], 5)):
            return False
        if used.intersection(part["marcher_ids"]):
            return False
        used.update(part["marcher_ids"])
    return True


def veil(world):
    return world["data"]["neutral_tears"] + sum(p["resources"]["personal_tears"] for p in world["players"])


def can_pay(world, pid, selected):
    return e.cards_valid(world) and e.selection(e.zones(world)["hands"][pid], selected)


def validate_rites(world, pid, order):
    choice = order.get("rites", {})
    e.require(rites_shape(choice), "rites_shape_invalid")
    for spend in choice.get("waiter_spends", []):
        for key in spend["marcher_ids"]:
            row = e.entity(world, key)
            e.require(row and row["kind"] == "marcher" and row["owner"] == pid
                      and row["attributes"]["waiting"] and row["attributes"]["hp"] > 0
                      and row["attributes"]["lane"] == spend["lane"], "rite_waiter_unavailable")
    if "invocation" in choice:
        e.require(world["data"]["dominion_rites"]["invocation_rounds"][pid] == 0, "invocation_already_used")
        e.require(veil(world) >= 7, "invocation_veil_below_gate")
        payment = choice["invocation"]["card_ids"]
        e.require(can_pay(world, pid, payment), "invocation_cards_unavailable")
        e.require(sum(e.entity(world, key)["attributes"]["value"] for key in payment) >= 11,
                  "invocation_insufficient_payment")
        reserved = order.get("card_ids", []) if type(order.get("card_ids", [])) is list else []
        reserved = reserved[:]
        for name in ("castle_action", "summon"):
            other = order.get(name, {})
            if type(other) is dict and type(other.get("card_ids", [])) is list:
                reserved.extend(other.get("card_ids", []))
        if type(order.get("guard_moves", [])) is list:
            reserved.extend(move.get("card_id") for move in order.get("guard_moves", []) if type(move) is dict)
        e.require(not any(key in reserved for key in payment), "rite_card_already_reserved")
    if "profane_ruins" in choice:
        target = e.entity(world, choice["profane_ruins"]["castle_id"])
        ruins = [r for r in world["entities"]["entities"] if r["kind"] == "castle" and r["owner"] == pid
                 and r["attributes"]["status"] == "ruined"]
        e.require(len(ruins) >= 2 and target in ruins, "profane_ruins_target_unavailable")
        e.require(world["players"][pid]["resources"]["souls"] >= 2, "profane_ruins_insufficient_souls")
        castle = order.get("castle_action", {})
        e.require(type(castle) is not dict or castle.get("target_id") != target["id"], "rite_castle_already_reserved")
    return {"action": "legal"}


def reserve_rites(world, pid, order, number):
    validate_rites(world, pid, order)
    e.require(world["data"]["dominion_rites"]["orders"][pid] is None, "rites_already_reserved")
    choice = copy_data(order.get("rites", {}))
    if "invocation" in choice:
        e.discard(world, pid, choice["invocation"]["card_ids"])
    if "profane_ruins" in choice:
        world["players"][pid]["resources"]["souls"] -= 2
    world["data"]["dominion_rites"]["orders"][pid] = dict(round=number, choice=choice)


def resolve_rites(world, number, player_order, hook="development"):
    state, events = world["data"]["dominion_rites"], []
    e.require(hook == "development" and state["resolved_round"] == number-1, "rites_resolution_clock_invalid")
    def gain(pid, source, details):
        world["players"][pid]["resources"]["personal_tears"] += 1
        events.append(e.event("PERSONAL_TEAR_CREATED", dict(details, player_id=pid, round=number,
                              source=source, amount=1, veil_after=veil(world))))
    for pid in player_order:
        record = state["orders"][pid]
        e.require(record is not None and record["round"] == number, "rites_reservation_missing")
        choice = record["choice"]
        for spend in choice.get("waiter_spends", []):
            for key in spend["marcher_ids"]:
                row = e.entity(world, key)
                e.require(row and row["owner"] == pid and row["attributes"]["waiting"]
                          and row["attributes"]["lane"] == spend["lane"], "reserved_waiter_missing")
                retire(world, key)
            gain(pid, "waiters", dict(lane=spend["lane"], marcher_ids=spend["marcher_ids"]))
        if "invocation" in choice:
            state["invocation_rounds"][pid] = number
            gain(pid, "invocation", choice["invocation"])
        if "profane_ruins" in choice:
            row = e.entity(world, choice["profane_ruins"]["castle_id"])
            e.require(row and row["attributes"]["status"] == "ruined", "reserved_ruin_missing")
            row["attributes"].update(status="profaned", artillery_target="")
            gain(pid, "profane_ruins", dict(castle_id=row["id"], soul_cost=2))
    state["resolved_round"] = number
    return events


def summon_quote(world, pid, selected):
    actor = e.entity(world, world["players"][pid]["lord_entity_id"])
    e.require(actor and not actor["attributes"]["alive"], "summon_requires_banished_lord")
    e.require(can_pay(world, pid, selected), "summon_payment_unavailable")
    kind = actor["attributes"]["lord_id"]
    cost = COSTS[kind] + (3 if world["data"]["breach_lord"] == kind else 0)
    circles = sorted((r for r in world["entities"]["entities"] if r["kind"] == "castle" and r["owner"] == pid
                      and r["attributes"]["castle_type"] == "SummoningCircle" and operational(r)
                      and r["attributes"]["integrity"] >= 3), key=lambda r: r["attributes"]["castle_slot"])
    circle_id = circles[0]["id"] if circles else ""
    if circle_id:
        cost = max(0, cost-3)
    paid = sum(e.entity(world, key)["attributes"]["value"] for key in selected)
    shortfall = max(0, cost-paid)
    affordable = shortfall <= 4 and not (kind == "Humbaba" and shortfall > 0)
    marked = world["data"]["orias_marks"][pid] is not None
    returned = min(4, shortfall+int(marked))
    if marked and shortfall < 4:
        # Quote Conduit against the board AFTER the offering, without exerting
        # any live Circle. Threat shortfall itself is a baseline, not a gain.
        predicted = copy_data(world)
        if circle_id:
            e.entity(predicted, circle_id)["attributes"]["integrity"] -= 3
        prior, later = copy_data(actor), copy_data(actor)
        prior["attributes"]["threat"], later["attributes"]["threat"] = shortfall, shortfall+1
        protects = (threat(actor) is not None and defense(predicted, later) < defense(predicted, prior)
                    and any(r["owner"] == pid and r["attributes"].get("castle_type") == "SummoningCircle"
                            and operational(r) for r in predicted["entities"]["entities"]))
        returned = shortfall+1-int(protects)
    return dict(action="legal" if affordable else "invalid", reason="" if affordable else "summon_payment_shortfall",
                lord_id=actor["id"], cost=cost, paid_value=paid, circle_id=circle_id,
                shortfall=shortfall, return_threat=returned, marked=marked)


def validate_summon(world, pid, order):
    if "summon" not in order:
        return {"action": "legal"}
    choice = order["summon"]
    e.require(type(choice) is dict and set(choice) == {"card_ids"} and type(choice["card_ids"]) is list,
              "summon_choice_invalid")
    e.require("action" not in order or order["action"] in ("Hunt", "Siege", "Ward"), "summon_combat_unavailable")
    castle, moves = order.get("castle_action", {}), order.get("guard_moves", [])
    e.require(type(castle) is dict and type(castle.get("card_ids", [])) is list
              and type(order.get("card_ids", [])) is list and type(moves) is list, "summon_order_shape_invalid")
    reserved = castle.get("card_ids", []) + order.get("card_ids", [])
    for move in moves:
        e.require(type(move) is dict, "guard_moves_invalid")
        reserved.append(move.get("card_id"))
    e.require(not any(key in reserved for key in choice["card_ids"]), "summon_card_already_reserved")
    return summon_quote(world, pid, choice["card_ids"])


def reserve_summon(world, pid, order, number):
    e.require(world["data"]["summon_orders"][pid] is None, "summon_already_reserved")
    quote = validate_summon(world, pid, order)
    if quote["action"] == "invalid":
        raise e.Rejected(quote["reason"], quote)
    world["data"]["summon_orders"][pid] = dict(round=number, choice=copy_data(order.get("summon", {})), quote=quote)
    if "summon" in order:
        e.discard(world, pid, order["summon"]["card_ids"])


def resolve_summon(world, number, player_order, hook="development"):
    d, events = world["data"], []
    e.require(hook == "development" and d["summon_round"] < number, "summon_phase_invalid")
    for pid in player_order:
        record = d["summon_orders"][pid]
        e.require(record is not None and record["round"] == number, "summon_reservation_missing")
        if not record["choice"]:
            continue
        quote = record["quote"]
        actor = e.entity(world, quote["lord_id"])
        e.require(actor and not actor["attributes"]["alive"], "summon_reserved_lord_invalid")
        if quote["circle_id"]:
            circle = e.entity(world, quote["circle_id"])
            e.require(circle and circle["attributes"]["integrity"] >= 3, "summon_circle_missing")
            before = circle["attributes"]["integrity"]
            circle["attributes"]["integrity"] -= 3
            note_loss(circle, before, number)
            if circle["attributes"]["integrity"] == 0:
                circle["attributes"]["status"] = "defunct"
        actor["attributes"]["alive"] = True
        if actor["attributes"]["lord_id"] != "Humbaba":
            actor["attributes"]["threat"] = quote["shortfall"]
            if quote["marked"] and quote["shortfall"] < 4:
                _, gained = Battle(world, number, "", player_order, hook).conduit(actor, 1)
                events.extend(gained)
        d["summon_counts"][pid] += 1
        d["neutral_tears"] += 1
        events.extend([e.event("LORD_RESUMMONED", dict(player_id=pid, lord_id=actor["id"], round=number,
            hook=hook, card_ids=record["choice"]["card_ids"], cost=quote["cost"], return_threat=quote["return_threat"], marked=quote["marked"])),
            e.event("NEUTRAL_TEAR_CREATED", dict(amount=1, source="Resummon", round=number))])
    d["summon_round"] = number
    return events
