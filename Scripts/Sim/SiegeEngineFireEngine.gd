# SIEGE_ENGINE_BOMBARDMENT_V1
class_name SiegeEngineFireEngine
extends RefCounted


const CastleIntegrityRulesData = preload(
	"res://Scripts/Sim/CastleIntegrityRules.gd"
)


const CASTLE_NAME: String = "SiegeEngine"


static func resolve(
	game,
	rules: RuleConfig,
	random_source
) -> Dictionary:
	assert(
		game != null,
		"Siege Engine bombardment requires a GameState."
	)
	assert(
		rules != null,
		"Siege Engine bombardment requires RuleConfig."
	)
	assert(
		random_source != null,
		"Siege Engine bombardment requires deterministic RNG."
	)

	var damage: int = maxi(
		0,
		int(rules.siege_engine_round_damage)
	)

	var shooter_ids: Array[int] = []

	# Eligibility is snapshotted so opposing operational Engines fire
	# simultaneously for rules purposes. Destroying the enemy Engine with the
	# first processed shot does not cancel its already-earned shot this round.
	if damage > 0:
		for player in game.players:
			if CastleIntegrityRulesData.power_active(
				player,
				CASTLE_NAME,
				rules
			):
				shooter_ids.append(
					int(player.pid)
				)

	var events: Array[Dictionary] = []

	for shooter_id: int in shooter_ids:
		events.append(
			_fire_one(
				game,
				rules,
				random_source,
				shooter_id,
				damage
			)
		)

	game.refresh_derived_values()

	return {
		"action": "siege_engine_fire",
		"damage": damage,
		"events": events,
	}


static func _fire_one(
	game,
	rules: RuleConfig,
	random_source,
	shooter_id: int,
	damage: int
) -> Dictionary:
	var shooter = game.get_player(
		shooter_id
	)
	var defender = game.get_opponent(
		shooter_id
	)

	if shooter == null or defender == null:
		return _event(
			shooter_id,
			-1,
			false,
			"player_missing"
		)

	var defender_id: int = int(
		defender.pid
	)

	var target: String = String(
		shooter.siege_engine_target
	)

	if not _valid_target(
		defender,
		target
	):
		target = ""
		shooter.siege_engine_target = ""

	var acquired_target: bool = false

	if target.is_empty():
		var candidates: Array = []

		for raw_castle in defender.castles:
			var castle_name: String = String(
				raw_castle
			)

			if _valid_target(
				defender,
				castle_name
			):
				candidates.append(
					castle_name
				)

		if candidates.is_empty():
			return _event(
				shooter_id,
				defender_id,
				false,
				"no_enemy_castles"
			)

		# Stable candidate ordering keeps the random draw deterministic even if
		# some unrelated board mutation changed Array insertion order.
		candidates.sort()

		target = String(
			random_source.choice(
				candidates
			)
		)
		shooter.siege_engine_target = target
		acquired_target = true

	var before: int = int(
		defender.castle_integrity.get(
			target,
			CastleIntegrityRulesData.max_integrity(
				target
			)
		)
	)

	var applied: int = mini(
		damage,
		maxi(
			0,
			before
		)
	)

	var after: int = maxi(
		0,
		before - applied
	)

	defender.castle_integrity[
		target
	] = after

	var destroyed: bool = (
		before > 0
		and after <= 0
	)

	if destroyed:
		_ruin_without_action_rewards(
			defender,
			target,
			rules
		)

		# The lock is released only after the target ceases to exist. A fresh
		# target is selected on the Engine's NEXT firing, never as a second shot
		# in this round.
		shooter.siege_engine_target = ""

	return {
		"shooter_id": shooter_id,
		"defender_id": defender_id,
		"fired": true,
		"reason": "",
		"target_castle": target,
		"acquired_target": acquired_target,
		"damage": applied,
		"integrity_before": before,
		"integrity_after": after,
		"destroyed": destroyed,
		"soul_gain": 0,
		"neutral_tear_gain": 0,
		"personal_tear_gain": 0,
	}


static func _valid_target(
	defender,
	target: String
) -> bool:
	if (
		defender == null
		or target.is_empty()
		or not defender.castles.has(
			target
		)
	):
		return false

	return int(
		defender.castle_integrity.get(
			target,
			CastleIntegrityRulesData.max_integrity(
				target
			)
		)
	) > 0


static func _ruin_without_action_rewards(
	defender,
	castle_name: String,
	rules: RuleConfig
) -> void:
	defender.castles.erase(
		castle_name
	)
	defender.castle_integrity[
		castle_name
	] = 0
	defender.castle_construction_progress.erase(
		castle_name
	)
	defender.castle_repair_locked_this_round.erase(
		castle_name
	)
	defender.castle_operational_seen_this_round.erase(
		castle_name
	)

	# Bombardment is structural attrition, not a free Siege action. It does not
	# award Souls, Tears, Consume, or Lord-specific Siege rewards.
	if (
		rules.castle_permanent_loss
		and int(
			defender.castle_scars.get(
				castle_name,
				0
			)
		) >= 1
	):
		if not defender.lost_castles.has(
			castle_name
		):
			defender.lost_castles.append(
				castle_name
			)
		return

	if not defender.ruined_castles.has(
		castle_name
	):
		defender.ruined_castles.append(
			castle_name
		)


static func _event(
	shooter_id: int,
	defender_id: int,
	fired: bool,
	reason: String
) -> Dictionary:
	return {
		"shooter_id": shooter_id,
		"defender_id": defender_id,
		"fired": fired,
		"reason": reason,
		"target_castle": "",
		"acquired_target": false,
		"damage": 0,
		"integrity_before": 0,
		"integrity_after": 0,
		"destroyed": false,
		"soul_gain": 0,
		"neutral_tear_gain": 0,
		"personal_tear_gain": 0,
	}
