"""The U13 cursor contract; handlers own game semantics and transactions."""

from copy import deepcopy

HOOKS = ("round_start_scheduled", "persistent_advancement", "round_start_automatic",
         "present_public_state", "submission_lock", "development", "post_repair_artillery",
         "commitment_reveal", "combat_resolution", "post_resolution_spawns", "post_resolution_position",
         "post_resolution_allegiance", "post_resolution_movement_state", "post_resolution_hazards",
         "post_resolution_direct", "post_resolution_special_actors", "marching_start", "marching",
         "end_marching_checks", "aftermath")


def top_step(index):
    return index + 1 if index < 9 else 10 if index < 16 else index - 5


class Timeline:
    def __init__(self):
        self.round = 0
        self.index = 0
        self.completed = False
        self.log = []

    @property
    def hook(self):
        return "" if self.completed else HOOKS[self.index]

    def invalid(self, reason, hook):
        return dict(action="invalid", reason=reason, round=self.round, hook=hook,
                    expected_hook=self.hook, next_hook=self.hook)

    def begin(self, number):
        if number < 1:
            return self.invalid("round_number_invalid", "")
        self.round, self.index, self.completed, self.log = number, 0, False, []
        return dict(action="u13_round_begin", round=number, next_hook=self.hook)

    def run(self, hook, payload=None):
        if self.round < 1:
            return self.invalid("round_not_started", hook)
        if self.completed:
            return self.invalid("round_already_completed", hook)
        if hook not in HOOKS:
            return self.invalid("unknown_hook", hook)
        if hook != self.hook:
            return self.invalid("hook_out_of_order", hook)
        payload = {} if payload is None else deepcopy(payload)
        if type(payload) is not dict:
            return self.invalid("handler_result_not_dictionary", hook)
        if payload.get("action") == "invalid":
            return dict(self.invalid("handler_rejected_hook", hook), result=payload)
        top = top_step(self.index)
        self.log.append(dict(round=self.round, hook=hook, hook_rank=self.index,
                             top_level_step=top, result=payload))
        self.index += 1
        self.completed = self.index == len(HOOKS)
        return dict(action="u13_hook", reason="", round=self.round, hook=hook,
                    top_level_step=top, result=deepcopy(payload), completed=self.completed, next_hook=self.hook)

    def snapshot(self):
        return dict(round=self.round, next_hook_index=self.index, next_hook=self.hook,
                    completed=self.completed, execution_log=deepcopy(self.log), timeline_version="U13_LORD_TIMELINE_V1")
