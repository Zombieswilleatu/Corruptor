class_name DevelopmentStartEngine
extends RefCounted


const DrawEngineData = preload(
	"res://Scripts/Sim/DrawEngine.gd"
)


static func resolve(
	game,
	rules: RuleConfig,
	random_source = null
) -> Dictionary:
	assert(
		game != null,
		"Development Start requires a GameState."
	)

	assert(
		rules != null,
		"Development Start requires RuleConfig."
	)

	var snare_events: Array[Dictionary] = []
	var gremory_draw_events: Array[Dictionary] = []
	var breach_draw_events: Array[Dictionary] = []

	# Orias — Snare resolves before all Development draws.
	for player in game.players:
		if (
			player.lord != "Orias"
			or not player.alive
		):
			continue

		var snare_event: Dictionary = (
			_resolve_orias_snare(
				game,
				player,
				rules
			)
		)

		snare_events.append(
			snare_event
		)

	# Gremory — Picking the Bones.
	for player in game.players:
		if (
			player.lord != "Gremory"
			or not player.alive
		):
			continue

		var opponent = game.get_opponent(
			int(
				player.pid
			)
		)

		assert(
			opponent != null,
			"Gremory Development draw requires an opponent."
		)

		var draw_count: int = 1

		if (
			not player.ruined_castles.is_empty()
			or not opponent.ruined_castles.is_empty()
		):
			draw_count += 1

		if not player.ruined_castles.is_empty():
			draw_count += 1

		var draw_results: Array[Dictionary] = []

		for _draw_index: int in range(
			draw_count
		):
			var draw_result: Dictionary = (
				DrawEngineData.draw_to_hand(
					game,
					player,
					rules,
					random_source,
					true
				)
			)

			draw_results.append(
				draw_result
			)

		gremory_draw_events.append({
			"player_id": int(
				player.pid
			),
			"requested_draws": draw_count,
			"draw_results": draw_results,
			"drawn_cards": _drawn_card_ids(
				draw_results
			),
		})

	# Gremory Breach — players with Ruins draw once.
	if game.breach == "Gremory":
		for player in game.players:
			if player.ruined_castles.is_empty():
				continue

			var draw_result: Dictionary = (
				DrawEngineData.draw_to_hand(
					game,
					player,
					rules,
					random_source,
					true
				)
			)

			breach_draw_events.append({
				"player_id": int(
					player.pid
				),
				"draw_result": draw_result,
			})

	game.refresh_derived_values()

	return {
		"action": "development_start",
		"snare_events": snare_events,
		"gremory_draw_events": (
			gremory_draw_events
		),
		"breach_draw_events": breach_draw_events,
	}


static func _resolve_orias_snare(
	game,
	orias,
	rules: RuleConfig
) -> Dictionary:
	var opponent = game.get_opponent(
		int(
			orias.pid
		)
	)

	assert(
		opponent != null,
		"Orias Snare requires an opponent."
	)

	var threat_before: int = int(
		orias.threat
	)

	if orias.threat >= 3:
		return {
			"player_id": int(
				orias.pid
			),
			"target_player_id": int(
				opponent.pid
			),
			"applied": false,
			"reason": "orias_threat_too_high",
			"threat_before": threat_before,
			"threat_after": int(
				orias.threat
			),
		}

	if (
		opponent.hand.size()
		+ opponent.garrison.size()
		< 2
	):
		return {
			"player_id": int(
				orias.pid
			),
			"target_player_id": int(
				opponent.pid
			),
			"applied": false,
			"reason": "target_has_too_few_cards",
			"threat_before": threat_before,
			"threat_after": int(
				orias.threat
			),
		}

	orias.threat = min(
		rules.max_threat,
		int(
			orias.threat
		) + 1
	)

	opponent.orias_snare_active = true

	return {
		"player_id": int(
			orias.pid
		),
		"target_player_id": int(
			opponent.pid
		),
		"applied": true,
		"reason": "",
		"threat_before": threat_before,
		"threat_after": int(
			orias.threat
		),
	}


static func _drawn_card_ids(
	draw_results: Array[Dictionary]
) -> Array[String]:
	var result: Array[String] = []

	for draw_result: Dictionary in draw_results:
		if not bool(
			draw_result.get(
				"drawn",
				false
			)
		):
			continue

		result.append(
			String(
				draw_result.get(
					"card",
					""
				)
			)
		)

	return result
