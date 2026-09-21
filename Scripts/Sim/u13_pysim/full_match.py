"""Independent setup-to-victory adapter for explicitly scoped ordinary games.

Four Lords; all 20 hooks; repeated rounds, paid Rites and Resummon. Declared
powers still fail explicitly. Policies remain outside authority.
"""

from . import economy as e, marching_game, paid_development as paid
from .copying import copy_data, RollbackSnapshot
from .lord_hooks import LordRoundRules
from .planning import PlanningMatch
from .timeline import HOOKS

VERSION = "U13_PYSIM_FULL_MATCH_V2_PAID_DEVELOPMENT"


class FullMatch(PlanningMatch):
    HOOK_LIMIT = len(HOOKS)

    def __init__(self, setup):
        super().__init__(setup)
        self._supported()

    def _rollback_snapshot(self):
        # This opt-in is for the audited built-in dispatcher, not arbitrary
        # subclasses or replaced handlers. They retain complete rollback.
        owned = (type(self) is FullMatch and not self._state_exposed and
                 PlanningMatch._apply is _BASE_APPLY and
                 all(getattr(getattr(self, name), "__func__", getattr(self, name)) is method
                     for name, method in _OWNED_METHODS.items()))
        return RollbackSnapshot(self._state, share_history=owned)

    def _supported(self):
        s = self._state
        marching_game.supported(dict(world=s["world"],persistent_effects=s["persistent"]["active"],permanent_breaches=True))
        if s["pending"]["pending"] or s["cooldowns"]["locks"]:
            raise e.Unsupported("Pending powers and cooldowns are outside FullMatch V1")

    def _apply(self, operation, rollback_state):
        self._supported()
        kind = operation.get("kind")
        if kind == "next_round":
            e.require(set(operation) == {"kind"}, "trace_operation_invalid")
            e.require(self.outcome()["winner"] == -1, "match_finished")
            e.require(self.clock.completed, "match_round_not_complete")
            self._state["submissions"],self._state["combat_orders"] = [None,None],[{},{}]
            self._state["player_order"] = [0,1]
            return self.clock.begin(self.clock.round+1)
        if kind == "step" and self.clock.completed:
            e.require(set(operation) == {"kind","hook"} and operation["hook"] == "", "trace_operation_invalid")
            raise e.Rejected("match_hook_unavailable")
        if kind in ("market","stockpile"):
            e.require(self.outcome()["winner"] == -1, "match_finished")
        return super()._apply(operation,rollback_state)

    def _hook(self):
        self._supported()
        s, hook, n = self._state, self.clock.hook, self.clock.round
        if hook == "submission_lock":
            e.require(all(x is not None for x in s["submissions"]), "both_submissions_required")
            for pid in s["player_order"]:
                s["events"]["rows"].extend(self._accept_order(s["world"],pid,s["combat_orders"][pid]))
        if hook == "persistent_advancement":
            s["persistent"]["advanced_round"] = n
            s["cooldowns"]["round"] = n
        rules = LordRoundRules(s["world"],n,s["seed"],s["player_order"],hook,[])
        try:
            events = rules.run(s["combat_orders"])
        except e.Rejected as error:
            raise e.Rejected("transform_contract_error") from error
        s["world"] = rules.w
        s["events"]["rows"].extend(events)
        if hook == "present_public_state":
            s["presentation_world"] = copy_data(s["world"])

    def _accept_order(self, world, pid, order, reserve=True):
        from . import game_staging, split_ward
        if split_ward.enabled(world):
            if "ward" in order:
                return split_ward.accept(self, world, pid, order, reserve, self._accept_order)
            if order.get("action") == "Ward":
                e.require(bool(order.get("card_ids")), "ward_cards_required")
        e.require(game_staging.order_valid(world,order), "staging_order_invalid")
        order = {k:v for k,v in order.items() if k != "staging"}
        paid.validate_rites(world, pid, order)
        if not order.get("rites") and "summon" not in order:
            return super()._accept_order(world, pid, order, reserve)
        # Native admission stages Rite payments before Resummon and the other
        # orders. Only a paid preview needs this extra world; ordinary decisions
        # retain the existing validation path and immutable history optimization.
        staged = world if reserve else copy_data(world)
        paid.reserve_rites(staged, pid, order, self.clock.round)
        paid.reserve_summon(staged, pid, order, self.clock.round)
        d = staged["data"]
        rites, summon = d["dominion_rites"]["orders"][pid], d["summon_orders"][pid]
        ordinary = {k: v for k, v in order.items() if k not in ("rites", "summon")}
        events = super()._accept_order(staged, pid, ordinary, reserve)
        if reserve:
            d["dominion_rites"]["orders"][pid], d["summon_orders"][pid] = rites, summon
        return events


# Captured functions make instance/class replacement conservative too. Helpers
# below this boundary receive only mutable world/orders and fresh event lists.
_OWNED_METHODS = {name: getattr(FullMatch, name) for name in
                  ("_apply", "_hook", "_supported", "_submit_one", "_accept_order", "_combat_shape", "outcome")}
_BASE_APPLY = PlanningMatch._apply
