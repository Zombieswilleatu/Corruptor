class_name BotPolicy
extends RefCounted


const POLICY_FAMILY: String = "softmax-2026.07-v1"


var policy_id: String = POLICY_FAMILY
var temperature: float = 0.0
var error_rate: float = 0.0


func _init(
	new_policy_id: String = POLICY_FAMILY,
	new_temperature: float = 0.0,
	new_error_rate: float = 0.0
) -> void:
	policy_id = new_policy_id

	temperature = max(
		0.0,
		new_temperature
	)

	error_rate = clamp(
		new_error_rate,
		0.0,
		1.0
	)


static func golden_core():
	return BotPolicy.new(
		"%s-golden" % POLICY_FAMILY,
		0.0,
		0.0
	)


static func competitive():
	return BotPolicy.new(
		"%s-competitive" % POLICY_FAMILY,
		0.35,
		0.0
	)


static func standard():
	return BotPolicy.new(
		"%s-standard" % POLICY_FAMILY,
		0.70,
		0.0
	)


static func easy():
	return BotPolicy.new(
		"%s-easy" % POLICY_FAMILY,
		1.25,
		0.12
	)


func duplicate_policy():
	return BotPolicy.new(
		policy_id,
		temperature,
		error_rate
	)
