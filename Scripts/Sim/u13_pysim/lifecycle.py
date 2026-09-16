"""Remaining ordinary round hooks for the first independent full-game path.

Authority is the complete U13GameContent wrapper order. Declared powers remain
unsupported; paid Rites and Resummon precede Guards and Work in Development.
"""

from . import economy as e, marching_game, paid_development as paid
from .battle import Battle, operational, targetable
from .development import _deploy_owned, draw_pairs, reconcile, work
from .resolution import HOOKS, Ordinary


def alive(world, pid):
    return e.entity(world, world["players"][pid]["lord_entity_id"])["attributes"]["alive"]


def evaluate(world):
    players = world["players"]
    for pid in (0, 1):
        if alive(world, pid) and players[pid]["resources"]["souls"] >= 12:
            return dict(winner=pid, win_by="Ritual")
    veil = world["data"]["neutral_tears"] + sum(p["resources"]["personal_tears"] for p in players)
    if veil >= 26:
        return dict(winner=int(players[1]["resources"]["souls"] > players[0]["resources"]["souls"]), win_by="FinalCollapse")
    if veil >= 12:
        for pid in (0, 1):
            tears = players[pid]["resources"]["personal_tears"]
            if tears >= 5 and tears > players[1-pid]["resources"]["personal_tears"]:
                return dict(winner=pid, win_by="Dominion")
    return dict(winner=-1, win_by="")


def settle(world, number):
    d, events = world["data"], []
    throne = d["vacant_throne"]
    e.require(throne["round"] == number and throne["completed_round"] == number-1, "vacant_throne_already_resolved")
    for pid in (0, 1):
        throne["present"][pid] |= alive(world, pid)
        count = 0 if throne["present"][pid] else throne["prior_counts"][pid]+1
        gain = int(count > 2)
        throne["counts"][pid] = count
        world["players"][1-pid]["resources"]["souls"] += gain
        events.append(e.event("VACANT_THRONE_RESOLVED", dict(round=number, player_id=pid,
            lord_present_this_round=throne["present"][pid], vacant_rounds_before=throne["prior_counts"][pid],
            vacant_rounds_after=count, grace_rounds=2, soul_gain=gain, soul_recipient=1-pid if gain else -1,
            reason="lord_present_this_round" if throne["present"][pid] else "vacant_round")))
    throne["completed_round"] = number
    victory = d["victory"]
    e.require(victory["winner"] == -1 and victory["checked_round"] == number-1, "victory_already_resolved")
    pressure = 2 if number > 20 else 1 if number > 12 else 0
    if pressure:
        d["neutral_tears"] += pressure
        events.append(e.event("NEUTRAL_TEAR_CREATED", dict(round=number, amount=pressure, source="RoundPressure")))
    victory.update(evaluate(world), checked_round=number)
    if victory["winner"] != -1:
        tears = [p["resources"]["personal_tears"] for p in world["players"]]
        events.append(e.event("MATCH_FINISHED", dict(round=number, winner=victory["winner"], win_by=victory["win_by"],
            souls=[p["resources"]["souls"] for p in world["players"]], personal_tears=tears,
            veil_total=d["neutral_tears"]+sum(tears))))
    return events


class RoundRules(Ordinary):
    def extra(self):
        return []

    def context(self):
        return dict(world=self.w, round=self.number, seed=self.seed, player_order=self.order,
                    hook=self.hook, persistent_effects=[])

    @staticmethod
    def march_reaction(world, fact, seed, order):
        rules = Battle(world, fact["data"]["round"], seed, order, "marching")
        events = rules.react(fact)
        return dict(action="resolved", world=rules.w, events=events)

    def run(self, orders):
        if self.hook in HOOKS:
            return super().run(orders) + self.extra()
        hook, n, d = self.hook, self.number, self.w["data"]
        before_defunct = [r["id"] for r in self.w["entities"]["entities"] if targetable(r)
                          and r["attributes"]["status"] == "defunct"
                          and self.w["players"][r["owner"]]["lord_id"] == "Kalligan"]
        events = []
        if hook == "round_start_scheduled":
            throne = d["vacant_throne"]
            e.require(throne["round"] == n-1 and throne["completed_round"] == n-1, "vacant_throne_round_clock_invalid")
            throne.update(round=n, prior_counts=throne["counts"][:], present=[alive(self.w,pid) for pid in (0,1)])
            e.require(d["kroni_feed_round"] < n, "kroni_feed_already_applied")
            d["kroni_feed_round"], d["kroni_actors"] = n, []
        elif hook == "persistent_advancement":
            for r in self.w["entities"]["entities"]:
                a = r["attributes"]
                if r["kind"] != "marcher" or "rout_round" not in a or n <= a["rout_round"]:
                    continue
                ended = n-a["rout_round"] >= 2
                events.append(e.event("ROUT_ENDED" if ended else "ROUT_RECOVERING",
                                      dict(entity_id=r["id"], round=n, effect_id=a["rout_effect_id"])))
                if ended:
                    del a["rout_round"], a["rout_effect_id"]
            e.require(d["scorch_guard_round"] < n, "scorch_pulse_already_applied")
            d["scorch_guard_round"] = n
            if type(self) is RoundRules: d["valak_orbs"] = []
        elif hook == "round_start_automatic":
            e.require(d["sigil_lifecycle"]["aged_round"] == n-1, "sigil_age_clock_invalid")
            for pid in (0,1):
                for lane in ("Lord", "Castle"):
                    before = d["sigils"][pid][lane]
                    if not before:
                        continue
                    after = "flipped" if before == "fresh" else ""
                    d["sigils"][pid][lane] = after
                    label = "decaying" if after else "expired"
                    events.append(e.event("SIGIL_AGED", dict(player_id=pid, lane=lane, round=n,
                                          before=before, after=after, state_label=label), "Sigil "+label+"."))
            d["sigil_lifecycle"]["aged_round"] = n
            result = marching_game.regenerate(self.context())
            e.require(result["action"] == "resolved", result.get("reason", "marching_regen_context_invalid"))
            self.w = result["world"]
            d = self.w["data"]
            events.extend(result["events"])
            e.require(d["kalligan_upkeep_round"] < n, "kalligan_upkeep_already_applied")
            breach = d["breach_lord"] == "Kalligan"
            for r in self.w["entities"]["entities"]:
                a = r["attributes"]
                if not targetable(r) or a["integrity"] >= a["max_integrity"]:
                    continue
                if not breach and not self.active(r["owner"], "Kalligan"):
                    continue
                before = a["integrity"]
                a.update(integrity=min(a["max_integrity"], before+2), status="standing")
                events.append(e.event("RAPID_CONSTRUCTION" if breach else "FORGE_REPAIR", dict(
                    player_id=r["owner"], castle_id=r["id"], before=before, after=a["integrity"], round=n)))
            d["kalligan_upkeep_round"] = n
            e.require(d["reconfiguration_round"] < n, "reconfiguration_already_advanced")
            d["reconfiguration_round"], d["kanifous_loss_round"], d["kanifous_losses"] = n, n, []
        elif hook == "present_public_state":
            e.require(not d["game_economy"]["stockpile_pending"] and d["game_market"]["seat"] == 2, "development_choice_required")
            d["guard_public_round"], d["guard_public_limits"] = n, [6,6]
        elif hook == "development":
            events.extend(paid.resolve_rites(self.w,n,self.order))
            events.extend(paid.resolve_summon(self.w,n,self.order))
            e.require(d["construction_round"] < n, "development_clock_invalid")
            d["construction_round"] = n
            # Guards and Work follow Kalligan's inner wrapper, below.
        elif hook == "post_resolution_allegiance":
            e.require(d["paradox_round"] < n, "paradox_already_resolved")
            d["paradox_round"] = n
        elif hook == "marching_start":
            e.require(d["scorch_lane_round"] < n and d["kroni_breach_round"] < n, "marching_start_clock_invalid")
            d["scorch_lane_round"] = d["kroni_breach_round"] = n
        elif hook == "marching":
            result = marching_game.resolve(self.context(), self.march_reaction)
            e.require(result["action"] == "resolved", result.get("reason", "marching_context_invalid"))
            self.w = result["world"]
            d = self.w["data"]
            events.extend(result["events"])
        elif hook == "end_marching_checks":
            e.require(d["humbaba_end_round"] < n, "endurance_already_checked")
            for pid in self.order:
                if self.w["players"][pid]["lord_id"] != "Humbaba":
                    continue
                qualifying = [r["id"] for r in self.w["entities"]["entities"] if r["kind"] == "marcher"
                              and r["owner"] == pid and r["attributes"]["suit"] == "Penitent" and r["attributes"]["hp"] == 1]
                met = alive(self.w,pid) and bool(qualifying)
                events.append(e.event("ENDURANCE_CHECKED", dict(player_id=pid, round=n, threshold_met=met,
                                      lord_alive=alive(self.w,pid), qualifying_ids=qualifying)))
                if met:
                    d["neutral_tears"] += 1
                    events.append(e.event("NEUTRAL_TEAR_CREATED", dict(player_id=pid, round=n,
                                          amount=1, source="EnduranceOfTheFaithful")))
            d["humbaba_end_round"] = n
        elif hook == "aftermath":
            e.require(d.get("combat_cleanup_round",0) < n and e.cards_valid(self.w), "combat_already_cleaned")
            z = e.zones(self.w)
            for pid in self.order:
                for key in z["committed"][pid]:
                    e.entity(self.w,key)["owner"] = -1
                    z["discard"].append(key)
            z["committed"] = [[],[]]
            d["combat_cleanup_round"], d["castle_orders"] = n, [None,None]
            d["guard_orders"], d["summon_orders"] = [None,None], [None,None]
        elif hook not in ("submission_lock", "post_resolution_spawns", "post_resolution_position",
                          "post_resolution_movement_state", "post_resolution_hazards", "post_resolution_direct",
                          "post_resolution_special_actors"):
            raise e.Unsupported("Unknown round hook: "+hook)
        # Kalligan observes the pre-hook Defunct episode before outer Work.
        eligible = d["rekindle_defunct_ids"]
        for key in before_defunct:
            if key not in eligible:
                eligible.append(key)
        eligible.sort()
        for key in eligible[:]:
            r = e.entity(self.w,key)
            if not targetable(r):
                eligible.remove(key)
                continue
            if operational(r):
                eligible.remove(key)
                pid = r["owner"]
                if alive(self.w,pid) and d["rekindle_rounds"][pid] < n:
                    d["rekindle_rounds"][pid] = n
                    d["neutral_tears"] += 1
                    events.append(e.event("NEUTRAL_TEAR_CREATED", dict(source="Rekindle",amount=1,
                                          player_id=pid,castle_id=key,round=n)))
        events.extend(self.extra())
        if hook == "development":
            events.extend(_deploy_owned(self.w,n,self.order))
            events.extend(work(self.w,n,self.order))
        reconcile(self.w)
        events.extend(self.clear_sigils())
        for pid in (0,1):
            d["vacant_throne"]["present"][pid] |= alive(self.w,pid)
        if hook == "aftermath":
            d["dominion_rites"]["orders"] = [None,None]
            events.extend(settle(self.w,n))
        if hook == "round_start_automatic":
            events.extend(e.start_draw(self.w,self.seed,n))
            events.extend(draw_pairs(self.w,n,self.seed))
            if not d["game_economy"]["stockpile_pending"]:
                events.extend(e.market_begin(self.w,self.seed,n))
        return events
