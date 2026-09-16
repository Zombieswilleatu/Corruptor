"""Fresh-game parity through ordinary combat; stops before post-resolution.

Authority: U13GameContent's hook composition, U13Structures, U13Combat, Sigils,
CastleDefenses and GuardWork. Decisions remain explicit, independent of policy.
"""

import json

from . import economy as e, recruitment as recruits
from .battle import Battle, targetable, operational, note_loss, threat, defense
from .copying import copy_data
from .development import DevelopmentMatch, reconcile
from .primitives import draw, instance_id

VERSION = "U13_PYSIM_RESOLUTION_V1"
HOOKS = ("post_repair_artillery", "commitment_reveal", "combat_resolution")


def combat_order(order):
    return {k: copy_data(v) for k, v in order.items() if k not in ("guard_moves", "castle_action", "rites", "summon")}


class Ordinary(Battle):
    def run(self, orders):
        if self.hook not in HOOKS:
            raise e.Unsupported("Ordinary resolution hook not implemented: " + self.hook)
        w, d = self.w, self.w["data"]
        before_defunct = [c["id"] for c in w["entities"]["entities"] if targetable(c)
                          and c["attributes"]["status"] == "defunct" and w["players"][c["owner"]]["lord_id"] == "Kalligan"]
        self.kroni_orders = [{k: v for k, v in order.items() if k not in ("rites", "guard_moves", "summon")} for order in orders]
        self.orders = [combat_order(order) for order in orders]
        if self.hook == HOOKS[0]: events = self.artillery()
        elif self.hook == HOOKS[1]: events = self.reveal()
        else: events = self.combat()
        # Kalligan wrapper observes before/after every ordinary hook.
        eligible = d["rekindle_defunct_ids"]
        for identity in before_defunct:
            if identity not in eligible: eligible.append(identity)
        eligible.sort()
        for identity in eligible[:]:
            row = e.entity(w, identity)
            if not targetable(row): eligible.remove(identity); continue
            if not operational(row): continue
            eligible.remove(identity)
            pid = row["owner"]
            if self.lord(pid)["attributes"]["alive"] and d["rekindle_rounds"][pid] < self.number:
                d["rekindle_rounds"][pid] = self.number
                d["neutral_tears"] += 1
                events.append(e.event("NEUTRAL_TEAR_CREATED", dict(source="Rekindle", amount=1,
                                      player_id=pid, castle_id=identity, round=self.number)))
        reconcile(w)
        events.extend(self.clear_sigils())
        for pid in (0, 1):
            if self.lord(pid)["attributes"]["alive"]: d["vacant_throne"]["present"][pid] = True
        return events

    def artillery(self):
        d, events = self.w["data"], []
        e.require(d.get("artillery_round", 0) < self.number, "artillery_already_fired")
        for pid in self.order:
            engines = sorted(c["id"] for c in self.w["entities"]["entities"] if c["kind"] == "castle"
                             and c["owner"] == pid and c["attributes"]["combat_profile"] == "siege_engine")
            for identity in engines: events.extend(self.fire(identity))
        d["artillery_round"] = self.number
        return events

    def fire(self, identity, shot="normal"):
        w, events = self.w, []
        engine = e.entity(w, identity)
        e.require(engine and engine["kind"] == "castle" and engine["attributes"]["combat_profile"] == "siege_engine", "artillery_engine_missing")
        if not operational(engine): return events
        a = engine["attributes"]
        target = e.entity(w, a["artillery_target"])
        if not targetable(target):
            targets = sorted(c["id"] for c in w["entities"]["entities"] if c["owner"] == 1-engine["owner"] and targetable(c))
            if not targets:
                a["artillery_target"] = ""
                return [e.event("ARTILLERY_NO_TARGET", dict(engine_id=identity, round=self.number, shot=shot))]
            target = e.entity(w, targets[draw(self.seed, identity, "ARTILLERY_TARGET", a["artillery_acquisitions"], len(targets))])
            a["artillery_target"] = target["id"]
            a["artillery_acquisitions"] += 1
            events.append(e.event("ARTILLERY_TARGET_ACQUIRED", dict(engine_id=identity, target_id=target["id"], round=self.number)))
        target_before = copy_data(target["attributes"])
        before = target_before["integrity"]
        damage = min(before, 2)
        if before <= 2:
            fact = self.fact(dict(command_id=instance_id("artillery", identity, shot), kind="ruin_castle",
                                  target_id=target["id"], player_id=engine["owner"], source_id=identity, cause="artillery"))
            w["players"][engine["owner"]]["resources"]["souls"] += 2
            events.append(e.event(fact["type"], fact["data"]))
            events.extend(self.castle_tear())
            events.extend(self.react(fact))
        else:
            target["attributes"]["integrity"] -= damage
            note_loss(target, before, self.number)
        events.append(e.event("ARTILLERY_FIRED", dict(round=self.number, player_id=engine["owner"], engine_id=identity,
            target_id=target["id"], shot=shot, damage=damage, destroyed=before<=2, soul_gain=2 if before<=2 else 0,
            target_before=target_before, target_after=target["attributes"])))
        return events

    def castleless(self, pid):
        return not any(c["owner"] == pid and targetable(c) for c in self.w["entities"]["entities"])

    def clear_sigils(self):
        events = []
        for pid in (0, 1):
            if self.castleless(pid) and self.w["data"]["sigils"][pid]["Castle"]:
                self.w["data"]["sigils"][pid]["Castle"] = ""
                events.append(e.event("SIGIL_REMOVED", dict(player_id=pid, round=self.number, lane="Castle", reason="no_active_castles")))
        return events

    def reveal(self):
        w, d, events = self.w, self.w["data"], []
        lifecycle = d["sigil_lifecycle"]
        e.require(lifecycle["created_round"] == self.number-1 and lifecycle["aged_round"] == self.number, "sigil_creation_clock_invalid")
        for pid in (0, 1):
            order = self.orders[pid]
            if order.get("action") != "Ward": continue
            lane = order["lane"]
            if lane == "Castle" and self.castleless(pid): continue
            before = d["sigils"][pid][lane]
            d["sigils"][pid][lane] = "fresh"
            actor = self.lord(pid)
            prior = threat(actor)
            after = prior
            if lane == "Lord" and prior is not None:
                after = max(0, prior-1)
                actor["attributes"]["threat"] = after
            events.append(e.event("SIGIL_CREATED", dict(player_id=pid, lane=lane, round=self.number, before=before,
                                  after="fresh", state_label="fresh", threat_before=prior, threat_after=after), "Sigil fresh."))
        lifecycle["created_round"] = self.number
        e.require(d.get("combat_reveal_round", 0) < self.number, "combat_already_revealed")
        for pid in self.order:
            order = self.orders[pid]
            if not order: continue
            cards = [e.entity(w, identity) for identity in order["card_ids"]]
            e.require(all(cards), "combat_cards_unavailable")
            events.append(e.event("COMBAT_ORDER_REVEALED", dict(player_id=pid, round=self.number, order=order, cards=cards)))
            for suit in recruits.SUITS:
                count = sum(c["attributes"]["value"] for c in cards if c["attributes"]["suit"] == suit) // (2 if order["action"] == "Ward" else 3)
                origin = instance_id("commitment", f"{self.number}:{pid}", suit)
                for ordinal in range(count):
                    row = recruits.create(w, origin, ordinal, pid, recruits.profile(suit, order["lane"], pid, self.number, self.number+1))
                    recruits.place_spawn(w, row, self.seed)
                    events.append(e.event("MARCHER_SPAWNED", row))
        d["combat_reveal_round"] = self.number
        return events

    def strength(self, ids, exempt):
        return sum(c["attributes"]["value"] if c["attributes"]["suit"] == exempt else max(1, c["attributes"]["value"]-1)
                   for c in (e.entity(self.w, identity) for identity in ids))

    def pairs(self, pid, lane):
        reconcile(self.w)
        events, screen = [], 0
        # Godot captures this pair list before reactions return replacement worlds.
        for pair in copy_data(self.w["data"]["guard_work"]["pairs"]):
            if not pair["active"] or pair["player_id"] != pid or pair["lane"] != lane: continue
            if pair["suit"] == "Penitent":
                screen += 5
                events.append(e.event("GUARD_PAIR_SCREEN", dict(player_id=pid, round=self.number, lane=lane, amount=5)))
            elif pair["suit"] == "Butcher":
                targets = sorted((r for r in self.w["entities"]["entities"] if r["kind"] == "marcher" and r["owner"] == 1-pid
                                  and r["attributes"]["lane"] == lane), key=lambda r: r["id"])
                if not targets: continue
                key = instance_id("butcher_guard", str(self.number)+lane, json.dumps(pair["ids"], ensure_ascii=False, separators=(",", ":")))
                target = targets[draw(self.seed, key, "victim", 0, len(targets))]
                fact = self.fact(dict(kind="marcher_damage", command_id=key, target_id=target["id"], damage=target["attributes"]["hp"], cause="hazard"))
                events.append(e.event("GUARD_PAIR_STRIKE", dict(player_id=pid, round=self.number, lane=lane, target_id=target["id"])))
                events.append(e.event(fact["type"], fact["data"]))
                events.extend(self.react(fact))
        return screen, events

    def attack_layers(self, pid, order, target_id, pursuit=0):
        lane, action = order["lane"], order["action"]
        strength = self.strength(order["card_ids"], "Butcher") + pursuit
        waiters = [r["id"] for r in self.w["entities"]["entities"] if r["kind"] == "marcher" and r["owner"] == pid
                   and r["attributes"]["lane"] == lane and r["attributes"]["waiting"]]
        for identity in waiters: recruits.retire(self.w, identity)
        strength += len(waiters)
        details = dict(player_id=pid, round=self.number, target_id=target_id, strength=strength, waiters_consumed=waiters)
        if action == "Hunt": details["relentless_pursuit"] = pursuit
        started = e.event(action.upper()+"_STARTED", details)
        events = [started] + self.react(started["event"])
        ward, screen = self.orders[1-pid], 0
        if ward.get("action") == "Ward":
            screen = self.strength(ward["card_ids"], "Penitent")
            if ward["lane"] != lane: screen >>= 1
        pair_screen, pair_events = self.pairs(1-pid, lane)
        remaining = max(0, max(0, strength-screen)-pair_screen)
        events.extend(pair_events)
        if lane == "Lord" and self.active(1-pid, "Valak"):
            resources = self.w["players"][1-pid]["resources"]
            before = resources["life_essence"]
            spent = min(before, remaining)
            resources["life_essence"] -= spent
            remaining -= spent
            if spent:
                reserved = self.w["data"]["valak_reserved"][1-pid]
                events.append(e.event("VALAK_ESSENCE_REINFORCED", dict(player_id=1-pid, zone="Lord", spent=spent,
                                      before=before+reserved, after=before-spent+reserved, round=self.number)))
        guards = sorted((copy_data(r) for r in self.w["entities"]["entities"] if r["kind"] == "card" and r["owner"] == 1-pid
                         and r["attributes"].get("role") == "guard" and r["attributes"]["lane"] == lane),
                        key=lambda r: (-r["attributes"]["value"], r["attributes"]["slot"]))
        lost = 0
        for guard in guards:
            if remaining <= guard["attributes"]["value"]:
                remaining = 0; break
            remaining -= guard["attributes"]["value"]
            events.extend(self.apply_fact(dict(command_id=f"{action.lower()}:{pid}:guard:{guard['id']}", kind="defeat_guard",
                          target_id=guard["id"], attacker_id=self.lord(pid)["id"], attack_kind=action)))
            lost += 1
        return strength, screen, remaining, lost, events

    def sigil(self, pid, lane, remaining):
        sigil, broken = self.w["data"]["sigils"][pid][lane], False
        if remaining > 0 and sigil:
            value = 2 if sigil == "fresh" else 1
            if remaining > value:
                remaining -= value
                self.w["data"]["sigils"][pid][lane] = ""
                broken = True
            else: remaining = 0
        return remaining, sigil, broken

    def screen_castle(self, pid, kind):
        castles = sorted((c for c in self.w["entities"]["entities"] if c["owner"] == pid and targetable(c)
                          and c["attributes"]["castle_type"] == kind), key=lambda c: c["attributes"]["castle_slot"])
        return castles[0] if castles else {}

    def siege_castle(self, pid, identity, remaining, lost):
        target, events = e.entity(self.w, identity), []
        before = target["attributes"]["integrity"]
        damage = min(before, remaining)
        destroyed = damage == before and remaining > 0
        if destroyed:
            self.w["players"][pid]["resources"]["souls"] += 3 if lost > 0 else 2
            events.extend(self.castle_tear())
            events.extend(self.apply_fact(dict(command_id=f"siege:{pid}:castle:{identity}", kind="ruin_castle", target_id=identity, player_id=pid)))
        else:
            target["attributes"]["integrity"] = before-damage
            note_loss(target, before, self.number)
            if before == damage: target["attributes"]["status"] = "defunct"
        return dict(integrity_before=before, damage=damage, destroyed=destroyed, overflow=max(0, remaining-damage)), events

    def plunder_record(self, pid, action, identity, success):
        self.w["data"]["plunder"]["results"][pid] = dict(action=action, round=self.number, target_id=identity,
            success=success, soul_gain=1 if action == "Pillage" and success else 0, tear_gain=1 if action == "Profane" and success else 0)

    def siege(self, pid, order):
        target, events = e.entity(self.w, order["target_id"]), []
        pillage = self.castleless(1-pid)
        if not pillage and order["target_id"] == f"castle_zone:{1-pid}":
            target = min((c for c in self.w["entities"]["entities"] if c["owner"] == 1-pid and targetable(c)),
                         key=lambda c: c["attributes"]["castle_slot"])
            order = dict(order, target_id=target["id"])
            events.append(e.event("PILLAGE_RETARGETED", dict(player_id=pid, round=self.number, castle_id=target["id"])))
        if not pillage and not targetable(target):
            return events + [e.event("COMBAT_ORDER_FIZZLED", dict(player_id=pid, round=self.number, target_id=order["target_id"]))]
        strength, screen, remaining, lost, attacks = self.attack_layers(pid, order, order["target_id"])
        events.extend(attacks)
        if pillage:
            success = remaining > 0
            self.w["players"][pid]["resources"]["souls"] += int(success)
            self.plunder_record(pid, "Pillage", order["target_id"], success)
            events.extend(self.clear_sigils())
            return events + [e.event("SIEGE_RESOLVED", dict(player_id=pid, round=self.number, target_id=order["target_id"],
                pillage=True, pillage_success=success, strength=strength, ward_screen=screen, guards_defeated=lost,
                sigil_broken=False, integrity_before=0, damage=0, destroyed=False, soul_gain=int(success), neutral_tear_gain=0, personal_tear_gain=0))]
        remaining, sigil, broken = self.sigil(1-pid, "Castle", remaining)
        bastion = self.screen_castle(1-pid, "Bastion") if target["attributes"]["castle_type"] != "Bastion" else {}
        if remaining > 0 and bastion:
            hit, facts = self.siege_castle(pid, bastion["id"], remaining, lost)
            events.extend(facts)
            remaining = hit["overflow"]
            events.append(e.event("BASTION_SCREENED", dict(player_id=1-pid, round=self.number, castle_id=bastion["id"],
                target_id=target["id"], damage=hit["damage"], destroyed=hit["destroyed"], overflow=remaining)))
        hit, facts = self.siege_castle(pid, target["id"], remaining, lost)
        events.extend(facts)
        if not hit["destroyed"] and broken and sigil == "fresh": self.w["players"][1-pid]["resources"]["souls"] += 1
        events.append(e.event("SIEGE_RESOLVED", dict(player_id=pid, round=self.number, target_id=target["id"], strength=strength,
            ward_screen=screen, guards_defeated=lost, sigil_broken=broken, integrity_before=hit["integrity_before"], damage=hit["damage"], destroyed=hit["destroyed"])))
        return events

    def hunt(self, pid, order):
        target = e.entity(self.w, order["target_id"])
        if not target or not target["attributes"]["alive"]:
            return [e.event("COMBAT_ORDER_FIZZLED", dict(player_id=pid, round=self.number, target_id=order["target_id"], reason="lord_banished"))]
        pursuit = (1 + int(threat(target) is not None and threat(target) >= 2)) if self.active(pid, "Orias") else 0
        strength, screen, remaining, lost, events = self.attack_layers(pid, order, target["id"], pursuit)
        remaining, sigil, broken = self.sigil(1-pid, "Lord", remaining)
        keep = self.screen_castle(1-pid, "Keep")
        if keep and remaining > 0:
            before = keep["attributes"]["integrity"]
            reduction = min(remaining, 3) if operational(keep) else 0
            remaining = max(0, remaining-reduction)
            damage = min(before, remaining)
            ruined = remaining > 0 and remaining >= before
            if ruined:
                events.extend(self.apply_fact(dict(command_id=f"hunt:{pid}:keep:{keep['id']}", kind="ruin_castle",
                    target_id=keep["id"], player_id=pid, cause="hunt")))
            else:
                keep["attributes"]["integrity"] -= damage
                note_loss(keep, before, self.number)
            remaining -= damage
            events.append(e.event("KEEP_INTERPOSED", dict(player_id=1-pid, round=self.number, castle_id=keep["id"],
                integrity_before=before, damage=damage, reduction=reduction, destroyed=ruined, overflow=remaining)))
        lord_defense = defense(self.w, target)
        banished = remaining > lord_defense
        if banished:
            self.w["players"][pid]["resources"]["souls"] += 2
            other = self.w["players"][1-pid]["resources"]
            other["souls"] = max(0, other["souls"]-1)
            self.w["data"]["neutral_tears"] += 1
            events.append(e.event("NEUTRAL_TEAR_CREATED", dict(amount=1, source="LordBanishment", round=self.number)))
            command = dict(command_id=f"hunt:{pid}:lord:{target['id']}", kind="banish_lord", target_id=target["id"],
                           attacker_id=self.lord(pid)["id"], attack_kind="Hunt")
            if "fracture_target" in order: command["fracture_target"] = order["fracture_target"]
            events.extend(self.apply_fact(command))
            events.extend(self.apply_fact(dict(command_id=f"hunt:{pid}:breach:{target['id']}", kind="set_breach",
                lord_id=self.w["players"][1-pid]["lord_id"], source_id=target["id"])))
            if "threat" in target["attributes"]: target["attributes"]["threat"] = 0
        elif broken and sigil == "fresh": self.w["players"][1-pid]["resources"]["souls"] += 1
        events.append(e.event("HUNT_RESOLVED", dict(player_id=pid, round=self.number, target_id=target["id"], strength=strength,
            ward_screen=screen, guards_defeated=lost, sigil_broken=broken, lord_defense=lord_defense, banished=banished, relentless_pursuit=pursuit)))
        return events

    def combat(self):
        w, d, events = self.w, self.w["data"], []
        e.require(d["kroni_action_round"] < self.number, "kroni_action_already_applied")
        d["kroni_action_round"] = self.number
        for pid in self.order:
            order = self.kroni_orders[pid]
            if self.active(pid, "Kroni") and (not order or order.get("action") == "Ward"):
                a = self.lord(pid)["attributes"]
                before, cause = a["hunger"], "Ward" if order else "Pass"
                a["hunger"] = max(0, before-1)
                events.append(e.event("KRONI_HUNGER_CHANGED", dict(player_id=pid, before=before, after=a["hunger"], round=self.number, cause=cause),
                                      f"{cause}: Hunger {before} → {a['hunger']}."))
        e.require(d.get("combat_resolved_round", 0) < self.number, "combat_already_resolved")
        e.require(d["plunder"]["resolved_round"] == self.number-1, "plunder_resolution_clock_invalid")
        d["plunder"].update(results=[None, None], resolved_round=self.number)
        for pid in self.order:
            order = self.orders[pid]
            if order.get("action") == "Siege": events.extend(self.siege(pid, order))
            elif order.get("action") == "Hunt": events.extend(self.hunt(pid, order))
            elif order.get("action") == "Profane":
                target = e.entity(w, order["target_id"])
                success = bool(targetable(target) and target["owner"] == pid and target["attributes"]["status"] == "standing"
                               and target["attributes"]["integrity"] == target["attributes"]["max_integrity"])
                if success: target["attributes"].update(integrity=0, status="profaned", artillery_target="")
                self.plunder_record(pid, "Profane", order["target_id"], success)
                events.append(e.event("PROFANE_RESOLVED", dict(player_id=pid, round=self.number, target_id=order["target_id"],
                    profaned=success, tear_pending=success, reason="" if success else "target_no_longer_eligible")))
        for pid, result in enumerate(d["plunder"]["results"]):
            if result and result["tear_gain"] == 1:
                w["players"][pid]["resources"]["personal_tears"] += 1
                veil = d["neutral_tears"] + sum(p["resources"]["personal_tears"] for p in w["players"])
                events.append(e.event("PERSONAL_TEAR_CREATED", dict(player_id=pid, round=self.number, source="Profane",
                                      castle_id=result["target_id"], amount=1, veil_after=veil)))
        events.extend(self.clear_sigils())
        d["combat_resolved_round"] = self.number
        return events


def resolve(raw, number, seed, player_order, hook, orders):
    """Pure component API; rejection restores every field, including earlier events."""
    w = copy_data(raw)
    try:
        events = Ordinary(w, number, seed, player_order, hook).run(orders)
        return dict(result=dict(action="resolved", events=events), world=w)
    except e.Rejected as error:
        return dict(result=dict(action="invalid", reason=str(error)), world=raw)


class ResolutionMatch(DevelopmentMatch):
    HOOK_LIMIT = 9

    def _hook(self):
        if self.clock.hook not in HOOKS:
            return super()._hook()
        s = self._state
        if self.clock.round != 1 or s["pending"]["pending"] or s["persistent"]["active"] or s["cooldowns"]["locks"]:
            raise e.Unsupported("ResolutionMatch requires the supported fresh-game, power-free prefix")
        try:
            events = Ordinary(s["world"], self.clock.round, s["seed"], s["player_order"], self.clock.hook).run(s["combat_orders"])
        except e.Rejected as error:
            raise e.Rejected("transform_contract_error") from error
        s["events"]["rows"].extend(events)
