"""Input-only isolated Marching scenarios; never full-match fixture shortcuts."""

import hashlib
import json
from pathlib import Path

from . import marching as m
from .copying import copy_data
from .primitives import Entities
from .recruitment import profile

INPUTS = Path(__file__).with_name("marching_inputs.json")


def load():
    return json.loads(INPUTS.read_text(encoding="utf-8"))


def input_hash():
    return hashlib.sha256(INPUTS.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def initial(spec):
    registry = Entities()
    for unit in spec["units"]:
        a = profile(unit["suit"], unit["lane"], unit["owner"], unit.get("birth", 0), unit.get("ready", 1))
        if unit["suit"] == "Vulture" and not spec["ranged"]:
            a.update(attack=2, step_fp=6, armor_bypass=True)
        if unit["suit"] == "Wright" and not spec["ranged"]:
            a["attack"] = 2
        a.update(copy_data(unit["attributes"]))
        registry.create("marcher", unit["origin"], unit["ordinal"], unit["owner"], a)
    state = registry.snapshot()
    if spec.get("reverse_registry", False):
        state["entities"].reverse()
        state["used_ids"].reverse()
    data = copy_data(spec["data"])
    if spec["ranged"]:
        data["ranged_profile"] = m.RANGED
    return dict(entities=state, data=data)


def context(spec, world, number, hook="marching"):
    return dict(world=world, seed=spec["seed"], round=number, hook=hook,
                player_order=spec["player_order"], persistent_effects=spec["effects"])


def reject_reaction(world, fact, seed, order):
    return dict(action="invalid", reason="deliberate_fixture_rejection")


def apply(spec, raw, op, *, capture_ticks=True):
    if op["kind"] in ("march", "regen"):
        ctx = context(spec, raw, op["round"], op.get("hook", "marching" if op["kind"] == "march" else "round_start_automatic"))
        result = (m.resolve(ctx, capture_ticks=capture_ticks, reaction=reject_reaction if spec.get("reaction") == "reject" else None)
                  if op["kind"] == "march" else m.regenerate(ctx))
        return dict(result={k: v for k, v in result.items() if k != "world"}, world=result.get("world", raw))
    world = copy_data(raw)
    registry = Entities()
    registry.restore(world["entities"])
    if op["kind"] == "fixture_retire":
        registry.retire(op["id"])
    elif op["kind"] == "fixture_owner":
        row = registry.rows[op["id"]]
        row["owner"] = op["owner"]
        row["attributes"]["direction"] = 1 if op["owner"] == 0 else -1
    elif op["kind"] == "fixture_patch":
        registry.rows[op["id"]]["attributes"].update(copy_data(op["attributes"]))
    else:
        raise ValueError("Unknown Marching fixture operation")
    world["entities"] = registry.snapshot()
    return dict(result=dict(action="fixture_prepared"), world=world)


def strip_ticks(result):
    return dict(result, events=[r for r in result.get("events", []) if r["event"]["type"] != "MARCHING_TICK"]) if "events" in result else result
