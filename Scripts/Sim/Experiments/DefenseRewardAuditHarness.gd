# DEFENSE_REWARD_AUDIT_V0
class_name DefenseRewardAuditHarness
extends RefCounted

const Setup = preload("res://Scripts/Sim/SeededGameSetup.gd")
const PolicyData = preload(
	"res://Scripts/Sim/Experiments/DefenseCulpabilityPolicy.gd"
)
const GameEngine = preload(
	"res://Scripts/Sim/Experiments/DefenseCulpabilityGameEngine.gd"
)

const LORDS: Array[String] = [
	"Orias",
	"Deimos",
	"Valak",
	"Kroni",
	"Kalligan",
	"Gremory",
	"Odradek",
	"Kanifous",
	"Humbaba",
]

const SMOKE_MATCHUPS: Array[Array] = [
	["Valak", "Kalligan"],
	["Valak", "Humbaba"],
	["Orias", "Humbaba"],
	["Kroni", "Odradek"],
	["Gremory", "Kanifous"],
	["Deimos", "Kalligan"],
]


static func run(
	rules: RuleConfig,
	seeds: int = 2,
	base_seed: int = 799685594,
	panel: String = "smoke",
	progress: Callable = Callable()
) -> Dictionary:
	var matchups: Array = (
		_all_matchups()
		if panel == "all"
		else SMOKE_MATCHUPS.duplicate(true)
	)

	var by_lord: Dictionary = {}
	for lord_name in LORDS:
		by_lord[lord_name] = _blank_lord(lord_name)

	var matchup_rows: Array[Dictionary] = []
	var total_games: int = matchups.size() * seeds * 2
	var completed: int = 0

	for matchup in matchups:
		var a_lord: String = String(matchup[0])
		var b_lord: String = String(matchup[1])

		var row: Dictionary = {
			"a": a_lord,
			"b": b_lord,
			"games": 0,
			"invalid": 0,
			"a_wins": 0,
			"b_wins": 0,
			"win_by": {},
		}

		for seed_index in range(seeds):
			var seed: int = base_seed + seed_index * 104729

			for cross in range(2):
				var a_pid: int = 0 if cross == 0 else 1
				var b_pid: int = 1 - a_pid
				var l0: String = a_lord if a_pid == 0 else b_lord
				var l1: String = b_lord if a_pid == 0 else a_lord

				var setup: Dictionary = Setup.setup_locked_game(
					l0,
					l1,
					seed,
					rules
				)

				var game = setup.get("game")
				var rng = setup.get("rng")

				if game == null or rng == null:
					row["invalid"] = int(row["invalid"]) + 1
					completed += 1
					_emit_progress(
						progress,
						completed,
						total_games,
						a_lord,
						b_lord,
						seed,
						cross,
						-1
					)
					continue

				var policy = PolicyData.new(
					{
						0: "production",
						1: "production",
					},
					4,
					10
				)

				var result: Dictionary = GameEngine.resolve_game(
					game,
					rules,
					rng,
					policy
				)

				if String(result.get("action", "")) == "invalid":
					row["invalid"] = int(row["invalid"]) + 1
					completed += 1
					_emit_progress(
						progress,
						completed,
						total_games,
						a_lord,
						b_lord,
						seed,
						cross,
						int(game.round)
					)
					continue

				row["games"] = int(row["games"]) + 1

				var winner: int = int(
					result.get("winner", game.winner)
				)

				if winner == a_pid:
					row["a_wins"] = int(row["a_wins"]) + 1
				elif winner == b_pid:
					row["b_wins"] = int(row["b_wins"]) + 1

				var win_by: String = String(
					result.get("win_by", game.win_by)
				)
				var wb: Dictionary = row["win_by"]
				wb[win_by] = int(wb.get(win_by, 0)) + 1

				_accumulate_player(
					by_lord[a_lord],
					game,
					result,
					rules,
					a_pid,
					b_pid
				)

				_accumulate_player(
					by_lord[b_lord],
					game,
					result,
					rules,
					b_pid,
					a_pid
				)

				completed += 1
				_emit_progress(
					progress,
					completed,
					total_games,
					a_lord,
					b_lord,
					seed,
					cross,
					int(result.get("final_round", game.round))
				)

		matchup_rows.append(_finish_matchup(row))

	var lord_rows: Array[Dictionary] = []
	for lord_name in LORDS:
		var raw: Dictionary = by_lord[lord_name]
		if int(raw["games"]) <= 0:
			continue
		lord_rows.append(_finish_lord(raw))

	return {
		"format": "defense-reward-audit-v0",
		"panel": panel,
		"seeds": seeds,
		"base_seed": base_seed,
		"total_games": completed,
		"matchups": matchup_rows,
		"lords": lord_rows,
		"read": {
			"question_1": (
				"Do production bots repeatedly exhibit general strategic "
				+ "blunder signatures?"
			),
			"question_2": (
				"Does defensive investment convert into progress and wins, "
				+ "or mostly into starvation and delay?"
			),
			"note": "V0 is observational only. No bot behavior is changed.",
		},
	}


static func _all_matchups() -> Array:
	var out: Array = []
	for i in range(LORDS.size()):
		for j in range(i + 1, LORDS.size()):
			out.append([LORDS[i], LORDS[j]])
	return out


static func _blank_lord(lord_name: String) -> Dictionary:
	return {
		"lord": lord_name,
		"games": 0,
		"wins": 0,
		"rounds": 0,
		"final_souls": 0,
		"final_tears": 0,
		"commit_rounds": 0,
		"zero_commit": 0,
		"low_commit": 0,
		"starved": 0,
		"wards": 0,
		"ward_miss": 0,
		"ward_uncontested": 0,
		"offense_rounds": 0,
		"defense_rounds": 0,
		"defense_value": 0,
		"def_starve": 0,
		"def_events": 0,
		"def_to_progress_2r": 0,
		"def_to_offense_2r": 0,
		"def_to_win": 0,
		"ward_events": 0,
		"ward_to_progress_2r": 0,
		"ward_to_offense_2r": 0,
		"ward_to_win": 0,
		"latent_dom_losses": 0,
		"win_by": {},
	}


static func _accumulate_player(
	a: Dictionary,
	game,
	result: Dictionary,
	rules: RuleConfig,
	pid: int,
	opponent_pid: int
) -> void:
	a["games"] = int(a["games"]) + 1

	var winner: int = int(result.get("winner", game.winner))
	if winner == pid:
		a["wins"] = int(a["wins"]) + 1

	var final_round: int = int(result.get("final_round", game.round))
	a["rounds"] = int(a["rounds"]) + final_round

	var win_by: String = String(result.get("win_by", game.win_by))
	if winner == pid:
		var wb: Dictionary = a["win_by"]
		wb[win_by] = int(wb.get(win_by, 0)) + 1

	var player = game.get_player(pid)
	if player != null:
		a["final_souls"] = int(a["final_souls"]) + int(player.souls)
		a["final_tears"] = int(a["final_tears"]) + int(player.tears)

		if winner != pid:
			var veil_total: int = int(game.calculate_veil_total())
			if (
				int(player.tears) >= int(rules.dominion_requirement)
				and veil_total >= int(rules.dominion_track) - 1
			):
				a["latent_dom_losses"] = int(a["latent_dom_losses"]) + 1

	var rounds = result.get("rounds", [])
	if typeof(rounds) != TYPE_ARRAY:
		return

	var telemetry: Array[Dictionary] = []

	for raw_round in rounds:
		if typeof(raw_round) != TYPE_DICTIONARY:
			continue

		var phases: Dictionary = _dict(raw_round.get("phases", {}))
		var commitment: Dictionary = _dict(phases.get("commitment", {}))
		var cres: Dictionary = _dict(commitment.get("result", {}))

		var own: Dictionary = _row(cres.get("players", []), pid)
		var opp: Dictionary = _row(cres.get("players", []), opponent_pid)

		var action: String = String(own.get("action", ""))
		var commitment_value: int = int(own.get("committed_value", 0))
		var opponent_action: String = String(opp.get("action", ""))

		var opponent_target: String = ""
		if opponent_action == "Hunt":
			opponent_target = "Lord"
		elif opponent_action == "Siege":
			opponent_target = "Castle"

		var pre: Dictionary = _dict(
			phases.get("culpability_precommit", {})
		)
		var own_pre: Dictionary = _state_row(pre, pid)

		var repair_value: int = _repair_value(phases, pid)
		var deploy: Dictionary = _deploy_value(phases, pid)
		var guard_value: int = (
			int(deploy.get("hand", 0))
			+ int(deploy.get("garrison", 0))
		)

		var ward_value: int = commitment_value if action == "Ward" else 0
		var defense_value: int = repair_value + guard_value + ward_value

		var starved: bool = (
			not own_pre.is_empty()
			and (
				int(own_pre.get("hand_count", 0)) < 4
				or int(own_pre.get("hand_value", 0)) < 10
			)
		)

		var ward_miss: bool = false
		var ward_uncontested: bool = false

		if action == "Ward":
			a["wards"] = int(a["wards"]) + 1
			var choice: Dictionary = _pick(
				_dict(commitment.get("choices", {})),
				pid
			)
			var zone: String = String(
				choice.get(
					"target_type",
					own.get("ward_target", "")
				)
			)

			if opponent_target.is_empty():
				ward_uncontested = true
				a["ward_uncontested"] = (
					int(a["ward_uncontested"]) + 1
				)
			elif zone != opponent_target:
				ward_miss = true
				a["ward_miss"] = int(a["ward_miss"]) + 1

		if not own.is_empty():
			a["commit_rounds"] = int(a["commit_rounds"]) + 1

			if commitment_value <= 0:
				a["zero_commit"] = int(a["zero_commit"]) + 1
			if commitment_value <= 4:
				a["low_commit"] = int(a["low_commit"]) + 1

			if action in ["Hunt", "Siege"]:
				a["offense_rounds"] = int(a["offense_rounds"]) + 1

			if action == "Ward" or defense_value >= 6:
				a["defense_rounds"] = int(a["defense_rounds"]) + 1

		if starved:
			a["starved"] = int(a["starved"]) + 1

		a["defense_value"] = int(a["defense_value"]) + defense_value

		if defense_value >= 6 and commitment_value <= 4:
			a["def_starve"] = int(a["def_starve"]) + 1

		var end_state: Dictionary = _dict(
			phases.get("culpability_end_state", {})
		)
		var own_end: Dictionary = _state_row(end_state, pid)

		var souls: int = int(own_end.get("souls", 0))
		var tears: int = int(own_end.get("tears", 0))

		var contested: bool = opponent_action in ["Hunt", "Siege"]
		var substantial_defense: bool = (
			defense_value >= 6
			and contested
		)
		var meaningful_ward: bool = (
			action == "Ward"
			and contested
			and not ward_miss
		)

		telemetry.append({
			"round": int(raw_round.get("round", telemetry.size() + 1)),
			"offense": (
				action in ["Hunt", "Siege"]
				and commitment_value >= 8
			),
			"souls": souls,
			"tears": tears,
			"substantial_defense": substantial_defense,
			"meaningful_ward": meaningful_ward,
			"ward_uncontested": ward_uncontested,
		})

	for index in range(telemetry.size()):
		var event: Dictionary = telemetry[index]
		var is_defense: bool = bool(
			event.get("substantial_defense", false)
		)
		var is_ward: bool = bool(
			event.get("meaningful_ward", false)
		)

		if not is_defense and not is_ward:
			continue

		var base_souls: int = int(event.get("souls", 0))
		var base_tears: int = int(event.get("tears", 0))

		var converted_progress: bool = false
		var converted_offense: bool = false

		for future_index in range(
			index + 1,
			mini(telemetry.size(), index + 3)
		):
			var future: Dictionary = telemetry[future_index]

			if bool(future.get("offense", false)):
				converted_offense = true

			if (
				int(future.get("souls", 0)) > base_souls
				or int(future.get("tears", 0)) > base_tears
			):
				converted_progress = true

		if is_defense:
			a["def_events"] = int(a["def_events"]) + 1
			if converted_progress:
				a["def_to_progress_2r"] = (
					int(a["def_to_progress_2r"]) + 1
				)
			if converted_offense:
				a["def_to_offense_2r"] = (
					int(a["def_to_offense_2r"]) + 1
				)
			if winner == pid:
				a["def_to_win"] = int(a["def_to_win"]) + 1

		if is_ward:
			a["ward_events"] = int(a["ward_events"]) + 1
			if converted_progress:
				a["ward_to_progress_2r"] = (
					int(a["ward_to_progress_2r"]) + 1
				)
			if converted_offense:
				a["ward_to_offense_2r"] = (
					int(a["ward_to_offense_2r"]) + 1
				)
			if winner == pid:
				a["ward_to_win"] = int(a["ward_to_win"]) + 1


static func _finish_lord(a: Dictionary) -> Dictionary:
	var games: int = maxi(1, int(a["games"]))

	return {
		"lord": String(a["lord"]),
		"games": int(a["games"]),
		"win_rate": _rate(int(a["wins"]), int(a["games"])),
		"avg_rounds": float(a["rounds"]) / float(games),
		"avg_final_souls": float(a["final_souls"]) / float(games),
		"avg_final_tears": float(a["final_tears"]) / float(games),
		"zero_commit_rate": _rate(
			int(a["zero_commit"]),
			int(a["commit_rounds"])
		),
		"low_commit_rate": _rate(
			int(a["low_commit"]),
			int(a["commit_rounds"])
		),
		"starved_rate": _rate(
			int(a["starved"]),
			int(a["commit_rounds"])
		),
		"ward_miss_rate": _rate(int(a["ward_miss"]), int(a["wards"])),
		"ward_uncontested_rate": _rate(
			int(a["ward_uncontested"]),
			int(a["wards"])
		),
		"offense_round_rate": _rate(
			int(a["offense_rounds"]),
			int(a["commit_rounds"])
		),
		"defense_round_rate": _rate(
			int(a["defense_rounds"]),
			int(a["commit_rounds"])
		),
		"defense_value_per_game": (
			float(a["defense_value"]) / float(games)
		),
		"defense_starvation_per_game": (
			float(a["def_starve"]) / float(games)
		),
		"defense_events": int(a["def_events"]),
		"defense_to_progress_2r_rate": _rate(
			int(a["def_to_progress_2r"]),
			int(a["def_events"])
		),
		"defense_to_offense_2r_rate": _rate(
			int(a["def_to_offense_2r"]),
			int(a["def_events"])
		),
		"defense_to_win_rate": _rate(
			int(a["def_to_win"]),
			int(a["def_events"])
		),
		"ward_events": int(a["ward_events"]),
		"ward_to_progress_2r_rate": _rate(
			int(a["ward_to_progress_2r"]),
			int(a["ward_events"])
		),
		"ward_to_offense_2r_rate": _rate(
			int(a["ward_to_offense_2r"]),
			int(a["ward_events"])
		),
		"ward_to_win_rate": _rate(
			int(a["ward_to_win"]),
			int(a["ward_events"])
		),
		"latent_dominion_losses": int(a["latent_dom_losses"]),
		"win_by": a["win_by"].duplicate(true),
	}


static func _finish_matchup(a: Dictionary) -> Dictionary:
	var games: int = int(a["games"])
	return {
		"a": String(a["a"]),
		"b": String(a["b"]),
		"games": games,
		"invalid": int(a["invalid"]),
		"a_win_rate": _rate(int(a["a_wins"]), games),
		"b_win_rate": _rate(int(a["b_wins"]), games),
		"win_by": a["win_by"].duplicate(true),
	}


static func report_text(result: Dictionary) -> String:
	var lines: PackedStringArray = []

	lines.append("CORRUPTOR - DEFENSE REWARD / BOT STRATEGY AUDIT V0")
	lines.append("=================================================")
	lines.append(
		"Panel %s | seeds %d | crossed seats | %d games"
		% [
			String(result.get("panel", "")),
			int(result.get("seeds", 0)),
			int(result.get("total_games", 0)),
		]
	)
	lines.append("")
	lines.append(
		"LORD       G    WR   ZERO  STARVE  WMISS  WEMPTY  DEF/G  D->PROG D->OFF D->WIN  LATDOM"
	)

	for raw in result.get("lords", []):
		var x: Dictionary = raw
		lines.append(
			"%-9s %3d %5.1f %6.1f %7.1f %6.1f %7.1f %6.1f %7.1f %6.1f %6.1f %7d"
			% [
				String(x["lord"]),
				int(x["games"]),
				float(x["win_rate"]),
				float(x["zero_commit_rate"]),
				float(x["starved_rate"]),
				float(x["ward_miss_rate"]),
				float(x["ward_uncontested_rate"]),
				float(x["defense_value_per_game"]),
				float(x["defense_to_progress_2r_rate"]),
				float(x["defense_to_offense_2r_rate"]),
				float(x["defense_to_win_rate"]),
				int(x["latent_dominion_losses"]),
			]
		)

	lines.append("")
	lines.append(
		"D->PROG/OFF/WIN = contested substantial defensive investment "
		+ "(>=6 face this round) converting within 2 rounds / eventual win."
	)
	lines.append(
		"WMISS = WARD picked wrong attacked zone. "
		+ "WEMPTY = WARD when opponent did not Hunt/Siege."
	)
	lines.append(
		"STARVE = pre-Commitment hand <4 cards OR <10 raw face."
	)
	lines.append("")
	lines.append("MATCHUPS")

	for raw in result.get("matchups", []):
		var m: Dictionary = raw
		lines.append(
			"  %-9s vs %-9s  %5.1f / %5.1f  G=%d invalid=%d"
			% [
				String(m["a"]),
				String(m["b"]),
				float(m["a_win_rate"]),
				float(m["b_win_rate"]),
				int(m["games"]),
				int(m["invalid"]),
			]
		)

	lines.append("")
	lines.append(
		"V0 IS OBSERVATIONAL: production bot behavior is unchanged."
	)
	lines.append(
		"Next: layer one shared Smart Core over every Lord and compare "
		+ "paired seeds without forcing one aggressive or defensive style."
	)

	return "\n".join(lines)


static func _emit_progress(
	progress: Callable,
	completed: int,
	total: int,
	a_lord: String,
	b_lord: String,
	seed: int,
	cross: int,
	final_round: int
) -> void:
	if not progress.is_valid():
		return

	progress.call({
		"completed": completed,
		"total": total,
		"a": a_lord,
		"b": b_lord,
		"seed": seed,
		"cross": cross,
		"round": final_round,
	})


static func _dict(x) -> Dictionary:
	return x if typeof(x) == TYPE_DICTIONARY else {}


static func _row(rows, pid: int) -> Dictionary:
	if typeof(rows) != TYPE_ARRAY:
		return {}
	for raw in rows:
		if (
			typeof(raw) == TYPE_DICTIONARY
			and int(raw.get("player_id", -1)) == pid
		):
			return raw
	return {}


static func _state_row(s: Dictionary, pid: int) -> Dictionary:
	var rows = s.get("players", [])
	if typeof(rows) != TYPE_ARRAY:
		return {}
	for raw in rows:
		if (
			typeof(raw) == TYPE_DICTIONARY
			and int(raw.get("pid", -1)) == pid
		):
			return raw
	return {}


static func _pick(d: Dictionary, pid: int) -> Dictionary:
	var x = d.get(pid, d.get(str(pid), {}))
	return x if typeof(x) == TYPE_DICTIONARY else {}


static func _repair_value(phases: Dictionary, pid: int) -> int:
	var repair: Dictionary = _dict(phases.get("repair", {}))
	for raw in repair.get("results", []):
		if (
			typeof(raw) == TYPE_DICTIONARY
			and int(raw.get("player_id", -1)) == pid
		):
			return int(
				raw.get(
					"paid_total",
					raw.get("payment_total", 0)
				)
			)
	return 0


static func _deploy_value(phases: Dictionary, pid: int) -> Dictionary:
	var out: Dictionary = {"hand": 0, "garrison": 0}
	var deploy: Dictionary = _dict(phases.get("deploy", {}))

	for raw in deploy.get("results", []):
		if (
			typeof(raw) != TYPE_DICTIONARY
			or int(raw.get("player_id", -1)) != pid
		):
			continue

		for mraw in raw.get("moves", []):
			if (
				typeof(mraw) != TYPE_DICTIONARY
				or String(mraw.get("action", "")) != "move"
			):
				continue

			var value: int = _face(String(mraw.get("card", "")))
			var source: String = String(mraw.get("source", ""))

			if source == "Hand":
				out["hand"] = int(out["hand"]) + value
			elif source == "Garrison":
				out["garrison"] = int(out["garrison"]) + value

		break

	return out


static func _face(card_id: String) -> int:
	var parts: PackedStringArray = card_id.split(":")
	return (
		int(parts[parts.size() - 1])
		if parts.size() >= 2
		else 0
	)


static func _rate(n: int, d: int) -> float:
	return 0.0 if d <= 0 else 100.0 * float(n) / float(d)
