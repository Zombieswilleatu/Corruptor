extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const Cooldowns = preload("res://Scripts/Sim/U13Cooldowns.gd")
const VERSION: String = "U13_LANE_AURAS_V1"


# The persistent registry is the only owner of identity/lifetime. Auras contain
# lane modifiers, never a captured cohort or tags left on individual Marchers.
static func enabled(world: Dictionary) -> bool:
	return world.data.get("lane_aura_profile") == VERSION


static func modifiers_valid(modifiers) -> bool:
	return (
		typeof(modifiers) == TYPE_DICTIONARY
		and modifiers.size() == 2
		and Data.is_integer(modifiers.get("regen_bonus"))
		and modifiers.regen_bonus >= 0
		and modifiers.regen_bonus <= 100
		and Data.is_integer(modifiers.get("speed_percent"))
		and modifiers.speed_percent >= 0
		and modifiers.speed_percent <= 100
	)


static func activate(record: Dictionary, context: Dictionary, modifiers: Dictionary) -> Dictionary:
	if not enabled(context.world) or not modifiers_valid(modifiers):
		return Data.invalid("lane_aura_profile_or_modifiers_invalid")
	var source: Dictionary = record.declaration
	if source.target.size() != 1 or source.target.get("lane") not in ["Lord", "Castle"]:
		return Data.invalid("lane_aura_target_invalid")
	var payload: Dictionary = {"lane_aura": modifiers.duplicate(true)}
	return {
		"action": "resolved",
		"world": context.world,
		"persistent_payload": payload,
		"events":
		[
			{
				"type": "LANE_AURA_STARTED",
				"text": "",
				"data":
				{
					"effect_id":
					Data.instance_id("persistent", source.declaration_id, source.power_id),
					"power_id": source.power_id,
					"player_id": source.player_id,
					"round": context.round,
					"lane": source.target.lane,
					"modifiers": modifiers.duplicate(true)
				}
			}
		]
	}


# Build four small owner/lane records once per phase, not per unit per tick.
# Separate auras add their bonuses; their lifetimes/slots remain independent.
static func compile(effects: Array, round_number: int) -> Dictionary:
	var result: Dictionary = {
		"Lord": [{"regen_bonus": 0, "speed_percent": 0}, {"regen_bonus": 0, "speed_percent": 0}],
		"Castle": [{"regen_bonus": 0, "speed_percent": 0}, {"regen_bonus": 0, "speed_percent": 0}]
	}
	for active in effects:
		if not active.payload.has("lane_aura"):
			continue
		if (
			round_number < active.activated_round
			or round_number >= active.activated_round + active.stages.size()
		):
			continue
		var values: Dictionary = result[active.target.lane][active.declaration.player_id]
		values.regen_bonus += int(active.payload.lane_aura.regen_bonus)
		values.speed_percent += int(active.payload.lane_aura.speed_percent)
	return result


# Exact rational step with deterministic fractional distribution. Compose Rout
# recovery before rounding, so (3 * 1.25 * 0.5) does not truncate to 1 per tick.
# Clock phase is bounded before multiplication and no float or RNG is involved.
static func speed(base: int, percent: int, recovering: bool, clock: int, web_slowed: bool = false, collapse: bool = false) -> int:
	var denominator: int = 200 if recovering else 100
	if collapse:
		denominator *= 2
	if web_slowed:
		denominator *= 2
	var numerator: int = base * (100 + percent)
	var phase: int = posmod(clock, denominator)
	# Suppress each intentional division at its statement, not the function.
	@warning_ignore("integer_division")
	var next_distance: int = ((phase + 1) * numerator) / denominator
	@warning_ignore("integer_division")
	var previous_distance: int = (phase * numerator) / denominator
	return next_distance - previous_distance


# Bind every modifier to trusted content and the central registry. This rejects
# forged magnitudes, targets, stages, payloads and premature/future lifetimes.
static func snapshot_valid(context: Dictionary, rules: Dictionary) -> bool:
	if not enabled(context.world):
		return false
	for active in context.get("persistent_effects", []):
		var rule: Dictionary = rules.get(active.declaration.power_id, {})
		if not rule.has("lane_aura"):
			if active.payload.has("lane_aura"):
				return false
			continue
		if (
			not modifiers_valid(rule.lane_aura)
			or active.payload != {"lane_aura": rule.lane_aura}
			or active.stages != rule.stages
			or active.target != active.declaration.target
			or active.target.size() != 1
			or active.target.get("lane") not in ["Lord", "Castle"]
			or (
				active.activated_round
				!= (
					active.declaration.declared_round
					if active.declaration.fire_round == -1
					else active.declaration.fire_round
				)
			)
			or active.effect_key != active.declaration.power_id
			or not active.declaration.parameters.is_empty()
		):
			return false
		var bound: bool = false
		for clock in context.get("cooldown_locks", []):
			if clock.persistent_effect_id == active.effect_id:
				bound = (
					clock.phase == Cooldowns.WAITING
					and clock.declaration == active.declaration
					and clock.cooldown_rounds == rule.cooldown_rounds
				)
		if not bound:
			return false
		var age: int = int(context.round) - int(active.activated_round)
		if age < 0 or age > active.stages.size():
			return false
		if age == 0 and context.next_hook_index <= Timeline.hook_rank(rule.fire_hook):
			return false
		if (
			age == active.stages.size()
			and context.next_hook_index > Timeline.hook_rank(Timeline.PERSISTENT_ADVANCEMENT)
		):
			return false
	return true
