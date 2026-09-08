class_name MarchingEngine
extends RefCounted


const ResolutionFinaleEngineData = preload(
	"res://Scripts/Sim/ResolutionFinaleEngine.gd"
)


const ZONE_LORD: String = "Lord"
const ZONE_CASTLE: String = "Castle"
const LANES: Array[String] = [
	ZONE_LORD,
	ZONE_CASTLE,
]

const SUIT_BEATS: Dictionary = {
	"Butcher": "Wright",
	"Wright": "Penitent",
	"Penitent": "Vulture",
	"Vulture": "Butcher",
}


# COMMITMENT_MARCHING_FOUNDATION_V1
# BATTLEFIELD_CLOCK_V1
# BATTLEFIELD_BIRTH_ROUND_HOLD_V1
# MARCHER_WAITING_SUPPORT_V1
# Reaching the enemy objective creates a persistent waiting force.
# Waiters do not move or regenerate; each supplies +1 to the next
# matching Hunt/Siege and is then consumed by that action.
# BATTLEFIELD_PLAYBACK_V1
# Each resolved half exports authoritative start/end unit state plus
# tick-stamped clash/destruction/arrival events. UI2 replays that tape;
# simulation remains instantaneous and deterministic.
# BATTLEFIELD_CLOCK_INTEGER_DIVISION_FIX_V2
# BATTLEFIELD_CLOCK_INTEGER_DIVISION_FIX_V1
# Fresh Commitment marchers exist immediately after Reveal and may block/fight,
# but they cannot advance during either battlefield half of their birth round.
# Commitment-generated marchers are persistent individual battlefield units.
# They use a deterministic fixed-step clock. Presentation reads normalized
# progress; no UI physics owns gameplay position.
#
# MOVE is distance per battlefield HALF. A 12-unit lane means the baseline
# MOVE 2 units preserve the old ~3-round gate-to-gate travel time:
#   Butcher/Wright: 3 rounds, Vulture: 2, Penitent: 4 (without combat).
const STANDARD_MARCHER_VALUE: int = 3
const STANDARD_MARCHER_UNIT: String = "Standard"
const STANDARD_MARCHER_SOURCE: String = "commitment"
const STANDARD_MAX_HP: int = 5

const LANE_LENGTH: float = 12.0
const DISTANCE_FP_SCALE: int = 200
const LANE_DISTANCE_FP: int = 2400
const HALF_TICKS: int = 100

const STANDARD_SUITS: Array[String] = [
	"Butcher",
	"Penitent",
	"Vulture",
	"Wright",
]

# step_fp is movement per fixed tick. Over 100 ticks this yields exactly:
# Penitent 1.5, Butcher/Wright 2.0, Vulture 3.0 display units per half.
const STANDARD_STATS: Dictionary = {
	"Butcher": {
		"attack": 3,
		"armor": 1,
		"move": 2.0,
		"regen": 1,
		"step_fp": 4,
		"armor_bypass": false,
	},
	"Penitent": {
		"attack": 1,
		"armor": 3,
		"move": 1.5,
		"regen": 2,
		"step_fp": 3,
		"armor_bypass": false,
	},
	"Vulture": {
		"attack": 2,
		"armor": 1,
		"move": 3.0,
		"regen": 1,
		"step_fp": 6,
		"armor_bypass": true,
	},
	"Wright": {
		"attack": 2,
		"armor": 2,
		"move": 2.0,
		"regen": 1,
		"step_fp": 4,
		"armor_bypass": false,
	},
}


static func spawn_from_commitments(
	game,
	rules: RuleConfig,
	commitment_choices: Dictionary
) -> Dictionary:
	var events: Array[Dictionary] = []

	if not rules.marching:
		return {
			"action": "march_spawn",
			"enabled": false,
			"events": events,
		}

	for player in game.players:
		var player_id: int = int(player.pid)
		var raw_choice = commitment_choices.get(player_id, {})
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue

		var choice: Dictionary = raw_choice
		var lane: String = _commitment_lane(choice)
		if lane.is_empty():
			continue

		var suit_totals: Dictionary = {}
		for suit_name: String in STANDARD_SUITS:
			suit_totals[suit_name] = 0

		# WARD_MARCHER_SPAWN_FROM_COMMITMENT_CHOICE_V1
		# Spawn from the immutable Commitment choice, not player.committed.
		# Ward resolves during Reveal and may mutate/clear player.committed before
		# this post-Reveal spawn hook runs. Hunt/Siege survive until Resolution,
		# which is why this presented as "Ward does not march."
		var raw_committed_cards = choice.get("cards", null)
		if typeof(raw_committed_cards) == TYPE_ARRAY:
			for raw_card in raw_committed_cards:
				var parsed: Dictionary = _march_commitment_card_parts(raw_card)
				var suit_name: String = String(parsed.get("suit", ""))
				var card_value: int = int(parsed.get("value", 0))
				if not suit_totals.has(suit_name) or card_value <= 0:
					continue
				suit_totals[suit_name] = (
					int(suit_totals.get(suit_name, 0))
					+ card_value
				)
		else:
			# Compatibility fallback for nonstandard callers that omit choice["cards"].
			for card in player.committed:
				if card == null:
					continue
				var suit_name: String = String(card.suit)
				if not suit_totals.has(suit_name):
					continue
				suit_totals[suit_name] = (
					int(suit_totals.get(suit_name, 0))
					+ int(card.value)
				)

		var generated_index: int = 0
		for suit_name: String in STANDARD_SUITS:
			var total_value: int = int(suit_totals.get(suit_name, 0))
			var marcher_count: int = int(float(total_value) / float(STANDARD_MARCHER_VALUE))
			var stats: Dictionary = _standard_stats_for(suit_name)

			for _marcher_index: int in range(marcher_count):
				var marcher_id: String = (
					"p%d_r%d_m%d"
					% [
						player_id,
						int(game.round),
						generated_index,
					]
				)
				generated_index += 1

				var marcher: Dictionary = {
					"id": marcher_id,
					"unit": STANDARD_MARCHER_UNIT,
					"suit": suit_name,
					"value": STANDARD_MARCHER_VALUE,
					"lane": lane,
					"attack": int(stats.get("attack", 1)),
					"armor": int(stats.get("armor", 0)),
					"max_armor": int(stats.get("armor", 0)),
					"hp": STANDARD_MAX_HP,
					"max_hp": STANDARD_MAX_HP,
					"move": float(stats.get("move", 0.0)),
					"regen": int(stats.get("regen", 1)),
					"armor_bypass": bool(stats.get("armor_bypass", false)),
					"step_fp": int(stats.get("step_fp", 0)),
					"distance_fp": 0,
					"distance": 0.0,
					"speed": float(stats.get("move", 0.0)),
					"progress": 0.0,
					"source": STANDARD_MARCHER_SOURCE,
					"spawn_round": int(game.round),
				}
				player.marchers.append(marcher)

				events.append({
					"type": "march_spawn",
					"player_id": player_id,
					"id": marcher_id,
					"unit": STANDARD_MARCHER_UNIT,
					"suit": suit_name,
					"value": STANDARD_MARCHER_VALUE,
					"lane": lane,
					"attack": int(marcher.get("attack", 0)),
					"armor": int(marcher.get("armor", 0)),
					"hp": int(marcher.get("hp", 0)),
					"move": float(marcher.get("move", 0.0)),
					"regen": int(marcher.get("regen", 0)),
					"armor_bypass": bool(marcher.get("armor_bypass", false)),
					"source": STANDARD_MARCHER_SOURCE,
				})

	return {
		"action": "march_spawn",
		"enabled": true,
		"events": events,
	}


static func regenerate_at_round_start(
	game,
	rules: RuleConfig
) -> Dictionary:
	var events: Array[Dictionary] = []
	if not rules.marching:
		return {
			"action": "march_regen",
			"enabled": false,
			"events": events,
		}

	for player in game.players:
		for index: int in range(player.marchers.size()):
			var marcher: Dictionary = player.marchers[index]
			if not _is_standard_token(marcher):
				continue
			_ensure_standard_schema(marcher)
			if bool(marcher.get("waiting", false)):
				continue
			var before: int = int(marcher.get("hp", STANDARD_MAX_HP))
			var maximum: int = int(marcher.get("max_hp", STANDARD_MAX_HP))
			var regen: int = int(marcher.get("regen", 1))
			var after: int = mini(maximum, before + regen)
			marcher["hp"] = after
			_sync_public_position(marcher)
			player.marchers[index] = marcher
			if after != before:
				events.append({
					"type": "march_regen",
					"player_id": int(player.pid),
					"id": String(marcher.get("id", "")),
					"suit": String(marcher.get("suit", "")),
					"hp_before": before,
					"hp_after": after,
				})

	return {
		"action": "march_regen",
		"enabled": true,
		"events": events,
	}


static func resolve_half(
	game,
	rules: RuleConfig,
	random_source,
	half_name: String
) -> Dictionary:
	var events: Array[Dictionary] = []
	if not rules.marching:
		return {
			"action": "march_half",
			"enabled": false,
			"half": half_name,
			"ticks": 0,
			"events": events,
			"terminal": false,
		}

	_ensure_all_standard_schemas(game)
	var start_state: Array[Dictionary] = _battlefield_playback_state(game)
	var ticks_run: int = 0
	var terminal: bool = false

	for tick: int in range(HALF_TICKS):
		ticks_run = tick + 1

		# Every movement-eligible living standard token advances independently.
		# Same-side units may overlap; opposing fronts may not pass each other.
		# BATTLEFIELD_BIRTH_ROUND_HOLD_V1: a newly spawned marcher is physically
		# present and can be selected by contact resolution, but it stays at its gate
		# until the next round. This keeps the second battlefield window while making
		# Commitment reinforcements stationary on their birth round.
		for player in game.players:
			for index: int in range(player.marchers.size()):
				var marcher: Dictionary = player.marchers[index]
				if not _is_standard_token(marcher):
					continue
				if int(marcher.get("hp", 0)) <= 0:
					continue
				if bool(marcher.get("waiting", false)):
					continue
				if int(marcher.get("spawn_round", -1)) >= int(game.round):
					continue
				marcher["distance_fp"] = mini(
					LANE_DISTANCE_FP,
					int(marcher.get("distance_fp", 0))
					+ int(marcher.get("step_fp", 0))
				)
				player.marchers[index] = marcher

		# Contact is lane-local. A duel resolves completely before another unit
		# can pass that contact point. Exact tied fronts use the seeded game RNG.
		for lane: String in LANES:
			_resolve_lane_contacts(
				game,
				rules,
				random_source,
				lane,
				half_name,
				tick,
				events
			)

		_resolve_arrivals(game, rules, half_name, tick, events)

		# Souls/Tears can end the game. Resolve the complete fixed tick first so
		# simultaneous lane outcomes remain simultaneous, then checkpoint victory.
		if not events.is_empty():
			game.refresh_derived_values()
			terminal = ResolutionFinaleEngineData.check_win(game, rules)
			if terminal:
				break

	_sync_all_public_positions(game)
	var end_state: Array[Dictionary] = _battlefield_playback_state(game)
	game.refresh_derived_values()
	if not terminal:
		terminal = ResolutionFinaleEngineData.check_win(game, rules)

	return {
		"action": "march_half",
		"enabled": true,
		"half": half_name,
		"ticks": ticks_run,
		"half_ticks": HALF_TICKS,
		"start_state": start_state,
		"end_state": end_state,
		"events": events,
		"terminal": terminal,
	}



static func _battlefield_playback_state(
	game
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for player in game.players:
		for marcher in player.marchers:
			if not _is_standard_token(marcher):
				continue
			rows.append({
				"player_id": int(player.pid),
				"id": String(marcher.get("id", "")),
				"suit": String(marcher.get("suit", "")),
				"lane": String(marcher.get("lane", "")),
				"progress": clampf(
					float(marcher.get("progress", 0.0)),
					0.0,
					1.0
				),
				"hp": int(marcher.get("hp", 0)),
				"armor": int(marcher.get("armor", 0)),
				"spawn_round": int(marcher.get("spawn_round", 0)),
				"waiting": bool(marcher.get("waiting", false)),
				"waiting_since_round": int(marcher.get("waiting_since_round", -1)),
			})
	return rows


static func _resolve_lane_contacts(
	game,
	rules: RuleConfig,
	random_source,
	lane: String,
	half_name: String,
	tick: int,
	events: Array[Dictionary]
) -> void:
	var first_player = game.get_player(0)
	var second_player = game.get_player(1)
	if first_player == null or second_player == null:
		return

	# A single tick can contain a whole queue battle: A/B/C can all arrive at
	# the same contact and are still resolved as individual pieces.
	var safety: int = 0
	while safety < 256:
		safety += 1
		var first_index: int = _front_index(first_player, lane, random_source)
		var second_index: int = _front_index(second_player, lane, random_source)
		if first_index < 0 or second_index < 0:
			return

		var first: Dictionary = first_player.marchers[first_index]
		var second: Dictionary = second_player.marchers[second_index]
		var first_distance: int = int(first.get("distance_fp", 0))
		var second_distance: int = int(second.get("distance_fp", 0))
		if first_distance + second_distance < LANE_DISTANCE_FP:
			return

		# Convert the two slightly crossed fixed-tick fronts to one shared contact
		# point. The maximum correction is only one 1/100-half movement tick.
		var second_world_from_first_gate: int = LANE_DISTANCE_FP - second_distance
		var contact_from_first_gate: int = clampi(
			int((float(first_distance) + float(second_world_from_first_gate)) / 2.0),
			0,
			LANE_DISTANCE_FP
		)

		var first_start_hp: int = int(first.get("hp", 0))
		var first_start_armor: int = int(first.get("armor", 0))
		var second_start_hp: int = int(second.get("hp", 0))
		var second_start_armor: int = int(second.get("armor", 0))
		var exchange_rows: Array[Dictionary] = []
		var exchange_count: int = 0

		# Fights are simultaneous exchanges and continue immediately to death.
		while (
			int(first.get("hp", 0)) > 0
			and int(second.get("hp", 0)) > 0
			and exchange_count < 64
		):
			exchange_count += 1
			var first_attack: int = maxi(1, int(first.get("attack", 1)))
			var second_attack: int = maxi(1, int(second.get("attack", 1)))
			var first_bypass: bool = bool(first.get("armor_bypass", false))
			var second_bypass: bool = bool(second.get("armor_bypass", false))

			# Capture attacks first; both land even if the first application is lethal.
			_apply_attack(second, first_attack, first_bypass)
			_apply_attack(first, second_attack, second_bypass)

			exchange_rows.append({
				"exchange": exchange_count,
				"first_attack": first_attack,
				"first_bypass": first_bypass,
				"second_attack": second_attack,
				"second_bypass": second_bypass,
				"first_hp": int(first.get("hp", 0)),
				"first_armor": int(first.get("armor", 0)),
				"second_hp": int(second.get("hp", 0)),
				"second_armor": int(second.get("armor", 0)),
			})

		var first_dead: bool = int(first.get("hp", 0)) <= 0
		var second_dead: bool = int(second.get("hp", 0)) <= 0

		events.append({
			"type": "march_clash",
			"half": half_name,
			"tick": tick,
			"lane": lane,
			"contact_progress": float(contact_from_first_gate) / float(LANE_DISTANCE_FP),
			"first_player_id": int(first_player.pid),
			"first_id": String(first.get("id", "")),
			"first_suit": String(first.get("suit", "")),
			"first_hp_before": first_start_hp,
			"first_armor_before": first_start_armor,
			"first_hp_after": maxi(0, int(first.get("hp", 0))),
			"first_armor_after": maxi(0, int(first.get("armor", 0))),
			"second_player_id": int(second_player.pid),
			"second_id": String(second.get("id", "")),
			"second_suit": String(second.get("suit", "")),
			"second_hp_before": second_start_hp,
			"second_armor_before": second_start_armor,
			"second_hp_after": maxi(0, int(second.get("hp", 0))),
			"second_armor_after": maxi(0, int(second.get("armor", 0))),
			"exchanges": exchange_rows,
		})

		if first_dead:
			# BATTLEFIELD_NO_KILL_SOUL_V1
			# Marcher casualties change battlefield position only;
			# they never award Souls.
			events.append({
				"type": "march_destroyed",
				"half": half_name,
				"tick": tick,
				"lane": lane,
				"player_id": int(first_player.pid),
				"id": String(first.get("id", "")),
				"suit": String(first.get("suit", "")),
				"killer_id": String(second.get("id", "")),
			})
			first_player.marchers.remove_at(first_index)
		else:
			first["distance_fp"] = contact_from_first_gate
			_sync_public_position(first)
			first_player.marchers[first_index] = first

		if second_dead:
			events.append({
				"type": "march_destroyed",
				"half": half_name,
				"tick": tick,
				"lane": lane,
				"player_id": int(second_player.pid),
				"id": String(second.get("id", "")),
				"suit": String(second.get("suit", "")),
				"killer_id": String(first.get("id", "")),
			})
			second_player.marchers.remove_at(second_index)
		else:
			second["distance_fp"] = LANE_DISTANCE_FP - contact_from_first_gate
			_sync_public_position(second)
			second_player.marchers[second_index] = second

		# All standard attacks are >=1, so a duel cannot end with two survivors.
		# Keep a hard escape anyway rather than risk an infinite loop after bad data.
		if not first_dead and not second_dead:
			return


static func _resolve_arrivals(
	game,
	rules: RuleConfig,
	half_name: String,
	tick: int,
	events: Array[Dictionary]
) -> void:
	for player in game.players:
		for index: int in range(player.marchers.size() - 1, -1, -1):
			var marcher: Dictionary = player.marchers[index]
			if not _is_standard_token(marcher):
				continue
			if bool(marcher.get("waiting", false)):
				continue
			if int(marcher.get("distance_fp", 0)) < LANE_DISTANCE_FP:
				continue

			# MARCHER_WAITING_SUPPORT_V1 — no Tear and no disappearance.
			# The survivor camps at the enemy objective until its owner uses
			# the matching Hunt/Siege. It remains a real battlefield piece,
			# so an enemy spawned at that gate can immediately fight it.
			marcher["distance_fp"] = LANE_DISTANCE_FP
			marcher["waiting"] = true
			marcher["waiting_since_round"] = int(game.round)
			_sync_public_position(marcher)
			player.marchers[index] = marcher
			events.append({
				"type": "march_waiting",
				"half": half_name,
				"tick": tick,
				"player_id": int(player.pid),
				"id": String(marcher.get("id", "")),
				"suit": String(marcher.get("suit", "")),
				"lane": String(marcher.get("lane", "")),
			})

static func _front_index(
	player,
	lane: String,
	random_source
) -> int:
	if player == null:
		return -1

	var best_distance: int = -1
	var tied: Array[int] = []
	for index: int in range(player.marchers.size()):
		var marcher: Dictionary = player.marchers[index]
		if not _is_standard_token(marcher):
			continue
		if String(marcher.get("lane", "")) != lane:
			continue
		if int(marcher.get("hp", 0)) <= 0:
			continue
		var distance: int = int(marcher.get("distance_fp", 0))
		if distance > best_distance:
			best_distance = distance
			tied.clear()
			tied.append(index)
		elif distance == best_distance:
			tied.append(index)

	if tied.is_empty():
		return -1
	if tied.size() == 1:
		return tied[0]

	# Exact ties are deliberately random, but use the match RNG so replays and
	# headless simulations remain deterministic. Fallback is stable array order.
	if random_source != null and random_source.has_method("randi_range"):
		var choice: int = int(random_source.randi_range(0, tied.size() - 1))
		return tied[choice]
	return tied[0]


static func _apply_attack(
	target: Dictionary,
	damage: int,
	bypass_armor: bool
) -> void:
	var remaining: int = maxi(0, damage)
	if not bypass_armor:
		var armor: int = maxi(0, int(target.get("armor", 0)))
		var absorbed: int = mini(armor, remaining)
		target["armor"] = armor - absorbed
		remaining -= absorbed

	if remaining > 0:
		target["hp"] = int(target.get("hp", 0)) - remaining


static func _ensure_all_standard_schemas(game) -> void:
	for player in game.players:
		for index: int in range(player.marchers.size()):
			var marcher: Dictionary = player.marchers[index]
			if not _is_standard_token(marcher):
				continue
			_ensure_standard_schema(marcher)
			player.marchers[index] = marcher


static func _ensure_standard_schema(marcher: Dictionary) -> void:
	var suit_name: String = String(marcher.get("suit", ""))
	var stats: Dictionary = _standard_stats_for(suit_name)
	if not marcher.has("attack"):
		marcher["attack"] = int(stats.get("attack", 1))
	if not marcher.has("armor"):
		marcher["armor"] = int(stats.get("armor", 0))
	if not marcher.has("max_armor"):
		marcher["max_armor"] = int(stats.get("armor", 0))
	if not marcher.has("hp"):
		marcher["hp"] = STANDARD_MAX_HP
	if not marcher.has("max_hp"):
		marcher["max_hp"] = STANDARD_MAX_HP
	if not marcher.has("move"):
		marcher["move"] = float(stats.get("move", 0.0))
	if not marcher.has("regen"):
		marcher["regen"] = int(stats.get("regen", 1))
	if not marcher.has("armor_bypass"):
		marcher["armor_bypass"] = bool(stats.get("armor_bypass", false))
	if not marcher.has("step_fp"):
		marcher["step_fp"] = int(stats.get("step_fp", 0))
	if not marcher.has("distance_fp"):
		marcher["distance_fp"] = clampi(
			int(round(float(marcher.get("distance", 0.0)) * DISTANCE_FP_SCALE)),
			0,
			LANE_DISTANCE_FP
		)
	_sync_public_position(marcher)


static func _sync_all_public_positions(game) -> void:
	for player in game.players:
		for index: int in range(player.marchers.size()):
			var marcher: Dictionary = player.marchers[index]
			if not _is_standard_token(marcher):
				continue
			_sync_public_position(marcher)
			player.marchers[index] = marcher


static func _sync_public_position(marcher: Dictionary) -> void:
	var distance_fp: int = clampi(
		int(marcher.get("distance_fp", 0)),
		0,
		LANE_DISTANCE_FP
	)
	marcher["distance_fp"] = distance_fp
	marcher["distance"] = float(distance_fp) / float(DISTANCE_FP_SCALE)
	marcher["speed"] = float(marcher.get("move", 0.0))
	marcher["progress"] = float(distance_fp) / float(LANE_DISTANCE_FP)


static func _is_standard_token(marcher: Dictionary) -> bool:
	return (
		marcher.get("card", null) == null
		and String(marcher.get("source", "")) == STANDARD_MARCHER_SOURCE
		and STANDARD_SUITS.has(String(marcher.get("suit", "")))
	)


static func _standard_stats_for(suit_name: String) -> Dictionary:
	var raw = STANDARD_STATS.get(suit_name, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


# WARD_MARCHER_SPAWN_FROM_COMMITMENT_CHOICE_V1
static func _march_commitment_card_parts(raw_card) -> Dictionary:
	if raw_card == null:
		return {}

	if typeof(raw_card) == TYPE_STRING:
		var text: String = String(raw_card)
		var separator: int = text.rfind(":")
		if separator <= 0 or separator >= text.length() - 1:
			return {}
		return {
			"suit": text.substr(0, separator),
			"value": int(text.substr(separator + 1)),
		}

	if typeof(raw_card) == TYPE_DICTIONARY:
		var row: Dictionary = raw_card
		return {
			"suit": String(row.get("suit", "")),
			"value": int(row.get("value", 0)),
		}

	if typeof(raw_card) == TYPE_OBJECT:
		return {
			"suit": String(raw_card.get("suit")),
			"value": int(raw_card.get("value")),
		}

	return {}


static func _commitment_lane(
	choice: Dictionary
) -> String:
	var action_name: String = String(
		choice.get("action", "")
	).strip_edges().to_lower()

	match action_name:
		"hunt":
			return ZONE_LORD
		"siege", "profane":
			return ZONE_CASTLE
		"ward":
			var zone: String = String(
				choice.get(
					"target_type",
					choice.get("ward_target", "")
				)
			)
			return zone if LANES.has(zone) else ""
		_:
			return ""


static func reactive_lane_for(
	game,
	player,
	rules: RuleConfig
) -> String:
	if (
		not rules.humbaba_reactive_lane
		or String(player.lord) != "Humbaba"
		or player.marchers.size() != rules.march_max_in_flight
	):
		return ""

	var opponent = game.get_opponent(int(player.pid))
	if opponent == null or opponent.marchers.is_empty():
		return ""

	var enemy_lanes: Dictionary = {}
	var own_lanes: Dictionary = {}
	for marcher in opponent.marchers:
		enemy_lanes[String(marcher.get("lane", ""))] = true
	for marcher in player.marchers:
		own_lanes[String(marcher.get("lane", ""))] = true

	for lane: String in LANES:
		if enemy_lanes.has(lane) and not own_lanes.has(lane):
			return lane

	return ""


static func can_launch_marcher(
	game,
	player,
	rules: RuleConfig
) -> bool:
	return (
		player.marchers.size() < rules.march_max_in_flight
		or not reactive_lane_for(game, player, rules).is_empty()
	)

static func launch(
	game,
	rules: RuleConfig,
	player_id: int,
	decision: Dictionary
) -> Dictionary:
	if not rules.marching:
		return _result(player_id, "pass", "marching_disabled")

	var player = game.get_player(player_id)
	if player == null:
		return _invalid(player_id, "player_missing")

	if _is_pass(decision):
		return _result(player_id, "pass", "pass")

	var reactive_lane: String = reactive_lane_for(game, player, rules)
	if (
		player.marchers.size() >= rules.march_max_in_flight
		and reactive_lane.is_empty()
	):
		return _invalid(player_id, "marcher_limit")

	var source_zone: String = String(decision.get("source_zone", ""))
	var lane: String = String(decision.get("lane", ""))
	var card_id: String = String(decision.get("card", ""))
	if not reactive_lane.is_empty():
		lane = reactive_lane

	if not LANES.has(source_zone):
		return _invalid(player_id, "march_source_zone_invalid")
	if not LANES.has(lane):
		return _invalid(player_id, "march_lane_invalid")
	if _marcher_in_lane(player, lane) != null:
		return _invalid(player_id, "march_lane_occupied")

	var guards: Array = (
		player.lord_guards
		if source_zone == ZONE_LORD
		else player.castle_guards
	)
	var card_index: int = _find_card_index(guards, card_id)
	if card_index < 0:
		return _invalid(player_id, "march_card_missing")

	var card = guards[card_index]
	guards.remove_at(card_index)
	player.marchers.append({
		"card": card,
		"value": int(card.value),
		"lane": lane,
		"pos": 0,
	})

	return {
		"action": "march",
		"player_id": player_id,
		"reason": "",
		"source_zone": source_zone,
		"lane": lane,
		"card": _card_id(card),
		"reactive": not reactive_lane.is_empty(),
	}

static func advance(
	game,
	rules: RuleConfig
) -> Dictionary:
	var events: Array[Dictionary] = []

	if not rules.marching:
		return {
			"action": "march_advance",
			"enabled": false,
			"events": events,
			"terminal": false,
		}

	for player in game.players:
		for marcher in player.marchers:
			marcher["pos"] = int(marcher.get("pos", 0)) + 1

	for lane in LANES:
		var first = _marcher_in_lane(game.get_player(0), lane)
		var second = _marcher_in_lane(game.get_player(1), lane)
		if first == null or second == null:
			continue

		var first_marshal: bool = _is_marshal(first, rules)
		var second_marshal: bool = _is_marshal(second, rules)
		if ((first_marshal and _is_spy(second, rules))
				or (second_marshal and _is_spy(first, rules))):
			first["value"] = 0
			second["value"] = 0
			events.append({
				"type": "march_spy",
				"lane": lane,
			})
		elif first_marshal or second_marshal:
			events.append({
				"type": "march_evade",
				"lane": lane,
			})
		else:
			var first_damage: int = rules.march_damage
			var second_damage: int = rules.march_damage
			if _suit_advantage(_card_suit(second), _card_suit(first)):
				first_damage += rules.march_suit_bonus
			if _suit_advantage(_card_suit(first), _card_suit(second)):
				second_damage += rules.march_suit_bonus
			first["value"] = int(first.get("value", 0)) - first_damage
			second["value"] = int(second.get("value", 0)) - second_damage
			events.append({
				"type": "march_clash",
				"lane": lane,
				"first_damage": first_damage,
				"second_damage": second_damage,
			})

	for player in game.players:
		var survivors: Array[Dictionary] = []
		for marcher in player.marchers:
			var card = marcher.get("card", null)
			var value: int = int(marcher.get("value", 0))
			if value <= 0:
				game.discard.append(card)
				events.append({
					"type": "march_destroyed",
					"player_id": int(player.pid),
					"card": _card_id(card),
				})
				continue

			if int(marcher.get("pos", 0)) >= rules.march_steps:
				var scored: bool = value >= rules.march_threshold
				if scored:
					player.tears += 1
				game.discard.append(card)
				events.append({
					"type": "march_arrival",
					"player_id": int(player.pid),
					"card": _card_id(card),
					"scored": scored,
				})
				continue

			survivors.append(marcher)

		# PlayerState.marchers is Array[Dictionary]. Replacing it with a
		# generic Array at runtime is rejected by Godot, even when every item
		# is a Dictionary. Preserve the typed-array container instead.
		player.marchers.clear()
		for survivor: Dictionary in survivors:
			player.marchers.append(survivor)

	game.refresh_derived_values()
	var terminal: bool = ResolutionFinaleEngineData.check_win(game, rules)
	return {
		"action": "march_advance",
		"enabled": true,
		"events": events,
		"terminal": terminal,
	}


static func _marcher_in_lane(player, lane: String):
	if player == null:
		return null
	for marcher in player.marchers:
		if String(marcher.get("lane", "")) == lane:
			return marcher
	return null


static func _is_marshal(marcher: Dictionary, rules: RuleConfig) -> bool:
	var card = marcher.get("card", null)
	return (
		rules.march_exception_pair
		and card != null
		and String(card.suit) == "Vulture"
		and int(card.value) == 5
	)


static func _is_spy(marcher: Dictionary, rules: RuleConfig) -> bool:
	var card = marcher.get("card", null)
	return (
		rules.march_exception_pair
		and card != null
		and String(card.suit) == "Butcher"
		and int(card.value) == 1
	)


static func _suit_advantage(attacker_suit: String, defender_suit: String) -> bool:
	return String(SUIT_BEATS.get(attacker_suit, "")) == defender_suit


static func _card_suit(marcher: Dictionary) -> String:
	var card = marcher.get("card", null)
	return "" if card == null else String(card.suit)


static func _find_card_index(cards: Array, card_identifier: String) -> int:
	for index in range(cards.size()):
		if _card_id(cards[index]) == card_identifier:
			return index
	return -1


static func _is_pass(decision: Dictionary) -> bool:
	return String(decision.get("action", "pass")).to_lower() == "pass"


static func _card_id(card) -> String:
	return "" if card == null else "%s:%d" % [String(card.suit), int(card.value)]


static func _result(player_id: int, action: String, reason: String) -> Dictionary:
	return {
		"action": action,
		"player_id": player_id,
		"reason": reason,
		"source_zone": "",
		"lane": "",
		"card": "",
		"reactive": false,
	}

static func _invalid(player_id: int, reason: String) -> Dictionary:
	var result := _result(player_id, "invalid", reason)
	return result
