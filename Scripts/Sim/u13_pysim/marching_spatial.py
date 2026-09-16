"""Integer spatial helpers mirrored from U13 Marching, LaneAuras and GravityOrbs."""

import math

from .economy import Rejected, Unsupported

LANES = ("Lord", "Castle")
CONTACT2, GAP2, RANGE2 = 180 ** 2, 84 ** 2, 800 ** 2
RANGED = "U13_VULTURE_RANGED_V1"
ROUT = "U13_ROUT_V1"
WEB = "U13_SPATIAL_WEB_FIELDS_V1"
AURAS = "U13_LANE_AURAS_V1"


def distance(ax, ay, bx, by):
    return (ax - bx) ** 2 + (ay - by) ** 2


def scaled(value, speed, length):
    amount = (abs(value) * speed + (length >> 1)) // length
    return -amount if value < 0 else amount


def ceil_sqrt(value):
    root = math.isqrt(value)
    return root + (root * root != value)


def half_away(value):
    # Godot roundi, not Python's ties-to-even round.
    return math.floor(value + 0.5) if value >= 0 else math.ceil(value - 0.5)


def speed(base, percent, recovering, clock, web=False, collapse=False):
    denominator = (200 if recovering else 100) * (2 if web else 1) * (2 if collapse else 1)
    numerator = base * (100 + percent)
    phase = clock % denominator
    return ((phase + 1) * numerator) // denominator - (phase * numerator) // denominator


def compile_effects(effects, number, data, *, full=False):
    modifiers = {lane: [dict(regen_bonus=0, speed_percent=0) for _ in (0, 1)] for lane in LANES}
    fields = {lane: [] for lane in LANES}
    for active in effects:
        payload = active["payload"]
        if not full and set(payload) - {"lane_aura", "spatial_field"}:
            raise Unsupported("Marching spike does not advance other persistent effects")
        if "spatial_field" in payload and data.get("spatial_field_profile") == WEB:
            target, spec = active["target"], payload["spatial_field"]
            point = target.get("field_position", {})
            if (active["declaration"]["power_id"] != "Web" or set(target) != {"lane", "field_position"}
                    or target["lane"] not in LANES or set(point) != {"x_fp", "y_fp"}
                    or not all(type(v) is int for v in point.values())
                    or not 0 <= point["x_fp"] <= 2400 or not 0 <= point["y_fp"] <= 600):
                raise Rejected("spatial_field_source_invalid")
            if (type(spec) is not dict or set(spec) != {"kind", "radius_fp"} or spec["kind"] != "web"
                    or type(spec["radius_fp"]) is not int or not 0 <= spec["radius_fp"] <= 3000):
                raise Rejected("spatial_field_payload_invalid")
        if not active["activated_round"] <= number < active["activated_round"] + len(active["stages"]):
            continue
        lane, owner = active["target"]["lane"], active["declaration"]["player_id"]
        if "lane_aura" in payload and data.get("lane_aura_profile") == AURAS:
            for key in ("regen_bonus", "speed_percent"):
                modifiers[lane][owner][key] += payload["lane_aura"][key]
        if "spatial_field" in payload and data.get("spatial_field_profile") == WEB:
            point = active["target"]["field_position"]
            fields[lane].append((owner, point["x_fp"], point["y_fp"], payload["spatial_field"]["radius_fp"] ** 2))
    return modifiers, fields


def swept(ax, ay, bx, by, px, py):
    dx, dy = bx - ax, by - ay
    vx, vy = px - ax, py - ay
    length, dot = dx * dx + dy * dy, vx * dx + vy * dy
    if length == 0 or dot <= 0:
        return distance(ax, ay, px, py) <= 65 ** 2
    if dot >= length:
        return distance(bx, by, px, py) <= 65 ** 2
    return (vx * dy - vy * dx) ** 2 <= 65 ** 2 * length


def gravity(s, orbs, before, number, tick, collapse, emit):
    """Pull uses pre-movement positions; consumption tests the swept segment."""
    old_x, old_y, indices = before
    tears = 0
    for i in indices:
        if not s.alive[i]:
            continue
        ax, ay, chosen, best = old_x[i], old_y[i], None, (1 << 63) - 1
        for orb in orbs:
            if orb["target"]["lane"] != s.lane[i]:
                continue
            point = orb["target"]["field_position"]
            gap = distance(ax, ay, point["x_fp"], point["y_fp"])
            if gap <= 248 ** 2 and (gap < best or gap == best and (chosen is None or orb["id"] < chosen["id"])):
                chosen, best = orb, gap
        if chosen is not None and s.movement_ready_round[i] <= number:
            point = chosen["target"]["field_position"]
            length = max(1, ceil_sqrt(best))
            pull = (7 + tick % 2) >> 1 if collapse else 7
            s.x_fp[i] = ax + half_away(float(point["x_fp"] - ax) * pull / length)
            s.y_fp[i] = ay + half_away(float(point["y_fp"] - ay) * pull / length)
            s.waiting[i], s.contact_tick[i] = False, -1
        for orb in orbs:
            point = orb["target"]["field_position"]
            if orb["target"]["lane"] != s.lane[i] or not swept(ax, ay, s.x_fp[i], s.y_fp[i], point["x_fp"], point["y_fp"]):
                continue
            s.retire(i)
            orb["consumed"] += 1
            reward = orb["consumed"] >= 4 and not orb["rewarded"]
            orb["rewarded"] = orb["consumed"] >= 4
            tears += int(reward)
            emit("GRAVITY_ORB_CONSUMED", dict(effect_id=orb["id"], player_id=orb["owner"], unit=s.row(i),
                 consumed=orb["consumed"], neutral_tears=int(reward), round=number, tick=tick))
            break
    return tears
