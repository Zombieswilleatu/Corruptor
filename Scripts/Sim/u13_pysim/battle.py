"""Ordinary battle facts and their immediate U13 reactions.

Mutates an owned world inside the caller's transaction. No spatial combat,
active power resolver or expected Godot snapshot is used here.
"""

import math

from . import incoming_damage as incoming
from . import veil
from . import economy as e
from .copying import copy_data
from .development import reconcile
from .primitives import draw, instance_id
from .recruitment import retire

FRACTURE = {"Orias": 0, "Deimos": 0, "Valak": 1, "Kroni": 1, "Kalligan": 1,
            "Gremory": 2, "Odradek": 2, "Kanifous": 1, "Humbaba": 2}


def targetable(row):
    return bool(row and row["kind"] == "castle" and row["attributes"]["status"] in ("standing", "defunct")
                and row["attributes"].get("construction_state", "active") == "active")


def note_loss(row, before, number):
    a = row["attributes"]
    if "construction_state" in a and before >= 7 and a["integrity"] < 7:
        a["repair_lock_until_round"] = max(a.get("repair_lock_until_round", 0), number + 1)


def operational(row):
    # All Structure abilities require the seven-Integrity floor.
    return targetable(row) and row["attributes"]["status"] == "standing" and row["attributes"]["integrity"] >= 7


def threat(row):
    return None if row["attributes"]["lord_id"] == "Humbaba" else row["attributes"].get("threat", 0)


def defense(world, row):
    kind, a = row["attributes"]["lord_id"], row["attributes"]
    if kind == "Kroni":
        return 8 if a["hunger"] >= 3 else 6 if a["hunger"] >= 1 else 4
    if kind == "Humbaba":
        return 2 + sum(targetable(c) and c["owner"] == row["owner"] and c["attributes"]["integrity"] > 0
                       for c in world["entities"]["entities"])
    value = threat(row)
    base = 6 if kind == "Orias" else 5 if kind in ("Odradek", "Valak", "Kanifous") else 4
    return base - (3 if value >= 4 else 2 if value >= 3 else 1 if value >= 2 else 0)


class Battle:
    def __init__(self, world, number, seed, player_order, hook):
        self.w, self.number, self.seed = world, number, seed
        self.order, self.hook = player_order, hook

    def lord(self, pid):
        return e.entity(self.w, self.w["players"][pid]["lord_entity_id"])

    def active(self, pid, kind):
        row = self.lord(pid)
        return row["attributes"]["lord_id"] == kind and row["attributes"]["alive"]

    def fact(self, command):
        """U13BattleEvents.apply subset used by the ordinary resolution slice."""
        w, d = self.w, self.w["data"]
        e.require(type(command.get("command_id")) is str and bool(command["command_id"]), "battle_command_id_required")
        key = instance_id("battle", str(self.number), command["command_id"])
        e.require(key not in d.get("battle_commands", {}), "battle_command_already_applied")
        target = e.entity(w, command.get("target_id", ""))
        details = dict(event_id=key, round=self.number, hook=self.hook)
        kind = command["kind"]
        if kind in ("ruin_castle", "ruin_castle_hazard", "ruin_castle_fracture"):
            e.require(targetable(target), "castle_not_ruinable")
            hazard = kind != "ruin_castle"
            if hazard:
                source = e.entity(w, command.get("source_id", ""))
                fracture = kind == "ruin_castle_fracture"
                scorch = not fracture and command.get("cause") == "scorch"
                e.require((source and source["kind"] == "lord" and source["attributes"]["lord_id"] == "Kalligan" and source["owner"] == 1-target["owner"] if scorch else
                           ((not fracture and veil.source_valid(w, command.get("source_id", ""))) or (source and source["kind"] == "lord" and not source["attributes"]["alive"]
                          and (source["owner"] == target["owner"] if fracture else source["attributes"]["lord_id"] == d["breach_lord"])))
                          and command.get("cause") == ("fracture" if fracture else "breach"))
                          and "player_id" not in command, "castle_hazard_source_invalid")
            else:
                e.require(type(command.get("player_id")) is int and command["player_id"] in (0, 1)
                          and target["owner"] == 1 - command["player_id"], "castle_ruination_attribution_invalid")
            details.update(castle=copy_data(target), player_id=-1 if hazard else command["player_id"],
                           cause=command.get("cause", "siege"), source_id=command.get("source_id", ""))
            target["attributes"].update(integrity=0, status="ruined", artillery_target="")
            if d["construction_targets"][target["owner"]] == target["id"]:
                d["construction_targets"][target["owner"]] = ""
            event_type = "CASTLE_DESTROYED"
        elif kind in ("defeat_guard", "banish_lord"):
            guard = kind == "defeat_guard"
            e.require(target and (target["kind"] == "card" and target["attributes"].get("role") == "guard"
                                  if guard else target["kind"] == "lord"), "guard_missing" if guard else "lord_missing")
            if not guard:
                e.require(target["attributes"]["alive"] and command.get("fracture_target", "") in ("", "subjects", "infrastructure"),
                          "fracture_banishment_invalid")
                details["fracture_target"] = command.get("fracture_target", "")
            if "attacker_id" in command:
                attacker = e.entity(w, command["attacker_id"])
                attack = command.get("attack_kind")
                e.require(attacker and attacker["kind"] == "lord" and attacker["owner"] == 1 - target["owner"]
                          and self.hook == "combat_resolution" and attack in (("Hunt", "Siege") if guard else ("Hunt",))
                          and (not guard or target["attributes"]["lane"] == ("Lord" if attack == "Hunt" else "Castle")),
                          "guard_attack_attribution_invalid" if guard else "banishment_attribution_invalid")
                details.update(attacker=copy_data(attacker), attack_kind=attack)
                if not guard:
                    details["lord"] = copy_data(target)
            if guard:
                details["guard"] = copy_data(target)
                target["attributes"]["role"], target["owner"] = "card", -1
                e.zones(w)["discard"].append(target["id"])
                event_type = "GUARD_DEFEATED"
            else:
                if "threat" in target["attributes"]:
                    target["attributes"]["threat"] = 0
                target["attributes"]["alive"] = False
                details["lord_id"] = target["id"]
                event_type = "LORD_BANISHED"
        elif kind == "change_marcher_allegiance":
            new = command.get("new_owner")
            e.require(self.hook == "post_resolution_allegiance" and self.number >= 1, "allegiance_hook_invalid")
            e.require(type(new) is int and new in (0,1), "allegiance_owner_invalid")
            e.require(target and target["kind"] == "marcher" and target["attributes"]["hp"] > 0, "allegiance_marcher_missing")
            e.require(target["owner"] != new, "allegiance_owner_unchanged")
            before = copy_data(target); interrupted = []
            duels = d.get("marching_duels", {})
            for lane, duel in list(duels.items()):
                if target["id"] not in [u["id"] for u in duel["units"]]: continue
                interrupted.append(duel.get("id", ""))
                for u in duel["units"]:
                    live = e.entity(w,u["id"])
                    if live: live["attributes"]["contact_tick"] = -1
                del duels[lane]
            target["owner"] = new
            target["attributes"].update(direction=1 if new == 0 else -1, waiting=False, waiting_since_round=0, contact_tick=-1)
            details.update(entity_id=target["id"],previous_owner=before["owner"],new_owner=new,before=before,after=copy_data(target),interrupted_duels=interrupted)
            event_type = "MARCHER_ALLEGIANCE_CHANGED"
        elif kind == "set_breach":
            e.require(type(command.get("lord_id")) is str, "breach_lord_invalid")
            d["breach_lord"] = command["lord_id"]
            details["lord_id"] = command["lord_id"]
            if "source_id" in command:
                source = e.entity(w, command["source_id"])
                e.require(source and source["kind"] == "lord" and not source["attributes"]["alive"]
                          and source["attributes"]["lord_id"] == command["lord_id"], "breach_source_invalid")
                details["source_id"] = source["id"]
            event_type = "BREACH_CHANGED"
        elif kind == "marcher_damage":
            e.require(target and target["kind"] == "marcher", "marcher_missing")
            if command.get("cause") == "combat":
                raise e.Unsupported("Marching damage and spatial reactions are not implemented")
            e.require(type(command.get("damage")) is int and command["damage"] >= 0 and command.get("cause") == "hazard", "damage_invalid")
            a = target["attributes"]
            details.update(victim=copy_data(target), attacker=copy_data(e.entity(w, command.get("attacker_id", ""))),
                           cause="hazard", damage_dealt=command["damage"], hp_before=a["hp"], hp_after=max(0, a["hp"] - command["damage"]))
            a["hp"] = details["hp_after"]
            event_type = "MARCHER_DAMAGED" if a["hp"] else "MARCHER_DEFEATED"
            if not a["hp"]:
                retire(w, target["id"])
        else:
            raise e.Unsupported("Battle command outside ordinary resolution: " + str(kind))
        d.setdefault("battle_commands", {})[key] = True
        return e.event(event_type, details)["event"]

    def apply_fact(self, command):
        fact = self.fact(command)
        return [e.event(fact["type"], fact["data"], fact["text"])] + self.react(fact)

    def castle_tear(self):
        d = self.w["data"]
        if d.get("castle_tear_round", 0) == self.number:
            return []
        d["castle_tear_round"] = self.number
        d["neutral_tears"] += 1
        return [e.event("NEUTRAL_TEAR_CREATED", dict(amount=1, source="CastleDestruction", round=self.number))]

    def conduit(self, actor, amount):
        before, events = actor["attributes"].get("threat", 0), []
        after = before + amount
        later = copy_data(actor)
        later["attributes"]["threat"] = after
        circles = sorted((c for c in self.w["entities"]["entities"] if c["owner"] == actor["owner"]
                          and c["attributes"].get("castle_type") == "SummoningCircle" and operational(c)),
                         key=lambda c: c["attributes"]["castle_slot"])
        if amount > 0 and threat(actor) is not None and defense(self.w, later) < defense(self.w, actor) and circles:
            circle = circles[0]
            integrity = circle["attributes"]["integrity"]
            circle["attributes"]["integrity"] -= 3
            note_loss(circle, integrity, self.number)
            after -= 1
            events.append(e.event("BLOOD_CONDUIT", dict(player_id=actor["owner"], lord_id=actor["id"],
                castle_id=circle["id"], round=self.number, integrity_before=integrity,
                integrity_after=circle["attributes"]["integrity"], threat_before=before, threat_after=after, prevented=1),
                "Blood Conduit prevented one Threat."))
        if threat(actor) is not None:
            actor["attributes"]["threat"] = after
        return after, events

    def react(self, fact, *, inner=False):
        w, d, detail = self.w, self.w["data"], fact["data"]
        kind, events = fact["type"], []
        ledger = d.setdefault("gremory_triggers", {})
        def take(key):
            if ledger.get(key, 0) >= self.number:
                return False
            ledger[key] = self.number
            return True
        if kind == "GUARD_DEFEATED" and veil.active(w, "Gremory") and take("GemDagger"):
            for pid in self.order:
                if not veil.affects(w,"Gremory",pid):continue
                drawn = e.draw(w, pid, self.seed, detail["event_id"] + ":gem:" + str(pid))
                events.append(e.event("GEM_DAGGER", drawn, private=pid, redact=("card_id",)))
        for pid in self.order:
            if self.active(pid, "Gremory") and kind == "CASTLE_DESTROYED" and take("Sifting:" + str(pid)):
                drawn = e.draw(w, pid, self.seed, detail["event_id"] + ":sift:" + str(pid), True)
                events.append(e.event("SIFTING_THE_RUINS", drawn))
            if (self.active(pid, "Gremory") and kind == "MARCHER_DEFEATED"
                    and detail.get("cause") == "combat" and detail.get("hook") == "marching"
                    and detail["attacker"]["owner"] == pid
                    and detail["attacker"]["attributes"].get("suit") == "Vulture"
                    and detail["victim"]["owner"] == 1-pid and take("Bones:" + str(pid))):
                drawn = e.draw(w, pid, self.seed, detail["event_id"] + ":bones:" + str(pid))
                d["neutral_tears"] += 1
                events.append(e.event("PICKING_THE_BONES", drawn, private=pid, redact=("card_id",)))
                events.append(e.event("NEUTRAL_TEAR_CREATED", dict(player_id=pid, amount=1, source="PickingTheBones")))
        if kind == "BREACH_CHANGED":
            events.extend(self.sync_breach())
        pid = detail.get("player_id", -1)
        if pid in (0, 1) and self.active(pid, "Deimos"):
            if kind == "SIEGE_STARTED" and d["deimos_fear_round"][pid] < self.number:
                d["deimos_fear_round"][pid] = self.number
                guards = sorted((r for r in w["entities"]["entities"] if r["kind"] == "card" and r["owner"] == 1-pid
                                 and r["attributes"].get("role") == "guard" and r["attributes"]["lane"] == "Castle"),
                                key=lambda r: (r["attributes"]["value"], r["id"]))
                returned = []
                for guard in guards[:1 + self.lord(pid)["attributes"]["threat"]]:
                    a = guard["attributes"]
                    a["role"] = "card"
                    a.pop("slot", None); a.pop("lane", None)
                    e.zones(w)["hands"][guard["owner"]].append(guard["id"])
                    returned.append(guard["id"])
                events.append(e.event("FEAR_AURA", dict(player_id=pid, round=self.number, returned_ids=returned,
                                                        threat=self.lord(pid)["attributes"]["threat"])))
            if kind == "CASTLE_DESTROYED" and detail["castle"]["owner"] == 1-pid and detail["event_id"] not in d["deimos_spoils_events"]:
                first = d["deimos_spoils"][pid] == 0
                d["deimos_spoils_events"][detail["event_id"]] = pid
                d["deimos_spoils"][pid] += 1
                if first: w["players"][pid]["resources"]["personal_tears"] += 1
                else: d["neutral_tears"] += 1
                events.append(e.event("PERSONAL_TEAR_CREATED" if first else "NEUTRAL_TEAR_CREATED",
                                      dict(player_id=pid, round=self.number, amount=1, source="SpoilsOfWar")))
        if kind == "BREACH_CHANGED" and detail["lord_id"] == "Humbaba":
            key = detail["event_id"]
            if key not in d["humbaba_breach_entries"]:
                source = e.entity(w, detail.get("source_id", ""))
                e.require(source and not source["attributes"]["alive"] and source["attributes"]["lord_id"] == "Humbaba", "stones_forget_source_missing")
                d["humbaba_breach_entries"][key] = self.number
                targets = sorted(c["id"] for c in w["entities"]["entities"] if targetable(c) and c["attributes"]["integrity"] > 0)
                for identity in targets:
                    events.extend(self.breach_damage(identity, source["id"], key))
                events.append(e.event("THE_STONES_FORGET", dict(source_id=source["id"], entry_id=key,
                                      round=self.number, castle_ids=targets, damage_per_castle=4)))
        if inner:
            return events
        if kind == "GUARD_DEFEATED" and "attacker" in detail:
            pid = detail["attacker"]["owner"]
            guard = detail["guard"]
            if guard["attributes"]["lane"] == "Lord" and self.active(pid, "Orias"):
                key = instance_id("battle", str(self.number), f"hunt:{pid}:guard:{guard['id']}")
                e.require(detail.get("attack_kind") == "Hunt" and self.hook == "combat_resolution"
                          and detail["event_id"] == key and key in d["battle_commands"], "accelerate_requires_credited_guard_fact")
                spent, target = d["orias_accelerate"][pid], self.lord(guard["owner"])
                before = threat(target)
                if (spent is None or spent["round"] < self.number) and before is not None:
                    e.require(before < 1000000, "accelerate_threat_limit")
                    after, gained = self.conduit(target, 1)
                    events.extend(gained)
                    d["orias_accelerate"][pid] = dict(round=self.number, event_id=key, guard_id=guard["id"])
                    events.append(e.event("ACCELERATE", dict(player_id=pid, lord_id=target["id"], guard_id=guard["id"],
                        event_id=key, round=self.number, hook=self.hook, threat_before=before, threat_after=after)))
            if self.active(pid, "Valak") and self.hook == "combat_resolution" and detail.get("attack_kind") in ("Hunt", "Siege"):
                resources, reserved = w["players"][pid]["resources"], d["valak_reserved"][pid]
                before = resources["life_essence"]
                after = min(5-reserved, before+2)
                resources["life_essence"] = after
                events.append(e.event("VALAK_ESSENCE_GAINED", dict(player_id=pid, guard=guard, before=before+reserved,
                                      after=after+reserved, gained=after-before, round=self.number)))
        if kind == "LORD_BANISHED":
            attacker, victim = detail.get("attacker", {}), detail.get("lord", {})
            if attacker and victim and attacker["attributes"]["lord_id"] == "Orias" and attacker["attributes"]["alive"] and threat(victim) is not None and threat(victim) >= 3:
                pid, key = attacker["owner"], detail["event_id"]
                expected = instance_id("battle", str(self.number), f"hunt:{pid}:lord:{victim['id']}")
                e.require(key == expected and self.hook == "combat_resolution" and detail.get("attack_kind") == "Hunt", "mark_requires_credited_banishment")
                prior = d["orias_marks"][victim["owner"]]
                if prior is None or prior["event_id"] != key:
                    d["orias_marks"][victim["owner"]] = dict(lord_id=victim["id"], marked_by=attacker["id"], round=self.number, event_id=key)
                    w["players"][pid]["resources"]["souls"] += 2
                    d["neutral_tears"] += 1
                    events.extend([e.event("ORIAS_MARKED", dict(player_id=pid, lord_id=victim["id"], threat=threat(victim), bonus_souls=2, round=self.number, event_id=key)),
                                   e.event("NEUTRAL_TEAR_CREATED", dict(amount=1, source="TheMark", round=self.number))])
            target = e.entity(w, detail["lord_id"])
            if target["attributes"]["lord_id"] == "Odradek":
                pid = target["owner"]
                before = w["players"][pid]["resources"]["reconfiguration"]
                w["players"][pid]["resources"]["reconfiguration"] = 0
                events.append(e.event("RECONFIGURATION_RESET", dict(player_id=pid, before=before, after=0, event_id=detail["event_id"])))
        if kind == "MARCHER_DEFEATED" and detail.get("cause") == "combat" and detail.get("hook") == "marching":
            victim, attacker = detail.get("victim",{}), detail.get("attacker",{})
            pid = victim.get("owner",-1)
            if (victim.get("kind") == "marcher" and attacker.get("kind") == "marcher" and pid in (0,1)
                    and attacker.get("owner") == 1-pid and self.active(pid,"Odradek") and d["interlock_rounds"][pid] < self.number):
                damage = detail.get("damage_dealt")
                e.require(type(damage) is int and damage >= 1,"interlock_killing_damage_missing")
                d["interlock_rounds"][pid] = self.number
                target = e.entity(w,attacker["id"])
                from .powers import odradek_event
                events.append(odradek_event("PSYCHIC_INTERLOCK",dict(player_id=pid,round=self.number,hook=self.hook,trigger_id=detail["event_id"],target_id=attacker["id"],damage=damage,target_alive=bool(target))))
                if target:
                    amount = incoming.amount(target["attributes"],damage,self.number*200+detail.get("tick",0))
                    absorbed = min(target["attributes"]["armor"],amount);target["attributes"]["armor"] -= absorbed
                    hit = self.fact(dict(command_id=instance_id("interlock",detail["event_id"],str(pid)),kind="marcher_damage",target_id=target["id"],damage=amount-absorbed,cause="hazard"))
                    events.append(e.event(hit["type"],hit["data"]));events.extend(self.react(hit,inner=True))
        from .wishmaster import record_losses
        record_losses(w, [dict(event=fact)])
        from .monster_effects import deaths
        events.extend(deaths(w, self.number))
        reconcile(w)
        events.extend(self.sync_breach())
        if kind == "LORD_BANISHED":
            throne = d["vacant_throne"]
            e.require(throne["round"] == self.number and throne["completed_round"] == self.number-1, "vacant_throne_banishment_clock_invalid")
            throne["present"][e.entity(w, detail["lord_id"])["owner"]] = True
            events.extend(self.fracture(detail))
            reconcile(w)
        return events

    def sync_breach(self):
        w, events = self.w, []
        for row in w["entities"]["entities"]:
            if row["kind"] != "castle": continue
            a = row["attributes"]
            ceiling = a["base_max_integrity"] - (5 if veil.affects(w, "Deimos", row["owner"]) else 0)
            if a["max_integrity"] == ceiling: continue
            a["max_integrity"], a["integrity"] = ceiling, min(a["integrity"], ceiling)
            if a["construction_state"] == "building" and a["integrity"] == ceiling:
                a["construction_state"] = "active"
                if w["data"]["construction_targets"][row["owner"]] == row["id"]:
                    w["data"]["construction_targets"][row["owner"]] = ""
                events.append(e.event("CASTLE_ACTIVATED", dict(player_id=row["owner"], castle_id=row["id"], before=a["integrity"],
                                      after=a["integrity"], automatic=True, reason="construction_reached_changed_ceiling")))
            events.append(e.event("CASTLE_CEILING_CHANGED", dict(castle_id=row["id"], max_integrity=ceiling, integrity=a["integrity"])))
        return events

    def breach_damage(self, identity, source, entry, damage=4, cause="breach", inner=False):
        row, events = e.entity(self.w, identity), []
        if not targetable(row) or row["attributes"]["integrity"] <= 0: return events
        before = row["attributes"]["integrity"]
        dealt = min(before, damage)
        if dealt == before:
            fact = self.fact(dict(command_id=instance_id(cause+"_damage", entry, identity), kind="ruin_castle_hazard",
                                  target_id=identity, source_id=source, cause=cause))
            events.append(e.event(fact["type"], fact["data"]))
            events.extend(self.castle_tear())
            events.extend(self.react(fact, inner=inner))
        else:
            row["attributes"]["integrity"] -= dealt
            note_loss(row, before, self.number)
        events.append(e.event("CASTLE_DAMAGED", dict(castle_id=identity, source_id=source, source="Scorch" if cause=="scorch" else "TheStonesForget",
                              cause=cause, round=self.number, damage=dealt, integrity=before-dealt, destroyed=dealt==before)))
        return events

    def fracture_groups(self, pid):
        groups = {}
        for name in ("Lord", "Castle", "Marcher"):
            rows = [r for r in self.w["entities"]["entities"] if r["owner"] == pid and
                    ((r["kind"] == "marcher" and r["attributes"]["hp"] > 0) if name == "Marcher" else
                     (r["kind"] == "card" and r["attributes"].get("role") == "guard" and
                      r["attributes"]["lane"] == name and r["attributes"]["value"] > 1))]
            if rows: groups[name] = sorted(rows, key=lambda r: r["id"])
        return groups

    def fracture_castles(self, pid):
        return sorted((r for r in self.w["entities"]["entities"] if r["owner"] == pid and targetable(r) and r["attributes"]["integrity"] > 0),
                      key=lambda r: (-r["attributes"]["integrity"], r["attributes"]["castle_slot"]))

    def fracture(self, detail):
        w, d, key = self.w, self.w["data"], detail["event_id"]
        lord = e.entity(w, detail["lord_id"])
        e.require(key not in d["fracture_events"] and not lord["attributes"]["alive"], "fracture_banishment_invalid")
        pid, value, category = lord["owner"], FRACTURE[lord["attributes"]["lord_id"]], detail.get("fracture_target", "")
        if not category:
            groups = self.fracture_groups(pid)
            capacity = sum(min(3, len(rows)) if name == "Marcher" else max(min(2, r["attributes"]["value"]-1) for r in rows)
                           for name, rows in groups.items())
            # Godot round is half away from zero; Python round ties to even.
            score = math.floor(capacity * value / len(groups) + 0.5) if groups else 0
            infrastructure = sum(r["attributes"]["integrity"] for r in self.fracture_castles(pid))
            category = "infrastructure" if min(value*2, infrastructure) > score else "subjects"
        d["fracture_events"][key] = dict(player_id=pid, category=category, value=value)
        events, used = [], []
        for point in range(value):
            group, targets = "infrastructure", []
            if category == "infrastructure":
                candidates = [r for r in self.fracture_castles(pid) if r["id"] not in used]
                if not candidates:
                    used.clear(); candidates = self.fracture_castles(pid)
                if not candidates: break
                targets = [candidates[0]]; used.append(candidates[0]["id"])
            else:
                groups = self.fracture_groups(pid)
                if not groups: break
                group = list(groups)[draw(self.seed, key, "U13_FRACTURE_V1:group", point, len(groups))]
                available = groups[group][:]
                for hit in range(min(3 if group == "Marcher" else 1, len(available))):
                    targets.append(available.pop(draw(self.seed, key, "U13_FRACTURE_V1:victim:"+str(hit), point, len(available))))
            for row in targets:
                field = "hp" if group == "Marcher" else "integrity" if group == "infrastructure" else "value"
                before = row["attributes"][field]
                after = max(0 if group in ("Marcher", "infrastructure") else 1, before-(1 if group == "Marcher" else 2))
                command = dict(command_id=f"{key}:fracture:{point}:{row['id']}", target_id=row["id"])
                if group == "Marcher":
                    amount = incoming.amount(row["attributes"],1,incoming.phase_clock(w,self.number))
                    after = max(0, before-amount)
                    command.update(kind="marcher_damage", damage=amount, cause="hazard")
                elif group == "infrastructure" and after == 0: command.update(kind="ruin_castle_fracture", source_id=lord["id"], cause="fracture")
                else:
                    row["attributes"][field] = after
                    if group == "infrastructure": note_loss(row, before, self.number)
                    command = {}
                events.append(e.event("FRACTURE_HIT", dict(event_id=key, round=self.number, point=point, category=category,
                                      group=group, target_id=row["id"], player_id=pid, before=before, after=after)))
                if command: events.extend(self.apply_fact(command))
        events.append(e.event("FRACTURE_RESOLVED", dict(event_id=key, round=self.number, player_id=pid, lord_id=lord["id"], value=value, category=category)))
        return events
