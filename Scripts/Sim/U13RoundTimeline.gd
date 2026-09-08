class_name U13RoundTimeline
extends RefCounted

# U13_LORD_TIMELINE_V1
#
# Canonical engine timing contract for the U13 Lord overhaul.
#
# This file deliberately contains no Lord behavior. It gives every conductor,
# declaration, pending effect, test, replay, and bot one shared vocabulary for
# WHEN authoritative work is allowed to resolve.
#
# The design specification has 14 top-level steps. Step 10 expands into seven
# deterministic Post-Resolution substeps, so the executable hook order contains
# 20 entries.

const CONTRACT_VERSION: String = "U13_LORD_TIMELINE_V1"

const ROUND_START_SCHEDULED: String = "round_start_scheduled"
const PERSISTENT_ADVANCEMENT: String = "persistent_advancement"
const ROUND_START_AUTOMATIC: String = "round_start_automatic"
const PRESENT_PUBLIC_STATE: String = "present_public_state"
const SUBMISSION_LOCK: String = "submission_lock"
const DEVELOPMENT: String = "development"
const POST_REPAIR_ARTILLERY: String = "post_repair_artillery"
const COMMITMENT_REVEAL: String = "commitment_reveal"
const COMBAT_RESOLUTION: String = "combat_resolution"

const POST_RESOLUTION_SPAWNS: String = "post_resolution_spawns"
const POST_RESOLUTION_POSITION: String = "post_resolution_position"
const POST_RESOLUTION_ALLEGIANCE: String = "post_resolution_allegiance"
const POST_RESOLUTION_MOVEMENT_STATE: String = "post_resolution_movement_state"
const POST_RESOLUTION_HAZARDS: String = "post_resolution_hazards"
const POST_RESOLUTION_DIRECT: String = "post_resolution_direct"
const POST_RESOLUTION_SPECIAL_ACTORS: String = "post_resolution_special_actors"

const MARCHING_START: String = "marching_start"
const MARCHING: String = "marching"
const END_MARCHING_CHECKS: String = "end_marching_checks"
const AFTERMATH: String = "aftermath"


# Human/design-facing 14-step contract. Step 10 is a container whose internal
# order is represented by POST_RESOLUTION_HOOKS below.
const TOP_LEVEL_STEPS: Array[String] = [
	ROUND_START_SCHEDULED,
	PERSISTENT_ADVANCEMENT,
	ROUND_START_AUTOMATIC,
	PRESENT_PUBLIC_STATE,
	SUBMISSION_LOCK,
	DEVELOPMENT,
	POST_REPAIR_ARTILLERY,
	COMMITMENT_REVEAL,
	COMBAT_RESOLUTION,
	"post_resolution",
	MARCHING_START,
	MARCHING,
	END_MARCHING_CHECKS,
	AFTERMATH,
]


# Step 10A -> 10G. Effect class wins before Reflex; Reflex is only a
# cross-player tie-break inside one of these hooks. Multiple same-player effects
# in one hook use their serialized submission queue order.
const POST_RESOLUTION_HOOKS: Array[String] = [
	POST_RESOLUTION_SPAWNS,
	POST_RESOLUTION_POSITION,
	POST_RESOLUTION_ALLEGIANCE,
	POST_RESOLUTION_MOVEMENT_STATE,
	POST_RESOLUTION_HAZARDS,
	POST_RESOLUTION_DIRECT,
	POST_RESOLUTION_SPECIAL_ACTORS,
]


# Fully expanded authoritative execution order.
const EXECUTION_HOOKS: Array[String] = [
	ROUND_START_SCHEDULED,
	PERSISTENT_ADVANCEMENT,
	ROUND_START_AUTOMATIC,
	PRESENT_PUBLIC_STATE,
	SUBMISSION_LOCK,
	DEVELOPMENT,
	POST_REPAIR_ARTILLERY,
	COMMITMENT_REVEAL,
	COMBAT_RESOLUTION,
	POST_RESOLUTION_SPAWNS,
	POST_RESOLUTION_POSITION,
	POST_RESOLUTION_ALLEGIANCE,
	POST_RESOLUTION_MOVEMENT_STATE,
	POST_RESOLUTION_HAZARDS,
	POST_RESOLUTION_DIRECT,
	POST_RESOLUTION_SPECIAL_ACTORS,
	MARCHING_START,
	MARCHING,
	END_MARCHING_CHECKS,
	AFTERMATH,
]


static func is_valid_hook(hook: String) -> bool:
	return EXECUTION_HOOKS.has(hook)


static func hook_rank(hook: String) -> int:
	return EXECUTION_HOOKS.find(hook)


static func is_post_resolution_hook(hook: String) -> bool:
	return POST_RESOLUTION_HOOKS.has(hook)


static func post_resolution_rank(hook: String) -> int:
	return POST_RESOLUTION_HOOKS.find(hook)


static func top_level_step_number(hook: String) -> int:
	var execution_rank: int = hook_rank(hook)
	if execution_rank < 0:
		return -1

	if execution_rank <= hook_rank(COMBAT_RESOLUTION):
		return execution_rank + 1

	if is_post_resolution_hook(hook):
		return 10

	if hook == MARCHING_START:
		return 11
	if hook == MARCHING:
		return 12
	if hook == END_MARCHING_CHECKS:
		return 13
	if hook == AFTERMATH:
		return 14

	return -1


static func validate_contract() -> Dictionary:
	var errors: Array[String] = []
	var seen: Dictionary = {}

	if TOP_LEVEL_STEPS.size() != 14:
		errors.append(
			"Expected 14 top-level steps; found %d."
			% TOP_LEVEL_STEPS.size()
		)

	if POST_RESOLUTION_HOOKS.size() != 7:
		errors.append(
			"Expected seven Post-Resolution hooks; found %d."
			% POST_RESOLUTION_HOOKS.size()
		)

	if EXECUTION_HOOKS.size() != 20:
		errors.append(
			"Expected 20 expanded execution hooks; found %d."
			% EXECUTION_HOOKS.size()
		)

	for hook: String in EXECUTION_HOOKS:
		if hook.is_empty():
			errors.append("Execution hook must not be empty.")
			continue
		if seen.has(hook):
			errors.append("Duplicate execution hook: %s" % hook)
		seen[hook] = true

	for hook: String in POST_RESOLUTION_HOOKS:
		if not EXECUTION_HOOKS.has(hook):
			errors.append(
				"Post-Resolution hook missing from execution order: %s"
				% hook
			)
		elif top_level_step_number(hook) != 10:
			errors.append(
				"Post-Resolution hook did not map to Step 10: %s"
				% hook
			)

	if hook_rank(POST_RESOLUTION_SPAWNS) >= hook_rank(POST_RESOLUTION_POSITION):
		errors.append("10A Spawns must precede 10B Position.")
	if hook_rank(POST_RESOLUTION_POSITION) >= hook_rank(POST_RESOLUTION_ALLEGIANCE):
		errors.append("10B Position must precede 10C Allegiance.")
	if hook_rank(POST_RESOLUTION_ALLEGIANCE) >= hook_rank(POST_RESOLUTION_MOVEMENT_STATE):
		errors.append("10C Allegiance must precede 10D Movement-State.")
	if hook_rank(POST_RESOLUTION_MOVEMENT_STATE) >= hook_rank(POST_RESOLUTION_HAZARDS):
		errors.append("10D Movement-State must precede 10E Hazards.")
	if hook_rank(POST_RESOLUTION_HAZARDS) >= hook_rank(POST_RESOLUTION_DIRECT):
		errors.append("10E Hazards must precede 10F Direct effects.")
	if hook_rank(POST_RESOLUTION_DIRECT) >= hook_rank(POST_RESOLUTION_SPECIAL_ACTORS):
		errors.append("10F Direct effects must precede 10G Special Actors.")

	return {
		"valid": errors.is_empty(),
		"version": CONTRACT_VERSION,
		"errors": errors,
	}
