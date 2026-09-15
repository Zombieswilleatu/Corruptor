"""Independent match start -> submission lock mirror. Later hooks fail closed.

Supports fresh game setup, ordinary opening upkeep, draws/choices, and power-free
Pass/Ward/Hunt/Siege/Profane with Guard moves and Work reservations. It does not
resolve those orders. No expected Godot state is loaded into this match.
"""

from copy import deepcopy

from . import economy as e, opening
from .primitives import normalize, instance_id, draw as roll
from .timeline import Timeline

VERSION = "U13_PYSIM_PLANNING_V1"


class PlanningMatch:
    HOOK_LIMIT = 5

    def __init__(self, setup):
        self.state = opening.snapshot(setup["seed"], setup["lords"], setup["castles"])
        self.clock = Timeline()
        self.clock.begin(1)

    def snapshot(self):
        return deepcopy(self.state)

    def outcome(self):
        victory = self.state["world"]["data"]["victory"]
        return dict(action="game_finished" if victory["winner"] != -1 else "game_in_progress",
                    round=self.clock.round, winner=victory["winner"], win_by=victory["win_by"])

    def apply(self, operation):
        # Include clock, event rows and sealed slots in the transaction.
        before, clock = self.snapshot(), deepcopy(self.clock)
        try:
            result = self._apply(operation)
            self.state["runtime"] = self.clock.snapshot()
            return result
        except e.Rejected as error:
            self.state, self.clock = before, clock
            return {"action": "invalid", "reason": str(error)}
        except Exception:
            self.state, self.clock = before, clock
            raise

    def _apply(self, operation):
        kind = operation.get("kind")
        if kind == "step":
            e.require(set(operation) == {"kind", "hook"} and operation["hook"] == self.clock.hook,
                      "trace_operation_invalid")
            if self.clock.index >= self.HOOK_LIMIT:
                raise e.Unsupported("Python planning stops before " + self.clock.hook)
            before = self.snapshot()
            try:
                self._hook()
            except e.Rejected as error:
                self.state = before
                return self.clock.run(self.clock.hook, {"action": "invalid", "reason": str(error)})
            self.clock.run(self.clock.hook, {"action": "u13_dispatched"})
            return dict(action="u13_match_hook", next_hook=self.clock.hook, round=self.clock.round)
        if kind == "next_round":
            e.require(self.clock.completed, "match_round_not_complete")
            raise e.Unsupported("Python full-round resolution is not implemented")
        if kind in ("market", "stockpile"):
            pid = operation["player_id"]
            e.require(type(pid) is int and pid in (0, 1), "match_choice_unavailable")
            w = self.state["world"]
            if kind == "market":
                e.require("market" in operation["choice"], "market_choice_invalid")
                events = e.choose_market(w, pid, operation["choice"], self.clock.round, self.clock.hook)
            else:
                events = e.choose_stockpile(w, pid, {"keep_id": operation["keep_id"]},
                                            self.state["seed"], self.clock.round, self.clock.hook)
                if not w["data"]["game_economy"]["stockpile_pending"]:
                    events += e.market_begin(w, self.state["seed"], self.clock.round)
            self.state["events"]["rows"].extend(events)
            return {"action": "match_choice_accepted"}
        if kind == "submit_one":
            self._submit_one(operation["player_id"], operation["plan"])
            return {"action": "u13_submission_accepted"}
        if kind == "submit":
            plans = operation["plans"]
            e.require(type(plans) is list and len(plans) == 2 and self.clock.hook == "submission_lock",
                      "game_submissions_invalid")
            for pid in (0, 1):
                plan = plans[pid]
                e.require(type(plan) is dict and type(plan.get("powers")) is list
                          and type(plan.get("order")) is dict, "game_plan_invalid")
                self._submit_one(pid, plan)
            return {"action": "game_submitted"}
        raise e.Unsupported("Unknown planning operation: " + str(kind))

    def _submit_one(self, pid, plan):
        e.require(type(pid) is int and pid in (0, 1) and self.clock.hook == "submission_lock", "submission_window_closed")
        e.require(self.state["submissions"][pid] is None, "submission_already_locked")
        if plan["powers"]:
            raise e.Unsupported("Lord power declarations are outside planning V1")
        try:
            order = normalize(plan["order"])
        except ValueError as error:
            raise e.Rejected("submission_data_invalid") from error
        # A validation preview does not pay, reserve or append events to live state.
        self._accept_order(deepcopy(self.state["world"]), pid, order)
        self.state["submissions"][pid] = []
        self.state["combat_orders"][pid] = order

    def _accept_order(self, w, pid, order):
        d, z, number = w["data"], e.zones(w), self.clock.round
        if "summon" in order or order.get("rites"):
            raise e.Unsupported("Resummon and paid Rites are outside planning V1")
        choice = order.get("castle_action", {})
        moves = order.get("guard_moves", [])
        e.require(type(moves) is list and len(moves) <= 6, "guard_moves_invalid")
        seen, slots = set(), set()
        for move in moves:
            e.require(type(move) is dict and set(move) == {"card_id", "lane", "slot"}
                      and type(move["card_id"]) is str and bool(move["card_id"])
                      and move["lane"] in ("Lord", "Castle") and type(move["slot"]) is int
                      and move["slot"] in (0, 1, 2), "guard_moves_invalid")
            cell = (move["lane"], move["slot"])
            e.require(move["card_id"] not in seen and cell not in slots, "guard_moves_invalid")
            seen.add(move["card_id"])
            slots.add(cell)
        e.require(d["guard_public_round"] == number and len(moves) <= d["guard_public_limits"][pid], "guard_public_limit_exceeded")
        e.require(type(choice) is dict and (not choice or
                  (set(choice) == {"action", "target_id", "card_ids", "use_repair_token"}
                   and choice["action"] in ("Construct", "Repair", "Activate", "Work")
                   and type(choice["target_id"]) is str and (choice["target_id"] or choice["action"] == "Work")
                   and type(choice["use_repair_token"]) is bool
                   and type(choice["card_ids"]) is list
                   and all(type(x) is str and x for x in choice["card_ids"])
                   and len(set(choice["card_ids"])) == len(choice["card_ids"]))), "castle_action_shape_invalid")
        e.require(type(order.get("card_ids", [])) is list, "combat_order_shape_invalid")
        for move in moves:
            e.require(move["card_id"] in z["hands"][pid] and move["card_id"] not in order.get("card_ids", [])
                      and move["card_id"] not in choice.get("card_ids", []), "guard_card_unavailable")
        combat = {k: deepcopy(v) for k, v in order.items() if k not in ("guard_moves", "castle_action", "rites")}
        e.require(self._combat_shape(combat), "castle_order_invalid")
        if choice:
            e.require(choice["action"] == "Work" and choice["card_ids"] == []
                      and choice["use_repair_token"] is False, "choose_work_target_without_payment")
            if choice["target_id"]:
                target = e.entity(w, choice["target_id"])
                e.require(target and target["kind"] == "castle" and target["owner"] == pid
                          and target["attributes"]["status"] not in ("profaned", "ruined")
                          and (target["attributes"]["integrity"] < target["attributes"]["max_integrity"]
                               or target["attributes"]["construction_state"] != "active"), "work_target_unavailable")
        events = []
        d["dominion_rites"]["orders"][pid] = dict(round=number, choice={})
        d["summon_orders"][pid] = dict(round=number, choice={}, quote={"action": "legal"})
        d["guard_orders"][pid] = dict(round=number, moves=deepcopy(moves))
        if moves:
            events.append(e.sealed_event("GUARDS_SEALED", dict(player_id=pid, round=number, moves=moves), pid))
        d["castle_orders"][pid] = dict(round=number, choice=deepcopy(choice), paid_value=0, reconstruction=False)
        if choice:
            events.append(e.sealed_event("CASTLE_ACTION_SEALED", dict(player_id=pid, round=number, choice=choice), pid))
        if combat:
            action = combat["action"]
            target = e.entity(w, combat.get("target_id", ""))
            if action == "Hunt":
                e.require(target and target["kind"] == "lord" and target["owner"] == 1 - pid
                          and target["attributes"]["alive"], "hunt_target_invalid")
            elif action == "Siege":
                e.require(target and target["kind"] == "castle" and target["owner"] == 1 - pid
                          and target["attributes"]["construction_state"] == "active"
                          and target["attributes"]["status"] not in ("ruined", "profaned"), "combat_target_invalid")
            elif action == "Profane":
                e.require(target and target["owner"] == pid and e.operational(target)
                          and target["attributes"]["integrity"] == target["attributes"]["max_integrity"],
                          "profane_target_not_full_active_own_castle")
            e.require(e.selection(z["hands"][pid], combat["card_ids"]) and not z["committed"][pid], "combat_cards_unavailable")
            for identity in combat["card_ids"]:
                z["hands"][pid].remove(identity)
                z["committed"][pid].append(identity)
            events.append(e.sealed_event("COMBAT_ORDER_SEALED", dict(player_id=pid, round=number, order=combat), pid))
        return events

    @staticmethod
    def _combat_shape(order):
        if not order:
            return True
        action = order.get("action")
        expected = {"action", "lane", "card_ids"}
        if action not in ("Hunt", "Siege", "Ward", "Profane"):
            return False
        if "fracture_target" in order:
            if action != "Hunt" or order["fracture_target"] not in ("subjects", "infrastructure"):
                return False
            expected.add("fracture_target")
        if action != "Ward":
            expected.add("target_id")
            if type(order.get("target_id")) is not str or not order["target_id"] or order.get("lane") != ("Lord" if action == "Hunt" else "Castle"):
                return False
        ids = order.get("card_ids")
        return (set(order) == expected and order.get("lane") in ("Lord", "Castle")
                and type(ids) is list and all(type(x) is str and x for x in ids)
                and len(set(ids)) == len(ids) and (bool(ids) or action not in ("Hunt", "Siege")))

    def _hook(self):
        w, hook, number = self.state["world"], self.clock.hook, self.clock.round
        d, rows = w["data"], self.state["events"]["rows"]
        if (number != 1 or self.state["pending"]["pending"] or self.state["persistent"]["active"]
                or self.state["cooldowns"]["locks"] or d["guard_work"]["pairs"]
                or any(r["kind"] == "marcher" or r["attributes"].get("role") == "guard"
                       for r in w["entities"]["entities"])):
            raise e.Unsupported("Planning V1 requires a fresh game without active powers or deployed units")
        if hook == "round_start_scheduled":
            d["vacant_throne"].update(round=number, prior_counts=d["vacant_throne"]["counts"][:], present=[True, True])
            d["kroni_feed_round"] = number
            for pid, player in enumerate(w["players"]):
                if player["lord_id"] == "Kroni":
                    # Fresh game: no deployed Guards and zero Hunger.
                    rows.append(e.event("KRONI_HUNGER_CHANGED", dict(player_id=pid, before=0, after=0,
                                        round=number, cause="Cannibal Hunger"), "Cannibal Hunger: Hunger 0 → 0."))
        elif hook == "persistent_advancement":
            self.state["persistent"]["advanced_round"] = number
            self.state["cooldowns"]["round"] = number
            d["scorch_guard_round"] = number
        elif hook == "round_start_automatic":
            d["sigil_lifecycle"]["aged_round"] = number
            d["marching_regen_round"] = number
            d["kalligan_upkeep_round"] = number
            for castle in w["entities"]["entities"]:
                if (castle["kind"] == "castle" and e.operational(castle)
                        and w["players"][castle["owner"]]["lord_id"] == "Kalligan"
                        and castle["attributes"]["integrity"] < castle["attributes"]["max_integrity"]):
                    a = castle["attributes"]
                    before = a["integrity"]
                    a["integrity"] = min(a["max_integrity"], before + 2)
                    rows.append(e.event("FORGE_REPAIR", dict(player_id=castle["owner"], castle_id=castle["id"],
                                        before=before, after=a["integrity"], round=number)))
            for pid, player in enumerate(w["players"]):
                if player["lord_id"] == "Odradek":
                    before = player["resources"]["reconfiguration"]
                    player["resources"]["reconfiguration"] = min(4, before + 1)
                    rows.append(e.event("RECONFIGURATION_GAINED", dict(player_id=pid, before=before,
                                        after=player["resources"]["reconfiguration"], round=number)))
            d["reconfiguration_round"] = number
            d["kanifous_loss_round"] = number
            for pid, player in enumerate(w["players"]):
                if player["lord_id"] == "Kanifous":
                    identity = instance_id("wishmaster", str(pid), str(number))
                    seed = self.state["seed"]
                    target = dict(lane=("Lord", "Castle")[roll(seed, identity, "SMOKE_LANE", 0, 2)],
                                  field_position=dict(x_fp=600 + roll(seed, identity, "SMOKE_X", 0, 1201),
                                                      y_fp=180 + roll(seed, identity, "SMOKE_Y", 0, 241)))
                    smoke = dict(id=identity, owner=pid, phase="smoke", created_round=number,
                                 due_round=number + 1, target=target)
                    d["kanifous_objects"].append(smoke)
                    rows.append(e.event("WISHMASTER_SMOKE_CREATED", smoke, "Wishmaster Smoke Created"))
            rows.extend(e.start_draw(w, self.state["seed"], number))
            d["guard_work"]["draw_round"] = number
            if not d["game_economy"]["stockpile_pending"]:
                rows.extend(e.market_begin(w, self.state["seed"], number))
        elif hook == "present_public_state":
            # Match._dispatch routes the content rejection through _apply_transform,
            # which reports transform_contract_error before Runtime wraps it.
            e.require(not d["game_economy"]["stockpile_pending"] and d["game_market"]["seat"] == 2,
                      "transform_contract_error")
            d["guard_public_round"] = number
            self.state["presentation_world"] = deepcopy(w)
        elif hook == "submission_lock":
            e.require(all(x is not None for x in self.state["submissions"]), "both_submissions_required")
            for pid in self.state["player_order"]:
                rows.extend(self._accept_order(w, pid, self.state["combat_orders"][pid]))
        d["vacant_throne"]["present"] = [True, True]
