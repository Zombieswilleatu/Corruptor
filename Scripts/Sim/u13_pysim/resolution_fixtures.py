"""Explicit input corpus; fixture edits are never match operations or policy.

Both engines read this input manifest. They independently construct every initial
world and compute each result; the manifest contains no expected state or result.
"""

import hashlib
import json
from pathlib import Path

from . import economy as e, recruitment
from .copying import copy_data
from .development import DevelopmentMatch
from .resolution import resolve

INPUTS = Path(__file__).with_name("resolution_inputs.json")


def inputs():
    return json.loads(INPUTS.read_text(encoding="utf-8"))


def input_hash():
    return hashlib.sha256(INPUTS.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def component_initial(spec):
    game = DevelopmentMatch(spec["setup"])
    for op in spec["initial_operations"]:
        e.require(game.apply(op)["action"] != "invalid", "component_prefix_invalid")
    e.require(game.clock.hook == "post_repair_artillery", "component_prefix_incomplete")
    return game.snapshot()["world"]


def component_apply(raw, op):
    kind = op["kind"]
    if kind == "resolve":
        return resolve(raw, op["round"], op["seed"], op["player_order"], op["hook"], op["orders"])
    w = copy_data(raw)
    if kind == "fixture_patch":
        row = e.entity(w, op["entity_id"])
        row["attributes"].update(copy_data(op["attributes"]))
    elif kind == "fixture_set":
        parent = w
        for key in op["path"][:-1]: parent = parent[key]
        parent[op["path"][-1]] = copy_data(op["value"])
    elif kind == "fixture_card":
        z, identity = e.zones(w), op["card_id"]
        for pile in [z["deck"], z["discard"], *z["hands"], *z["committed"], z["market"], z["market_reserve"]]:
            if identity in pile: pile.remove(identity)
        card = e.entity(w, identity)
        card["owner"] = op["player_id"]
        for key in ("role", "lane", "slot"): card["attributes"].pop(key, None)
        card["attributes"].update(copy_data(op["attributes"]))
        if op["pile"]: z[op["pile"]][op["player_id"]].append(identity)
    elif kind == "fixture_spawn":
        a = recruitment.profile(op["suit"], op["lane"], op["player_id"], op["birth"], op["ready"])
        a.update(copy_data(op["attributes"]))
        recruitment.create(w, op["origin"], op["ordinal"], op["player_id"], a)
    else:
        raise ValueError("unknown resolution fixture operation: " + str(kind))
    return dict(result=dict(action="fixture_prepared"), world=w)
