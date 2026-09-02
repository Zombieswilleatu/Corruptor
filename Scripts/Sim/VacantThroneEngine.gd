class_name VacantThroneEngine
extends RefCounted


const GRACE_ROUNDS: int = 2


static func resolve_end_round(
	game,
	rules: RuleConfig
) -> Dictionary:
	var events: Array[Dictionary] = []

	if game == null:
		return {
			"action": "vacant_throne",
			"reason": "game_missing",
			"events": events,
			"winner": -1,
			"win_by": "",
		}

	if int(game.winner) >= 0:
		return {
			"action": "vacant_throne",
			"reason": "game_already_terminal",
			"events": events,
			"winner": int(game.winner),
			"win_by": String(game.win_by),
		}

	for player in game.players:
		var player_id: int = int(player.pid)
		var before: int = int(
			player.vacant_throne_rounds
		)
		var after: int = before
		var soul_gain: int = 0
		var soul_recipient: int = -1
		var reason: String = ""

		# A round is Vacant only if the player had no living Lord at any
		# point in the entire round. The Banishing/removal round itself
		# therefore never counts.
		if (
			bool(player.alive)
			or bool(player.lord_present_this_round)
		):
			after = 0
			reason = "lord_present_this_round"
		else:
			after = before + 1
			reason = "vacant_round"

			if after > GRACE_ROUNDS:
				var opponent = game.get_opponent(
					player_id
				)

				if opponent != null:
					opponent.souls += 1
					soul_gain = 1
					soul_recipient = int(
						opponent.pid
					)

					# Ritual victory keeps the existing living-Lord gate.
					if (
						int(game.winner) < 0
						and bool(opponent.alive)
						and int(opponent.souls)
						>= int(rules.win_souls)
					):
						game.winner = int(
							opponent.pid
						)
						game.win_by = "Ritual"

		player.vacant_throne_rounds = after

		events.append({
			"player_id": player_id,
			"lord": String(player.lord),
			"alive_at_end": bool(player.alive),
			"lord_present_this_round": bool(
				player.lord_present_this_round
			),
			"vacant_rounds_before": before,
			"vacant_rounds_after": after,
			"grace_rounds": GRACE_ROUNDS,
			"soul_gain": soul_gain,
			"soul_recipient": soul_recipient,
			"reason": reason,
		})

	game.refresh_derived_values()

	return {
		"action": "vacant_throne",
		"reason": "",
		"events": events,
		"winner": int(game.winner),
		"win_by": String(game.win_by),
	}
