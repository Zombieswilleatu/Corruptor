"""Independent isolated U13 Marching phase, with owned flat-column working state.

This is not a full-match hook adapter. Worlds contain Marchers and explicitly
prepared phase fields/actors, without implicit Lord reactions or declarations.
Godot U13Marching.resolve is the authority for every output event and field.
"""

import json
from bisect import bisect_left

from .copying import copy_data
from .economy import Rejected, Unsupported
from .marching_columns import Columns
from .marching_spatial import (LANES, CONTACT2, GAP2, RANGE2, RANGED, ROUT, WEB, AURAS,
                               distance, scaled, ceil_sqrt, speed, compile_effects, gravity)
from .primitives import entity_id, instance_id, draw

VERSION = "U13_PYSIM_MARCHING_SPIKE_V2_RANGE_SENTINEL"
MODEL = "U13_MARCHING_SPATIAL_V2"
TICKS = 200
INTEGER_FIELDS = ("hp", "max_hp", "attack", "armor", "regen", "step_fp", "birth_round",
                  "movement_ready_round", "x_fp", "y_fp", "contact_tick", "direction", "waiting_since_round")


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def valid(world, check_duels=True):
    try:
        data = world["data"]
        for field, expected in (("ranged_profile", RANGED), ("rout_profile", ROUT),
                                ("spatial_field_profile", WEB), ("lane_aura_profile", AURAS)):
            # Rout profile itself is only checked when a Marcher carries a Rout tag.
            if field != "rout_profile" and field in data and data[field] != expected:
                return False
        for field in ("marching_round", "marching_regen_round"):
            if type(data.get(field, 0)) is not int or data.get(field, 0) < 0:
                return False
        for row in world["entities"]["entities"]:
            if row["kind"] != "marcher":
                continue
            a = row["attributes"]
            if row["owner"] not in (0, 1) or a.get("suit") not in ("Butcher", "Penitent", "Vulture", "Wright") or a.get("lane") not in LANES:
                return False
            if any(type(a.get(field)) is not int for field in INTEGER_FIELDS):
                return False
            if not (1 <= a["hp"] <= a["max_hp"] <= 1000000 and 1 <= a["attack"] <= 1000000
                    and 0 <= a["armor"] <= 1000000 and 0 <= a["regen"] <= 1000000
                    and 0 <= a["step_fp"] <= 2400 and 0 <= a["x_fp"] <= 2400 and 0 <= a["y_fp"] <= 600
                    and a["contact_tick"] >= -1 and a["birth_round"] >= 0
                    and a["movement_ready_round"] >= a["birth_round"] and a["waiting_since_round"] >= 0
                    and a["direction"] == (1 if row["owner"] == 0 else -1)
                    and type(a["waiting"]) is bool and type(a["armor_bypass"]) is bool):
                return False
            if a["waiting"] and a["waiting_since_round"] < 1:
                return False
            for field in ("ranged_next_tick", "melee_next_tick"):
                if field in a and (type(a[field]) is not int or a[field] < 0):
                    return False
            if "rout_round" in a:
                if (type(a["rout_round"]) is not int or a["rout_round"] <= 0 or type(a.get("rout_effect_id")) is not str
                        or not a["rout_effect_id"] or data.get("rout_profile") != ROUT):
                    return False
            elif "rout_effect_id" in a:
                return False
        if not check_duels:
            return True
        used = set()
        duels = data.get("marching_duels", {})
        if type(duels) is not dict:
            return False
        for lane, duel in duels.items():
            if (lane not in LANES or type(duel) is not dict or type(duel.get("id")) is not str or not duel["id"]
                    or type(duel.get("units")) is not list or len(duel["units"]) != 2
                    or type(duel.get("exchanges")) is not list or not 0 < len(duel["exchanges"]) < 64):
                return False
            if any(type(duel.get(k)) is not int or duel[k] < 0 for k in ("round", "tick", "next_tick")):
                return False
            if duel["tick"] >= 200 or duel["next_tick"] != duel["round"] * 200 + duel["tick"] + len(duel["exchanges"]) * 8:
                return False
            for pid, unit in enumerate(duel["units"]):
                if (unit["id"] not in world["entities"]["used_ids"] or unit["owner"] != pid or unit["kind"] != "marcher"
                        or unit["id"] in used or unit["attributes"]["lane"] != lane
                        or entity_id("marcher", unit["origin"], unit["ordinal"]) != unit["id"]
                        or not valid(dict(entities=dict(entities=[unit]), data=dict(rout_profile=ROUT)), False)):
                    return False
                used.add(unit["id"])
            a, b = [row["attributes"] for row in duel["units"]]
            if distance(a["x_fp"], a["y_fp"], b["x_fp"], b["y_fp"]) > CONTACT2:
                return False
            expected = instance_id("spatial_duel", str(duel["round"] * 200 + duel["tick"]), compact([r["id"] for r in duel["units"]]))
            if duel["id"] != expected:
                return False
            for exchange in duel["exchanges"]:
                for key in ("hp", "armor"):
                    if (type(exchange.get(key)) is not list or len(exchange[key]) != 2
                            or any(type(v) is not int or v < 0 for v in exchange[key])):
                        return False
        return True
    except (KeyError, TypeError, ValueError):
        return False


def supported(context):
    world = context["world"]
    if set(world) != {"entities", "data"} or any(r["kind"] != "marcher" for r in world["entities"]["entities"]):
        raise Unsupported("Marching spike requires an isolated Marcher world, not a full game")
    data = world["data"]
    if data.get("kroni_actors") or data.get("kanifous_objects") or "kanifous_profile" in data:
        raise Unsupported("Kroni and Wishmaster actors are not implemented by this spike")
    for row in world["entities"]["entities"]:
        if set(row["attributes"]) & {"blood_wish", "ghost_wishes", "ghost_bypassed"}:
            raise Unsupported("Wishmaster Marcher alterations are outside the spike")


def teams(s, indices):
    result = {lane: [[], []] for lane in LANES}
    for i in indices:
        result[s.lane[i]][s.owner[i]].append(i)
    return result


def grid(indices, xs, ys, shift):
    result = {}
    for i in indices:
        result.setdefault((xs[i] >> shift, ys[i] >> shift), []).append(i)
    return result


def near(x, y, cells, shift):
    cx, cy = x >> shift, y >> shift
    return [i for dx in (-1, 0, 1) for dy in (-1, 0, 1) for i in cells.get((cx + dx, cy + dy), ())]


def busy_ids(duels):
    return {row["id"] for duel in duels.values() for row in duel["units"]}


def duel_alive(s, duel):
    indices = [s.live(row["id"]) for row in duel["units"]]
    for row, i in zip(duel["units"], indices):
        if i is None or s.owner[i] != row["owner"] or s.lane[i] != row["attributes"]["lane"]:
            return False
    i, j = indices
    return distance(s.x_fp[i], s.y_fp[i], s.x_fp[j], s.y_fp[j]) <= CONTACT2


def nearest_target(i, candidates, positions, xs, ys):
    """Exact 2-D nearest, pruning only when horizontal distance proves exclusion.

    Candidate slots are sorted by x; slots themselves retain immutable-ID order.
    Equal distances must still visit both sides and select the smallest slot.
    """
    best, target = (1 << 63) - 1, None
    right = bisect_left(positions, xs[i])
    left, count = right - 1, len(candidates)
    while left >= 0 or right < count:
        lx = xs[i] - positions[left] if left >= 0 else (1 << 63) - 1
        rx = positions[right] - xs[i] if right < count else (1 << 63) - 1
        if lx <= rx:
            dx, j = lx, candidates[left]
            left -= 1
        else:
            dx, j = rx, candidates[right]
            right += 1
        if dx * dx > best:
            break
        gap = dx * dx + (ys[i] - ys[j]) ** 2
        if gap < best or gap == best and (target is None or j < target):
            best, target = gap, j
    return best, target


def move(s, duels, context, clock, modifiers, fields):
    indices = s.active()
    xs, ys = s.x_fp[:], s.y_fp[:]  # One target snapshot; accepted positions stay in columns.
    grouped = teams(s, indices)
    ordered = {lane: [sorted(team, key=xs.__getitem__) for team in grouped[lane]] for lane in LANES}
    positions = {lane: [[xs[j] for j in team] for team in ordered[lane]] for lane in LANES}
    busy, number = busy_ids(duels), context["round"]
    retreat = [value == number for value in s.rout_round]
    nearest, gaps = [None] * len(s.ids), [(1 << 63) - 1] * len(s.ids)
    for i in indices:
        lane, owner = s.lane[i], s.owner[i]
        gaps[i], nearest[i] = nearest_target(i, ordered[lane][1-owner], positions[lane][1-owner], xs, ys)
    accepted = {lane: [grid(team, xs, ys, 7) for team in grouped[lane]] for lane in LANES}
    data = context["world"]["data"]
    gate_queue = data.get("guard_work", {}).get("version") == "U13_GUARD_WORK_V2"
    ranged, collapse = data.get("ranged_profile") == RANGED, data.get("breach_lord") == "Valak"
    for i in indices:
        lane, owner, base = s.lane[i], s.owner[i], s.step_fp[i]
        recovery = s.rout_round[i] == number - 1
        step = (base >> 1) + (base & 1) * (clock & 1) if recovery else base
        percent = modifiers[lane][owner]["speed_percent"]
        web = any(who != owner and distance(xs[i], ys[i], wx, wy) <= radius for who, wx, wy, radius in fields[lane])
        if percent or web or collapse:
            step = speed(base, percent, recovery, clock, web, collapse)
        if not retreat[i] and gaps[i] <= CONTACT2:
            if s.contact_tick[i] < 0:
                s.contact_tick[i] = clock
            continue
        s.contact_tick[i] = -1
        if s.movement_ready_round[i] > number or not retreat[i] and (s.waiting[i] or s.ids[i] in busy):
            continue
        if not retreat[i] and ranged and s.suit[i] == "Vulture" and gaps[i] <= RANGE2:
            continue
        dx, dy = s.direction[i] * step * (-1 if retreat[i] else 1), 0
        j = nearest[i]
        if not retreat[i] and j is not None:
            vx, vy = xs[j] - xs[i], ys[j] - ys[i]
            length = max(1, ceil_sqrt(gaps[i]))
            dx, dy = scaled(vx, step, length), scaled(vy, step, length)
            if dx == dy == 0 and step > 0:
                if abs(vx) >= abs(vy):
                    dx = 1 if vx > 0 else -1
                else:
                    dy = 1 if vy > 0 else -1
        nx, ny = max(0, min(2400, xs[i] + dx)), max(0, min(600, ys[i] + dy))
        allies = accepted[lane][owner]
        def free(px, py):
            for other in near(px, py, allies, 7):
                if other == i:
                    continue
                if gate_queue and s.waiting[other] and s.x_fp[other] == (2400 if owner == 0 else 0):
                    continue
                after = distance(px, py, s.x_fp[other], s.y_fp[other])
                if after < GAP2 and after < distance(xs[i], ys[i], s.x_fp[other], s.y_fp[other]):
                    return False
            return True
        if not free(nx, ny):
            side = 1 if ord(s.ids[i][-1]) % 2 == 0 else -1
            nx, ny = xs[i], max(0, min(600, ys[i] + side * step))
            if not free(nx, ny):
                ny = max(0, min(600, ys[i] - side * step))
                if not free(nx, ny):
                    nx, ny = xs[i], ys[i]
        old_cell, new_cell = (xs[i] >> 7, ys[i] >> 7), (nx >> 7, ny >> 7)
        if old_cell != new_cell:
            allies[old_cell].remove(i)
            allies.setdefault(new_cell, []).append(i)
        s.x_fp[i], s.y_fp[i] = nx, ny


def melee_ready(s, i, clock):
    recovery = s.melee_next_tick[i]
    if recovery is None:
        recovery = s.ranged_next_tick[i] or 0
    return s.suit[i] != "Vulture" or recovery <= clock


def contact(s, lane, context, clock, diagnostic=False):
    grouped = teams(s, s.active())[lane]
    cells = grid(grouped[1], s.x_fp, s.y_fp, 8)
    candidates, earliest = [], (1 << 63) - 1
    ranged = context["world"]["data"].get("ranged_profile") == RANGED
    for i in grouped[0]:
        # Indices are immutable-ID sorted, independently of spatial-grid traversal.
        for j in sorted(near(s.x_fp[i], s.y_fp[i], cells, 8)):
            if ranged and (not melee_ready(s, i, clock) or not melee_ready(s, j, clock)):
                continue
            if distance(s.x_fp[i], s.y_fp[i], s.x_fp[j], s.y_fp[j]) > CONTACT2:
                continue
            arrival = max(clock if s.contact_tick[i] < 0 else s.contact_tick[i],
                          clock if s.contact_tick[j] < 0 else s.contact_tick[j])
            if arrival < earliest:
                earliest, candidates = arrival, [(i, j)]
            elif arrival == earliest:
                candidates.append((i, j))
    key = instance_id("contact_queue", str(clock), lane)
    roll = draw(context["seed"], key, "CONTACT_TIE", 0, len(candidates)) if candidates else None
    pair = candidates[roll] if candidates else ()
    if diagnostic:
        return dict(key=key, purpose="CONTACT_TIE", roll_index=0, bound=len(candidates), value=roll,
                    earliest=None if not candidates else earliest,
                    candidates=[[s.ids[i], s.ids[j]] for i, j in candidates],
                    selected=[s.row(i) for i in pair])
    return pair


def attack(s, i, amount, bypass):
    remaining = max(1, amount)
    if not bypass:
        absorbed = min(s.armor[i], remaining)
        s.armor[i] -= absorbed
        remaining -= absorbed
    s.hp[i] = max(0, s.hp[i] - remaining)
    return remaining


class Phase:
    def __init__(self, context, capture_ticks, reaction, *, keep_background=False):
        self.context = copy_data(context)
        self.w = self.context["world"]
        self.keep_background = keep_background
        self.s = Columns(self.w["entities"], keep_background=keep_background)
        self.number = self.context["round"]
        self.events = []
        self.capture_ticks, self.reaction = capture_ticks, reaction

    def emit(self, kind, data):
        # Events are detached from working columns and future reaction mutations.
        fact = dict(type=kind, text="", data=copy_data(data))
        self.events.append(dict(event=fact, views=[copy_data(fact), copy_data(fact)]))

    def react(self, fact, failure):
        if self.reaction is None:
            return
        result = self.reaction(self.w, copy_data(fact), self.context["seed"], self.context["player_order"][:])
        if type(result) is not dict or result.get("action") != "resolved":
            raise Rejected(failure)
        self.w = copy_data(result["world"])
        self.events.extend(copy_data(result["events"]))

    def restore_reactions(self, failure):
        if self.reaction is None:
            return
        try:
            self.s = Columns(self.w["entities"], keep_background=self.keep_background)
        except ValueError as error:
            raise Rejected("ranged_entities_invalid" if failure.startswith("ranged") else "marching_reaction_entities_invalid") from error

    def interrupt(self, duels, tick):
        for lane in list(duels):
            if not duel_alive(self.s, duels[lane]):
                self.emit("MARCHER_DUEL_INTERRUPTED", dict(event_id=duels[lane]["id"], round=self.number, tick=tick))
                del duels[lane]

    def volley(self, duels, tick):
        s, clock, busy = self.s, self.number * 200 + tick, busy_ids(duels)
        rows, shots = s.active(), []
        for i in rows:
            if (s.suit[i] != "Vulture" or s.ids[i] in busy or s.rout_round[i] == self.number
                    or (s.ranged_next_tick[i] or 0) > clock):
                continue
            best, target = RANGE2 + 1, None
            for j in rows:
                if s.owner[j] == s.owner[i] or s.lane[j] != s.lane[i]:
                    continue
                gap = distance(s.x_fp[i], s.y_fp[i], s.x_fp[j], s.y_fp[j])
                # Native nearest() admits a tie with its initial RANGE2+1
                # sentinel when no target exists yet. Keep that exact edge.
                if gap < best or gap == best and (target is None or s.ids[j] < s.ids[target]):
                    best, target = gap, j
            if target is None or best <= CONTACT2:
                continue
            # One pre-volley snapshot, before any attack cooldown is written.
            shots.append(dict(attacker=s.row(i), target=s.row(target), amount=s.attack[i], index=i))
        for shot in shots:
            i = shot.pop("index")
            s.ranged_next_tick[i], s.melee_next_tick[i] = clock + 32, clock + 8
        deaths = []
        for shot in shots:
            target = s.live(shot["target"]["id"])
            dealt, hp_after = 0, 0
            if target is not None:
                dealt = attack(s, target, shot["amount"], False)
                hp_after = s.hp[target]
                if not hp_after:
                    s.retire(target)
                    deaths.append(dict(attacker=shot["attacker"], victim=s.row(target), damage_dealt=dealt, hp_after=0))
            self.emit("MARCHER_RANGED_ATTACK", dict(round=self.number, tick=tick, lane=shot["attacker"]["attributes"]["lane"],
                      attacker=shot["attacker"], target=shot["target"], damage_dealt=dealt, hp_after=hp_after))
        # Columns already own nonlethal damage/cooldowns. Publish and rebuild
        # only when a death callback can change the registry outside them.
        if self.reaction is not None and deaths:
            self.w["entities"] = s.snapshot()
        for death in deaths:
            death.update(event_id=instance_id("ranged_kill", str(clock), death["victim"]["id"]),
                         round=self.number, tick=tick, hook="marching", cause="combat")
            self.emit("MARCHER_DEFEATED", death)
            self.react(self.events[-1]["event"], "ranged_reaction_invalid")
        if deaths:
            self.restore_reactions("ranged_reaction_invalid")

    def run(self):
        s, data, context = self.s, self.w["data"], self.context
        ranged = data.get("ranged_profile") == RANGED
        if ranged:
            for i in s.active():
                if s.suit[i] == "Vulture":
                    s.step_fp[i], s.armor_bypass[i] = 4, False
        duels = copy_data(data.get("marching_duels", {}))
        start = dict(round=self.number, hook="marching", ticks=200, model=MODEL, units=s.rows())
        if ranged:
            start["ranged_profile"] = RANGED
        self.emit("MARCHING_STARTED", start)
        bases = {row["id"]: row for row in s.rows()}
        modifiers, fields = compile_effects(context.get("persistent_effects", []), self.number, data)
        has_retreat = any(value == self.number for value in s.rout_round)
        orbs = data.get("valak_orbs", [])
        collapse = data.get("breach_lord") == "Valak"
        for tick in range(200):
            s = self.s
            before = (s.x_fp[:], s.y_fp[:], s.active()) if orbs else None
            clock = self.number * 200 + tick
            self.interrupt(duels, tick)
            move(s, duels, context, clock, modifiers, fields)
            if orbs:
                self.w["data"]["neutral_tears"] += gravity(s, orbs, before, self.number, tick, collapse, self.emit)
            if has_retreat or orbs:
                self.interrupt(duels, tick)
            for lane in LANES:
                s = self.s
                if lane not in duels:
                    pair = contact(s, lane, context, clock)
                    if pair:
                        units = [s.row(i) for i in pair]
                        key = instance_id("spatial_duel", str(clock), compact([r["id"] for r in units]))
                        duels[lane] = dict(id=key, units=units, exchanges=[], round=self.number, tick=tick, next_tick=clock)
                        self.emit("MARCHER_CONTACT", dict(event_id=key, round=self.number, tick=tick, lane=lane, units=units))
                if lane not in duels or duels[lane]["next_tick"] > clock:
                    continue
                duel = duels[lane]
                i, j = [s.live(row["id"]) for row in duel["units"]]
                damages = [attack(s, i, s.attack[j], s.armor_bypass[j]), attack(s, j, s.attack[i], s.armor_bypass[i])]
                duel["exchanges"].append(dict(hp=[s.hp[i], s.hp[j]], armor=[s.armor[i], s.armor[j]]))
                duel["next_tick"] = clock + 8
                fallen = [s.hp[i] == 0, s.hp[j] == 0]
                for index in (i, j):
                    if ranged and s.suit[index] == "Vulture":
                        s.melee_next_tick[index] = clock + 8
                        s.ranged_next_tick[index] = max(s.ranged_next_tick[index] or 0, clock + 8)
                    if not s.hp[index]:
                        s.retire(index)
                if not any(fallen):
                    if len(duel["exchanges"]) >= 64:
                        raise Rejected("marching_exchange_limit")
                    continue
                del duels[lane]
                self.emit("MARCHER_CLASH", dict(event_id=duel["id"], round=self.number, hook="marching", tick=duel["tick"],
                          start_round=duel["round"], end_tick=tick, lane=lane,
                          x_fp=(duel["units"][0]["attributes"]["x_fp"] + duel["units"][1]["attributes"]["x_fp"]) >> 1,
                          units=duel["units"], exchanges=duel["exchanges"]))
                if self.reaction is not None:
                    self.w["entities"] = s.snapshot()
                for attacker in context["player_order"]:
                    victim = 1 - attacker
                    if not fallen[victim]:
                        continue
                    self.emit("MARCHER_DEFEATED", dict(event_id=instance_id("kill", duel["id"], str(victim)),
                              round=self.number, hook="marching", tick=tick, victim=duel["units"][victim],
                              attacker=duel["units"][attacker], cause="combat", damage_dealt=damages[victim]))
                    self.react(self.events[-1]["event"], "marching_reaction_invalid")
                self.restore_reactions("marching_reaction_invalid")
            if ranged:
                self.volley(duels, tick)
                self.interrupt(duels, tick)
            s = self.s
            indices, busy = s.active(), busy_ids(duels)
            for i in indices:
                if (s.waiting[i] or has_retreat and s.rout_round[i] == self.number
                        or s.x_fp[i] != (2400 if s.owner[i] == 0 else 0) or s.ids[i] in busy):
                    continue
                if any(s.owner[j] != s.owner[i] and s.lane[j] == s.lane[i]
                       and distance(s.x_fp[i], s.y_fp[i], s.x_fp[j], s.y_fp[j]) <= CONTACT2 for j in indices):
                    continue
                s.waiting[i], s.waiting_since_round[i] = True, self.number
                self.emit("MARCHER_WAITING", dict(entity_id=s.ids[i], round=self.number, hook="marching", tick=tick,
                          lane=s.lane[i], x_fp=s.x_fp[i], y_fp=s.y_fp[i]))
            if self.capture_ticks:
                active = [row["id"] for lane in LANES if lane in duels for row in duels[lane]["units"]]
                self.emit("MARCHING_TICK", dict(round=self.number, tick=tick, unit_format="attribute_delta_v1",
                          units=s.delta_rows(bases), clash=active))
        if "valak_orbs" in self.w["data"]:
            self.w["data"]["valak_orbs"] = orbs
        self.w["entities"] = self.s.snapshot()
        self.w["data"].update(marching_duels=duels, marching_round=self.number)
        self.emit("MARCHING_FINISHED", dict(round=self.number, hook="marching", ticks=200, units=self.s.rows()))
        return dict(action="resolved", world=self.w, events=self.events)


def resolve(context, *, capture_ticks=True, reaction=None):
    supported(context)
    if context.get("hook") != "marching" or not valid(context["world"]):
        return dict(action="invalid", reason="marching_context_invalid")
    if context["world"]["data"].get("marching_round", 0) >= context["round"]:
        return dict(action="invalid", reason="marching_already_applied")
    try:
        try:
            phase = Phase(context, capture_ticks, reaction)
        except ValueError:
            return dict(action="invalid", reason="marching_entities_invalid")
        return phase.run()
    except Rejected as error:
        return dict(action="invalid", reason=str(error))


def regenerate(context):
    supported(context)
    world = copy_data(context["world"])
    if context.get("hook") != "round_start_automatic" or not valid(world):
        return dict(action="invalid", reason="marching_regen_context_invalid")
    number = context["round"]
    if world["data"].get("marching_regen_round", 0) >= number:
        return dict(action="invalid", reason="marching_regen_already_applied")
    modifiers, _ = compile_effects(context.get("persistent_effects", []), number,
                                   dict(lane_aura_profile=world["data"].get("lane_aura_profile")))
    s, events = Columns(world["entities"]), []
    for i in s.active():
        if s.waiting[i]:
            continue
        before = s.hp[i]
        s.hp[i] = min(s.max_hp[i], before + s.regen[i] + modifiers[s.lane[i]][s.owner[i]]["regen_bonus"])
        if before != s.hp[i]:
            fact = dict(type="MARCHER_REGENERATED", text="", data=dict(entity_id=s.ids[i], before=before,
                        after=s.hp[i], round=number, hook=context["hook"]))
            events.append(dict(event=fact, views=[copy_data(fact), copy_data(fact)]))
    world["entities"] = s.snapshot()
    world["data"]["marching_regen_round"] = number
    return dict(action="resolved", world=world, events=events)
