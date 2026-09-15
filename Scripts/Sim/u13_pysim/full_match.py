"""Independent setup-to-victory adapter for explicitly scoped ordinary games.

Four Lords; all 20 hooks; repeated rounds; no declared powers, paid Rites or
Resummon yet. Those choices fail explicitly. Policies remain outside authority.
"""

from . import economy as e, marching_game
from .copying import copy_data
from .lifecycle import RoundRules
from .planning import PlanningMatch
from .timeline import HOOKS

VERSION = "U13_PYSIM_FULL_MATCH_V1"


class FullMatch(PlanningMatch):
    HOOK_LIMIT = len(HOOKS)

    def __init__(self, setup):
        super().__init__(setup)
        self._supported()

    def _supported(self):
        s = self.state
        marching_game.supported(dict(world=s["world"],persistent_effects=s["persistent"]["active"]))
        if s["pending"]["pending"] or s["cooldowns"]["locks"]:
            raise e.Unsupported("Pending powers and cooldowns are outside FullMatch V1")

    def _apply(self, operation, rollback_state):
        self._supported()
        kind = operation.get("kind")
        if kind == "next_round":
            e.require(set(operation) == {"kind"}, "trace_operation_invalid")
            e.require(self.outcome()["winner"] == -1, "match_finished")
            e.require(self.clock.completed, "match_round_not_complete")
            self.state["submissions"],self.state["combat_orders"] = [None,None],[{},{}]
            self.state["player_order"] = [0,1]
            return self.clock.begin(self.clock.round+1)
        if kind == "step" and self.clock.completed:
            e.require(set(operation) == {"kind","hook"} and operation["hook"] == "", "trace_operation_invalid")
            raise e.Rejected("match_hook_unavailable")
        if kind in ("market","stockpile"):
            e.require(self.outcome()["winner"] == -1, "match_finished")
        return super()._apply(operation,rollback_state)

    def _hook(self):
        self._supported()
        s, hook, n = self.state, self.clock.hook, self.clock.round
        if hook == "submission_lock":
            e.require(all(x is not None for x in s["submissions"]), "both_submissions_required")
            for pid in s["player_order"]:
                s["events"]["rows"].extend(self._accept_order(s["world"],pid,s["combat_orders"][pid]))
        if hook == "persistent_advancement":
            s["persistent"]["advanced_round"] = n
            s["cooldowns"]["round"] = n
        rules = RoundRules(s["world"],n,s["seed"],s["player_order"],hook)
        try:
            events = rules.run(s["combat_orders"])
        except e.Rejected as error:
            raise e.Rejected("transform_contract_error") from error
        s["world"] = rules.w
        s["events"]["rows"].extend(events)
        if hook == "present_public_state":
            s["presentation_world"] = copy_data(s["world"])
