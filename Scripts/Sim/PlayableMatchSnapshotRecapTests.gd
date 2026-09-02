class_name PlayableMatchSnapshotRecapTests
extends RefCounted


const PlayableRoundControllerData = preload(
	"res://Prototype/PlayableRoundController.gd"
)

const PlayableMatchSnapshotData = preload(
	"res://Scripts/Sim/PlayableMatchSnapshot.gd"
)


static func run() -> Array[Dictionary]:
	return [
		_test_recap_preserves_round_rows(),
		_test_final_summary_is_compact_and_complete(),
	]


static func _controller():
	var controller = PlayableRoundControllerData.new()

	controller.start_match(
		"Valak",
		"Humbaba",
		1856146580
	)

	return controller


static func _test_recap_preserves_round_rows() -> Dictionary:
	var controller = _controller()

	var rows: Array = [
		{
			"round": 1,
			"summary": "Valak Hunt 8; Humbaba Ward 4.",
		},
		{
			"round": 2,
			"summary": "Valak Siege 9; Humbaba Hunt 6.",
		},
	]

	var recap: Dictionary = (
		PlayableMatchSnapshotData._match_recap(
			controller,
			rows
		)
	)

	var output_rows = recap.get(
		"rounds",
		[]
	)

	if String(recap.get("format", "")) != "compact-round-recap-v2":
		return _fail(
			"snapshot_recap_round_rows",
			"Compact recap format was not upgraded to v2."
		)

	if (
		typeof(
			output_rows
		) != TYPE_ARRAY
		or output_rows.size() != 2
	):
		return _fail(
			"snapshot_recap_round_rows",
			"Compact recap did not retain exactly the supplied round rows."
		)

	if int(
		recap.get(
			"round_count",
			-1
		)
	) != 2:
		return _fail(
			"snapshot_recap_round_rows",
			"Compact recap round_count is not 2."
		)

	return _pass(
		"snapshot_recap_round_rows"
	)


static func _test_final_summary_is_compact_and_complete() -> Dictionary:
	var controller = _controller()
	var game = controller.game

	var human = controller.get_human_player()
	var bot = controller.get_bot_player()

	human.souls = 13
	human.tears = 1
	human.threat = 4
	human.vacant_throne_rounds = 0

	bot.souls = 1
	bot.tears = 0
	bot.threat = 0
	bot.vacant_throne_rounds = 2

	game.winner = 0
	game.win_by = "Ritual"
	game.round = 7

	var recap: Dictionary = (
		PlayableMatchSnapshotData._match_recap(
			controller,
			[]
		)
	)

	var final_raw = recap.get(
		"final",
		{}
	)

	if typeof(
		final_raw
	) != TYPE_DICTIONARY:
		return _fail(
			"snapshot_recap_final",
			"Final recap is not a Dictionary."
		)

	var final: Dictionary = final_raw

	if (
		int(
			final.get(
				"round",
				-1
			)
		) != 7
		or int(
			final.get(
				"winner_pid",
				-1
			)
		) != 0
		or String(
			final.get(
				"winner_lord",
				""
			)
		) != "Valak"
		or String(
			final.get(
				"win_by",
				""
			)
		) != "Ritual"
	):
		return _fail(
			"snapshot_recap_final",
			"Final recap omitted round/winner/win_by truth."
		)

	var players = final.get(
		"players",
		[]
	)

	if (
		typeof(
			players
		) != TYPE_ARRAY
		or players.size() != 2
	):
		return _fail(
			"snapshot_recap_final",
			"Final recap did not contain both compact player states."
		)

	var player_zero: Dictionary = players[0]

	for key: String in [
		"lord",
		"alive",
		"souls",
		"tears",
		"threat",
		"hand_count",
		"garrison_count",
		"lord_guard_count",
		"castle_guard_count",
		"castles",
		"ruined_castles",
		"profaned_castles",
		"castle_integrity",
		"vacant_throne_rounds",
	]:
		if not player_zero.has(
			key
		):
			return _fail(
				"snapshot_recap_final",
				"Compact player state omitted %s." % key
			)

	return _pass(
		"snapshot_recap_final"
	)


static func _pass(
	name: String
) -> Dictionary:
	return {
		"name": name,
		"passed": true,
		"detail": "",
	}


static func _fail(
	name: String,
	detail: String
) -> Dictionary:
	return {
		"name": name,
		"passed": false,
		"detail": detail,
	}
