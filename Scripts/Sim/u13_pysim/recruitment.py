"""Exact commitment recruitment and spawn placement; no Marching tick loop.

These are boundary entity records, not a choice of the future tick-loop layout.
Godot U13Marching.profile/place_spawn own the constants and keyed placement.
"""

from . import economy as e
from .copying import copy_data
from .primitives import draw, entity_id

SUITS = ("Butcher", "Penitent", "Vulture", "Wright")
STATS = ((3, 1, 1, 4), (1, 3, 2, 3), (1, 1, 1, 4), (1, 2, 1, 4))


def profile(suit, lane, pid, birth, ready):
    attack, armor, regen, step = STATS[SUITS.index(suit)]
    return dict(attack=attack, armor=armor, regen=regen, step_fp=step,
                armor_bypass=False, suit=suit, lane=lane, hp=5, max_hp=5,
                birth_round=birth, movement_ready_round=ready,
                x_fp=0 if pid == 0 else 2400, y_fp=300, contact_tick=-1,
                direction=1 if pid == 0 else -1, waiting=False, waiting_since_round=0)


def create(world, origin, ordinal, pid, attributes):
    registry = world["entities"]
    identity = entity_id("marcher", origin, ordinal)
    e.require(identity not in registry["used_ids"], "entity_identity_already_used")
    row = dict(id=identity, kind="marcher", origin=origin, ordinal=ordinal,
               owner=pid, attributes=copy_data(attributes))
    registry["entities"].append(row)
    registry["entities"].sort(key=lambda r: r["id"])
    registry["used_ids"].append(identity)
    registry["used_ids"].sort()
    return row


def retire(world, identity):
    rows = world["entities"]["entities"]
    target = e.entity(world, identity)
    e.require(bool(target), "entity_missing")
    rows.remove(target)  # Identity remains in used_ids forever.


def place_near_spawn(world, row, origin):
    a = row['attributes']
    for dx, dy in ((0,84),(0,-84),(84,0),(-84,0),(84,84),(-84,-84)):
        nx, ny = max(0,min(2400,origin['x_fp']+dx)), max(0,min(600,origin['y_fp']+dy))
        free = True
        for other in world['entities']['entities']:
            if other['kind'] != 'marcher' or other['id'] == row['id'] or other['owner'] != row['owner'] or other['attributes']['lane'] != a['lane']: continue
            b = other['attributes']; gap = (nx-b['x_fp'])**2+(ny-b['y_fp'])**2
            if gap < 84*84 and gap < (a['x_fp']-b['x_fp'])**2+(a['y_fp']-b['y_fp'])**2:
                free = False; break
        if free:
            a.update(x_fp=nx,y_fp=ny); break


def place_spawn(world, row, seed):
    a, best, clearance = row["attributes"], copy_data(row["attributes"]), -1
    for attempt in range(64):
        forward = draw(seed, row["id"], "SPAWN_FORWARD", attempt, 121)
        candidate = dict(a, x_fp=forward if row["owner"] == 0 else 2400 - forward,
                         y_fp=90 + draw(seed, row["id"], "SPAWN_LATERAL", attempt, 421))
        nearest = (1 << 63) - 1
        for other in world["entities"]["entities"]:
            if (other["kind"] == "marcher" and other["id"] != row["id"]
                    and other["owner"] == row["owner"] and other["attributes"]["lane"] == a["lane"]):
                b = other["attributes"]
                nearest = min(nearest, (candidate["x_fp"] - b["x_fp"]) ** 2
                              + (candidate["y_fp"] - b["y_fp"]) ** 2)
        if nearest > clearance:
            clearance, best = nearest, candidate
        if nearest >= 84 * 84:
            break
    row["attributes"] = best
    return row
