extends "res://Scripts/Sim/U13GameConductor.gd"

# Frozen e4d9501 flow access for exact parity and execution timing.

func to_planning(random_choices: bool = false) -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	if is_finished():
		return outcome()
	while _owner.next_hook() != Timeline.SUBMISSION_LOCK:
		if _owner.next_hook().is_empty():
			return outcome() if is_finished() else Data.invalid("game_round_complete")
		var pending: Dictionary = _owner.player_view(0, 0).world.game_economy.stockpile_pending
		if not pending.is_empty():
			var pid: int = pending.player_id
			if not random_choices:
				return {"action": "game_draw_choice", "player_id": pid}
			var offered: Array = _owner.player_view(pid, 0).world.game_economy.stockpile_pending.card_ids
			var index: int = int(Economy.Rng.draw(_owner.rng_seed(), "STOCKPILE_RANDOM_V1", "%d:%d" % [_owner.round_number(), pid], 0, offered.size()).value)
			var selected: Dictionary = choose_stockpile(pid, offered[index])
			if selected.action == "invalid":
				return selected
			continue
		var market: Dictionary = _owner.player_view(0, 0).world.game_market
		if market.seat != 2:
			if not random_choices:
				return {"action": "game_market_choice", "player_id": market.seat}
			var options: Array = market_choices(market.seat)
			var index: int = int(Economy.Rng.draw(_owner.rng_seed(), "MARKET_RANDOM_V1", "%d:%d" % [_owner.round_number(), market.seat], 0, options.size()).value)
			var selected: Dictionary = choose_market(market.seat, options[index])
			if selected.action == "invalid":
				return selected
			continue
		var result: Dictionary = step()
		if result.action == "invalid":
			return result
	return {"action": "game_planning", "round": _owner.round_number()}

func market_choices(player_id: int) -> Array:
	if _owner == null or player_id not in [0, 1] or _owner.next_hook() != Timeline.PRESENT_PUBLIC_STATE:
		return []
	var view: Dictionary = _owner.player_view(player_id, 0).world
	if view.game_market.seat != player_id:
		return []
	var choices: Array = [{"market": "Pass"}]
	for take in view.market:
		for give in view.hand:
			choices.append({"market": "Swap", "take_id": take, "give_id": give})
	return choices

func outcome() -> Dictionary:
	if _owner == null:
		return Data.invalid("game_not_started")
	var state: Dictionary = _owner.player_view(0, 0).world.victory
	return {"action": "game_finished" if state.winner != -1 else "game_in_progress", "round": _owner.round_number(), "winner": state.winner, "win_by": state.win_by}
