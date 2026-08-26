class_name UI2ActivityRail
extends PanelContainer


const MAX_ENTRIES: int = 90


var title_label: Label = null
var body_label: RichTextLabel = null

var entries: Array[String] = []
var bound_controller_id: int = -1
var bound_round: int = -1
var last_stage: String = ""
var consumed_event_count: int = 0
var last_state: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(164, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		8
	)
	add_child(box)

	title_label = Label.new()
	title_label.text = "ACTIVITY"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override(
		"font_size",
		16
	)
	box.add_child(title_label)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = false
	body_label.scroll_active = true
	body_label.scroll_following = true
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override(
		"normal_font_size",
		11
	)
	box.add_child(body_label)


func bind_controller(
	controller,
	stage_text: String
) -> void:
	if controller == null or controller.game == null:
		return

	var controller_id: int = int(
		controller.get_instance_id()
	)

	if controller_id != bound_controller_id:
		_reset_for_controller(
			controller,
			controller_id
		)

	var game = controller.game
	var current_round: int = int(game.round)

	if current_round != bound_round:
		bound_round = current_round
		consumed_event_count = 0
		_append(
			"\n[b]ROUND %d[/b]"
			% current_round
		)

	_ingest_controller_events(
		controller
	)

	var current_state: Dictionary = _state_snapshot(
		controller
	)

	if not last_state.is_empty():
		_append_state_deltas(
			last_state,
			current_state
		)

	last_state = current_state

	var normalized_stage: String = stage_text.replace(
		" ",
		"_"
	).to_upper()

	if normalized_stage != last_stage:
		last_stage = normalized_stage
		_append(
			"[color=#c8b36a]→ %s[/color]"
			% _friendly_stage(
				normalized_stage
			)
		)

	_render()


func _reset_for_controller(
	controller,
	controller_id: int
) -> void:
	entries.clear()
	bound_controller_id = controller_id
	bound_round = -1
	last_stage = ""
	consumed_event_count = 0
	last_state.clear()

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	if human != null and bot != null:
		_append(
			"[b]NEW MATCH[/b]\n%s vs %s"
			% [
				String(human.lord).to_upper(),
				String(bot.lord).to_upper(),
			]
		)


func _ingest_controller_events(
	controller
) -> void:
	var raw_events = controller.events

	if typeof(raw_events) != TYPE_ARRAY:
		return

	var event_array: Array = raw_events

	if event_array.size() < consumed_event_count:
		consumed_event_count = 0

	while consumed_event_count < event_array.size():
		var raw_event = event_array[
			consumed_event_count
		]
		consumed_event_count += 1

		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		var event: Dictionary = raw_event
		_append(
			_event_line(
				event
			)
		)


func _event_line(
	event: Dictionary
) -> String:
	var phase_name: String = String(
		event.get(
			"phase",
			event.get(
				"name",
				"event"
			)
		)
	)

	var label_text: String = _friendly_stage(
		phase_name
	)
	var detail: String = ""

	if phase_name not in [
		"commitment",
		"reveal",
	]:
		var data = event.get(
			"data",
			{}
		)
		detail = _human_result_detail(
			data
		)

	return (
		"• [color=#9aa6b8]%s[/color]%s"
		% [
			label_text,
			(
				" · %s" % detail
				if not detail.is_empty()
				else ""
			),
		]
	)


func _human_result_detail(
	value
) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value

		if (
			dictionary.has("player_id")
			and int(dictionary.get("player_id", -1)) == 0
		):
			var direct: String = _format_result(
				dictionary
			)
			if not direct.is_empty():
				return direct

		for key in [
			"results",
			"result",
			"actions",
		]:
			if not dictionary.has(key):
				continue
			var nested: String = _human_result_detail(
				dictionary[key]
			)
			if not nested.is_empty():
				return nested

		return ""

	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			var nested: String = _human_result_detail(
				entry
			)
			if not nested.is_empty():
				return nested

	return ""


func _format_result(
	result: Dictionary
) -> String:
	var action_name: String = String(
		result.get(
			"action",
			""
		)
	)

	match action_name:
		"swap":
			return "YOU %s → %s" % [
				String(result.get("give", "")),
				String(result.get("take", "")),
			]

		"repair":
			var castle_name: String = String(
				result.get(
					"castle",
					"Castle"
				)
			)
			if result.has("integrity_after"):
				return "YOU repaired %s %d→%d" % [
					castle_name,
					int(result.get("integrity_before", 0)),
					int(result.get("integrity_after", 0)),
				]
			return "YOU repaired %s" % castle_name

		"construct":
			var castle_name: String = String(
				result.get(
					"castle",
					"Castle"
				)
			)
			if result.has("progress_after"):
				return "YOU built %s %d→%d" % [
					castle_name,
					int(result.get("progress_before", 0)),
					int(result.get("progress_after", 0)),
				]
			return "YOU constructed %s" % castle_name

		"march":
			return "YOU launched %s → %s" % [
				String(
					result.get(
						"card",
						"Guard"
					)
				),
				String(
					result.get(
						"lane",
						"lane"
					)
				),
			]

		"pass":
			return "YOU passed"

	return ""


func _state_snapshot(
	controller
) -> Dictionary:
	var game = controller.game
	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	return {
		"veil": int(
			game.calculate_veil_total()
		),
		"neutral_tears": int(
			game.neutral_tears
		),
		"breach": String(
			game.breach
		),
		"human": _player_snapshot(
			human
		),
		"bot": _player_snapshot(
			bot
		),
	}


func _player_snapshot(
	player
) -> Dictionary:
	if player == null:
		return {}

	var integrity: Dictionary = {}

	for castle_name in player.castles:
		var name: String = String(
			castle_name
		)
		integrity[name] = int(
			player.castle_integrity.get(
				name,
				0
			)
		)

	return {
		"lord": String(player.lord),
		"alive": bool(player.alive),
		"souls": int(player.souls),
		"tears": int(player.tears),
		"threat": int(player.threat),
		"hand": int(player.hand.size()),
		"garrison": int(player.garrison.size()),
		"lord_guards": int(player.lord_guards.size()),
		"castle_guards": int(player.castle_guards.size()),
		"integrity": integrity,
		"ruined": player.ruined_castles.duplicate(),
		"profaned": player.profaned_castles.duplicate(),
	}


func _append_state_deltas(
	before: Dictionary,
	after: Dictionary
) -> void:
	_append_scalar_delta(
		"VEIL",
		int(before.get("veil", 0)),
		int(after.get("veil", 0))
	)

	_append_scalar_delta(
		"NEUTRAL TEARS",
		int(before.get("neutral_tears", 0)),
		int(after.get("neutral_tears", 0))
	)

	var before_breach: String = String(
		before.get(
			"breach",
			""
		)
	)
	var after_breach: String = String(
		after.get(
			"breach",
			""
		)
	)

	if before_breach != after_breach:
		_append(
			"BREACH %s → %s"
			% [
				(
					before_breach
					if not before_breach.is_empty()
					else "—"
				),
				(
					after_breach
					if not after_breach.is_empty()
					else "—"
				),
			]
		)

	_append_player_deltas(
		"YOU",
		before.get("human", {}),
		after.get("human", {})
	)

	_append_player_deltas(
		"ENEMY",
		before.get("bot", {}),
		after.get("bot", {})
	)


func _append_player_deltas(
	owner: String,
	before_value,
	after_value
) -> void:
	if (
		typeof(before_value) != TYPE_DICTIONARY
		or typeof(after_value) != TYPE_DICTIONARY
	):
		return

	var before: Dictionary = before_value
	var after: Dictionary = after_value

	for stat_name in [
		"souls",
		"tears",
		"threat",
		"hand",
		"garrison",
		"lord_guards",
		"castle_guards",
	]:
		var old_value: int = int(
			before.get(
				stat_name,
				0
			)
		)
		var new_value: int = int(
			after.get(
				stat_name,
				0
			)
		)

		if old_value == new_value:
			continue

		_append(
			"%s %s %d→%d"
			% [
				owner,
				stat_name.replace("_", " ").to_upper(),
				old_value,
				new_value,
			]
		)

	var was_alive: bool = bool(
		before.get(
			"alive",
			false
		)
	)
	var is_alive: bool = bool(
		after.get(
			"alive",
			false
		)
	)

	if was_alive != is_alive:
		_append(
			"%s LORD %s"
			% [
				owner,
				(
					"RETURNED"
					if is_alive
					else "BANISHED"
				),
			]
		)

	_append_castle_deltas(
		owner,
		before,
		after
	)


func _append_castle_deltas(
	owner: String,
	before: Dictionary,
	after: Dictionary
) -> void:
	var before_integrity = before.get(
		"integrity",
		{}
	)
	var after_integrity = after.get(
		"integrity",
		{}
	)

	if (
		typeof(before_integrity) != TYPE_DICTIONARY
		or typeof(after_integrity) != TYPE_DICTIONARY
	):
		return

	var old_map: Dictionary = before_integrity
	var new_map: Dictionary = after_integrity

	for castle_name_value in old_map.keys():
		var castle_name: String = String(
			castle_name_value
		)

		if new_map.has(castle_name):
			var old_integrity: int = int(
				old_map[castle_name]
			)
			var new_integrity: int = int(
				new_map[castle_name]
			)

			if old_integrity != new_integrity:
				_append(
					"%s %s %d→%d"
					% [
						owner,
						castle_name,
						old_integrity,
						new_integrity,
					]
				)
			continue

		if after.get("ruined", []).has(
			castle_name
		):
			_append(
				"%s %s RUINED"
				% [
					owner,
					castle_name,
				]
			)
		elif after.get("profaned", []).has(
			castle_name
		):
			_append(
				"%s %s PROFANED"
				% [
					owner,
					castle_name,
				]
			)

	for castle_name_value in new_map.keys():
		var castle_name: String = String(
			castle_name_value
		)

		if old_map.has(
			castle_name
		):
			continue

		_append(
			"%s %s CONSTRUCTED · %d"
			% [
				owner,
				castle_name,
				int(new_map[castle_name]),
			]
		)


func _append_scalar_delta(
	label_text: String,
	before_value: int,
	after_value: int
) -> void:
	if before_value == after_value:
		return

	_append(
		"%s %d→%d"
		% [
			label_text,
			before_value,
			after_value,
		]
	)


func _append(
	text: String
) -> void:
	if text.is_empty():
		return

	entries.append(
		text
	)

	while entries.size() > MAX_ENTRIES:
		entries.pop_front()


func _render() -> void:
	if body_label == null:
		return

	body_label.text = "\n".join(
		entries
	)


func _friendly_stage(
	stage_text: String
) -> String:
	return stage_text.replace(
		"_",
		" "
	).capitalize()
