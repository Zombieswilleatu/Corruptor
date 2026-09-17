"""Explicit directed inputs for Development parity, tests and partial timing.

Fixture preparation is outside game rules. It never loads an expected Godot
world into the Python match and is not a policy or a full-round simulation.
"""

from copy import deepcopy

from . import economy as e, opening, development as d
from .primitives import Entities
from .timeline import HOOKS

ATTEMPTS = (2, 0, 1, 7, 10, 9, 0, 3, 6)
COMPONENT_SEED = "u13-development-components:é"
COMPONENT_NAMES = ["work_lifecycle", *[f"pair_{suit}_{lane}" for suit in d.SUITS for lane in d.LANES],
                   "reconstruction", "atomic_deployment"]


def setup(index):
    return dict(seed=f"u13-python-development:é:{index}:{ATTEMPTS[index]}",
                lords=[opening.LORDS[index], opening.LORDS[(index + 1) % 9]],
                castles=[list(opening.CASTLES), list(opening.CASTLES)])


def choice(target):
    return dict(action="Work", target_id=target, card_ids=[], use_repair_token=False)


def move(identity, lane, slot):
    return dict(card_id=identity, lane=lane, slot=slot)


def scripted_operations(index):
    """Prepare input decisions once; callers can replay them without a bot."""
    game = d.DevelopmentMatch(setup(index))
    operations = []
    def apply(op):
        operations.append(op)
        e.require(game.apply(op)["action"] != "invalid", "invalid_development_fixture")
    for hook in HOOKS[:3]:
        apply(dict(kind="step", hook=hook))
    for _ in range(2):
        apply(dict(kind="market", player_id=game.state["world"]["data"]["game_market"]["seat"],
                   choice={"market": "Pass"}))
    apply(dict(kind="step", hook=HOOKS[3]))
    w, plans = game.state["world"], []
    for pid in (0, 1):
        suit = d.SUITS[(index + 2 * pid) % 4]
        picked = [identity for identity in e.zones(w)["hands"][pid]
                  if e.entity(w, identity)["attributes"]["suit"] == suit][:2]
        e.require(len(picked) == 2, "directed_hand_missing_pair")
        lane = d.LANES[(index // 4 + pid) % 2]
        target = opening.castle_id(pid, 3)
        plans.append(dict(powers=[], order=dict(guard_moves=[move(picked[0], lane, 2), move(picked[1], lane, 0)],
                                               castle_action=choice(target))))
    operations.append(dict(kind="submit", plans=plans))
    operations.extend(dict(kind="step", hook=hook) for hook in HOOKS[4:6])
    return operations


def component_world():
    return opening.world(COMPONENT_SEED, ["Deimos", "Gremory"], [list(opening.CASTLES)] * 2)


def component_apply(raw, op):
    w, result = deepcopy(raw), {"action": "fixture_prepared"}
    kind = op["kind"]
    try:
        if kind == "fixture_give":
            z = e.zones(w)
            for pile in [z["deck"], z["discard"], *z["hands"], *z["committed"], z["market"], z["market_reserve"]]:
                if op["card_id"] in pile:
                    pile.remove(op["card_id"])
            card = e.entity(w, op["card_id"])
            card["owner"] = op["player_id"]
            for key in ("role", "lane", "slot"):
                card["attributes"].pop(key, None)
            z["hands"][op["player_id"]].append(op["card_id"])
        elif kind == "fixture_patch":
            row = e.entity(w, op["entity_id"])
            row["owner"] = op.get("owner", row["owner"])
            row["attributes"].update(deepcopy(op["attributes"]))
        elif kind == "fixture_retire":
            ids = Entities()
            ids.restore(w["entities"])
            ids.retire(op["entity_id"])
            w["entities"] = ids.snapshot()
        elif kind == "fixture_exhaust_deck":
            z = e.zones(w)
            z["discard"].extend(z["deck"])
            z["deck"].clear()
        elif kind == "fixture_stage":
            w["data"]["guard_public_round"] = op["round"]
            for pid in (0, 1):
                w["data"]["guard_orders"][pid] = dict(round=op["round"], moves=deepcopy(op["moves"][pid]))
                w["data"]["castle_orders"][pid] = dict(round=op["round"], choice=deepcopy(op["choices"][pid]),
                                                       paid_value=0, reconstruction=False)
        elif kind == "deploy":
            result = d.deploy(w, op["round"], op["player_order"])
            w = result.pop("world")
        elif kind == "work":
            result = dict(action="resolved", events=d.work(w, op["round"], op["player_order"]))
        elif kind == "pair_draw":
            result = dict(action="resolved", events=d.draw_pairs(w, op["round"], COMPONENT_SEED))
        elif kind == "reconcile":
            d.reconcile(w)
            result = dict(action="resolved", events=[])
        elif kind == "validate_work":
            result = d.validate_choice(w, op["player_id"], op["choice"])
        elif kind == "discard":
            result = e.discard(w, op["player_id"], op["card_ids"])
        else:
            raise e.Unsupported("Unknown Development component operation " + str(kind))
        return dict(result=result, world=w)
    except e.Rejected as error:
        return dict(result=dict(action="invalid", reason=str(error)), world=deepcopy(raw))
