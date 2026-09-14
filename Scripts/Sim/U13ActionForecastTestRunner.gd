extends "res://Scripts/Sim/U13BasicDoctrineTestRunner.gd"
const Forecast = preload("res://Scripts/Sim/U13ActionForecast.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
func run() -> void:
	public_guard_boundary()
	coordinated_powers()
	for action in ["Siege", "Hunt"]:
		for amount in [3, 7, 14, 21]: compare(action, amount)
	pair_visibility()
	ward_and_privacy()
	print("U13 action forecast failures: %d" % failures)
	quit(failures)
func public_view(w: Dictionary) -> Dictionary:
	var view: Dictionary = Game.Content.new().project(w, 0)
	view["viewer_id"] = 0
	return {"world": view}
func compare(action: String, amount: int) -> void:
	var w: Dictionary = fixture("Orias")
	for castle in w.entities.entities:
		if castle.kind == "castle" and castle.owner == 1:
			patch(w, castle.id, {"status": "ruined", "integrity": 0, "construction_state": "active"})
	var screen: String = Slots.castle_id(1, 0 if action == "Hunt" else 1)
	patch(w, screen, {"status": "standing", "integrity": 7})
	var card: String = w.data.card_zones.hands[0][0]
	patch(w, card, {"suit": "Butcher", "value": amount})
	var target: String = w.players[1].lord_entity_id if action == "Hunt" else Slots.castle_id(1, 2)
	if action == "Siege": patch(w, target, {"status": "standing", "integrity": 8})
	var lane: String = "Lord" if action == "Hunt" else "Castle"
	var guard: String = w.data.card_zones.hands[1].pop_back()
	patch(w, guard, {"role": "guard", "lane": lane, "slot": 0, "value": 3})
	w.data.sigils[1][lane] = "fresh"
	var order: Dictionary = {"action": action, "lane": lane, "target_id": target, "card_ids": [card]}
	var view: Dictionary = public_view(w)
	var before: Dictionary = view.duplicate(true)
	var predicted: Dictionary = Forecast.evaluate(view, order)
	var context: Dictionary = {"world": w, "round": 1, "hook": Game.Timeline.COMBAT_RESOLUTION, "combat_orders": [order, {}], "seed": "forecast", "player_order": [0, 1]}
	var actual: Dictionary = Combat.on_hook(context, Callable(Game.Content.new(), "react"))
	if not check(actual.action != "invalid", "forecast comparison combat resolves"): return
	var outcomes: Array = actual.events.filter(func(e): return e.event.type == action.to_upper() + "_RESOLVED")
	if not check(outcomes.size() == 1 and predicted.available, "forecast and combat produce a result"): return
	var result: Dictionary = outcomes[0].event.data
	check(predicted.guards_defeated == result.guards_defeated, "%s Guard equality and strict defeat at %d" % [action, amount])
	check((predicted.banished == result.banished) if action == "Hunt" else (predicted.damage == result.damage and predicted.destroyed == result.destroyed), "%s baseline agrees through Guards, Sigil and interception at %d" % [action, amount])
	check(view == before and Forecast.evaluate(view, order) == predicted, "forecast is deterministic and read only")
func ward_and_privacy() -> void:
	var w: Dictionary = fixture()
	var cards: Array = w.data.card_zones.hands[0].slice(0, 3)
	for index in range(3): patch(w, cards[index], {"suit": "Penitent" if index < 2 else "Wright", "value": 3})
	var order: Dictionary = {"action": "Ward", "lane": "Lord", "card_ids": cards}
	var view: Dictionary = public_view(w)
	var first: Dictionary = Forecast.evaluate(view, order)
	check(first.strength == 8 and first.recruits == 4, "Ward uses suit efficiency, half-screen and 2:1 per-suit recruitment")
	var hidden_ids: Array = w.data.card_zones.hands[1]
	check(view.world.entities.all(func(e): return e.id not in hidden_ids), "opponent hand identities remain absent")
	for id in hidden_ids: patch(w, id, {"value": 5, "suit": "Butcher"})
	check(Forecast.evaluate(public_view(w), order) == first, "opponent hidden hand faces cannot change forecast")
	var support_id: String = "public-support"
	view.world.entities.append({"id": support_id, "kind": "marcher", "owner": 0, "attributes": {"lane": "Castle", "waiting": true}})
	for castle in view.world.entities:
		if castle.kind == "castle" and castle.owner == 1: castle.attributes.status = "ruined"
	order = {"action": "Siege", "lane": "Castle", "card_ids": cards, "target_id": "castle_zone:1"}
	first = Forecast.evaluate(view, order)
	check(first.pillage_success and first.support == 1, "Pillage includes matching-lane Supplicants")
	order["rites"] = {"waiter_spends": [{"marcher_ids": [support_id]}]}
	check(Forecast.evaluate(view, order).support == 0, "reserved Supplicants are excluded from combat forecast")

func pair_visibility() -> void:
	var w: Dictionary = fixture()
	var guards: Array = w.data.card_zones.hands[1].slice(0, 2)
	w.data.guard_orders = [{"round": 1, "moves": []}, {"round": 1, "moves": []}]
	w.data.castle_orders = [{"choice": {}}, {"choice": {}}]
	for index in range(2):
		w.data.card_zones.hands[1].erase(guards[index])
		patch(w, guards[index], {"role": "guard", "lane": "Castle", "slot": index, "suit": "Penitent", "value": 3})
		w.data.guard_orders[1].moves.append({"card_id": guards[index], "lane": "Castle", "slot": index})
	Game.Content.GuardWork.develop(w, 1, [0, 1])
	var view: Dictionary = public_view(w)
	check(view.world.guard_work.pairs.size() == 1 and view.world.guard_work.pairs[0].player_id == 1, "enemy active pair is public")
	var card: String = w.data.card_zones.hands[0][0]
	patch(w, card, {"suit": "Butcher", "value": 5})
	var order: Dictionary = {"action": "Siege", "lane": "Castle", "target_id": Slots.castle_id(1, 0), "card_ids": [card]}
	var forecast: Dictionary = Forecast.evaluate(public_view(w), order)
	check(forecast.guards_defeated == 0 and forecast.damage == 0, "public Penitent pair stops strength before the Guard layer")
	patch(w, guards[0], {"role": "hand"})
	Game.Content.GuardWork.reconcile(w)
	check(public_view(w).world.guard_work.pairs.is_empty(), "broken pair is absent from the public forecast projection")
