"""Explicit full-world integration of the accepted Marcher column kernel.

Cards, Castles and Lords remain in the owned registry through every reaction.
This first match path admits four Lords and no declared powers/active actors.
The isolated API keeps its original boundary and never silently admits a game.
"""

from . import marching as m, veil
from .copying import copy_data
from .economy import Rejected, Unsupported
from .marching_columns import Columns

LORDS = ("Gremory", "Deimos", "Humbaba", "Kalligan")


def supported(context):
    w = context["world"]
    if context.get("full_roster"):
        from .power_match import LORDS as all_lords
        if any(p["lord_id"] not in all_lords for p in w["players"]): raise Unsupported("Unknown Lord")
        return
    if (set(w) != {"players", "entities", "data"} or len(w["players"]) != 2
            or any(p["lord_id"] not in LORDS for p in w["players"])
            or w["data"].get("breach_lord", "") not in ("", *LORDS)):
        raise Unsupported("Full Marching integration currently supports Gremory, Deimos, Humbaba and Kalligan")
    actors = w["data"].get("kroni_actors", [])
    permanent_actors = context.get("permanent_breaches") and veil.active(w,"Kroni") and all(a.get("breach") for a in actors)
    if context.get("persistent_effects") or (actors and not permanent_actors) or any(w["data"].get(k) for k in
            ("valak_orbs", "kanifous_objects", "kanifous_prices")):
        raise Unsupported("Declared spatial effects and actors are outside the first full-match path")
    if any(set(row["attributes"]) & {"blood_wish", "ghost_wishes", "ghost_bypassed"}
           for row in w["entities"]["entities"]):
        raise Unsupported("Wishmaster alterations are outside the first full-match path")


def resolve(context, reaction, *, capture_ticks=False):
    supported(context)
    if context.get("hook") != "marching" or not m.valid(context["world"]):
        return dict(action="invalid", reason="marching_context_invalid")
    if context["world"]["data"].get("opening_marching_round" if context.get("opening_marching") else "marching_round", 0) >= context["round"]:
        return dict(action="invalid", reason="marching_already_applied")
    try:
        try:
            phase = m.Phase(context, capture_ticks, reaction, keep_background=True)
        except ValueError:
            return dict(action="invalid", reason="marching_entities_invalid")
        return phase.run()
    except Rejected as error:
        return dict(action="invalid", reason=str(error))


def regenerate(context):
    supported(context)
    world, number = copy_data(context["world"]), context["round"]
    if context.get("hook") != "round_start_automatic" or not m.valid(world):
        return dict(action="invalid", reason="marching_regen_context_invalid")
    if world["data"].get("marching_regen_round", 0) >= number:
        return dict(action="invalid", reason="marching_regen_already_applied")
    modifiers, _ = m.compile_effects(context.get("persistent_effects", []), number, world["data"], full=context.get("full_roster",False))
    s, events = Columns(world["entities"], keep_background=True), []
    for i in s.active():
        if s.waiting[i]:
            continue
        before = s.hp[i]
        s.hp[i] = min(s.max_hp[i], before+s.regen[i]+modifiers[s.lane[i]][s.owner[i]]["regen_bonus"])
        if s.hp[i] != before:
            fact = dict(type="MARCHER_REGENERATED", text="", data=dict(entity_id=s.ids[i], before=before,
                        after=s.hp[i], round=number, hook=context["hook"]))
            events.append(dict(event=fact, views=[copy_data(fact), copy_data(fact)]))
    world["entities"] = s.snapshot()
    world["data"]["marching_regen_round"] = number
    return dict(action="resolved", world=world, events=events)
