extends SceneTree
const Board = preload("res://Prototype/U13/U13ActionFlowBoard.gd")
const Game = Board.PlaySession.Game
const Work = Board.Work
const Slots = Game.Slots
const Ledger = preload("res://Prototype/U13/U13AftermathLedger.gd")
const Gremory = preload("res://Scripts/Sim/U13Gremory.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
var failures: int = 0
var board
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	mechanics()
	check(Ledger.describe("KANIFOUS_WISH_RESOLVED", {"power": "WishDeath", "count": 4}) == "Deathwish · 4 Marchers killed", "Deathwish displays actual kill count")
	check(Ledger.describe("KANIFOUS_WISH_RESOLVED", {"power": "WishDeath", "count": 0}).contains("0 Marchers"), "unsuccessful Deathwish reports zero")
	board = Board.new()
	root.add_child(board)
	board._runtime_ok = true
	board.open_setup()
	await process_frame
	board.start_loadout(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES], false)
	await process_frame
	check(board._slaver_pending() and board.confirm.visible and board.pass_button.visible, "Slaver exposes both modal action slots")
	check(board._playtime_surface() == "slaver", "Slaver decision time has its own surface")
	check(board.confirm.text == "SWAP CARDS" and board.pass_button.text == "PASS TRADE", "Slaver action slots are labelled correctly")
	board.pass_round()
	await job_done()
	check(board._flow_title() == "Work Target", "modal Pass completes Slaver")
	check(board._playtime_surface() == "work_target", "Work Target decision time is separate from Slaver")
	board._set_work_target(Slots.castle_id(0, 4))
	await process_frame
	check(board.sides[1].target_controls[Slots.castle_id(0, 4)].get_parent().get_parent().work_target_badge != null, "selected work target appears on its Castle")
	board._goto_flow(3)
	check(board._playtime_surface() == "combat_commitment", "Combat decision time has its own surface")
	board._select_direct_action("Hunt")
	var id: String = board._available_ids()[0]
	board._hand_selection_changed([id])
	await process_frame
	check(id in board._draft_combat.get("card_ids", []) and board._draft_combat.get("action") == "Hunt", "clicking a hand card stages Hunt without a separate target click")
	check(board.flow_forecast.visible and board.flow_forecast.get_parent() == board.action_zone.action_box and board.flow_forecast.get_index() == board.action_zone.action_buttons["Hunt"].get_index() + 1 and board.flow_forecast.text.contains("Visible offense:") and board.flow_forecast.text.contains("Visible defense:"), "compact forecast is directly below selected Hunt in modal")
	check(not board._order_preview.get_children().any(func(c): return c is Label and c.text.contains("Visible offense:")), "forecast no longer overlays board cards")
	check(board.header.scores[0].text.contains("Personal Tears") and board.header.scores[1].text.contains("Personal Tears") and board.header.veil_wheel.visible, "corner resources include Personal Tears and banner shows Veil wheel")
	var final_view: Dictionary = {"lord_ids": ["Deimos", "Kroni"], "souls": [2, 3], "personal_tears": [1, 5], "neutral_tears": 7, "veil_total": 13, "victory": {"winner": 1, "win_by": "Dominion", "checked_round": 14}}
	var ledger: String = Ledger.render(final_view, [], 14)
	check(ledger.begins_with("DEFEAT · Dominion") and ledger.contains("Kroni won with 5 Personal Tears to 1") and ledger.contains("Veil reached 13"), "Aftermath leads with exact loss condition and totals")
	var target: String = board._draft_combat.target_id
	board._return_card("combat", id)
	board._select_direct_action("Siege")
	board._hand_selection_changed([id])
	await process_frame
	check(id in board._draft_combat.get("card_ids", []) and board._draft_combat.get("action") == "Siege" and board._draft_combat.target_id != target, "Siege card click stages against an enemy Castle")
	# Build an eligible protected Castle in a valid fresh fixture, then stage at Powers.
	var w: Dictionary = fixture()
	var project: String = Slots.castle_id(0, 4)
	var ids = Work.Ids.new(); ids.restore(w.entities)
	var castle: Dictionary = ids.get_entity(project)
	castle.attributes.integrity = 9; castle.attributes.status = "standing"; castle.attributes.construction_state = "building"
	ids.update(project, 0, castle.attributes); w.entities = ids.snapshot()
	var play = Board.PlaySession.new()
	play._owner = Game.Content.new().create_combat_match()
	check(play._owner.start("commission-ui", w, [0, 1]).action != "invalid", "commission fixture valid")
	play._to_planning()
	board._reset_direct(); board.session = play; board._refresh()
	await process_frame
	board.pass_round(); await job_done()
	board._goto_flow(4)
	check(board._playtime_surface() == "lord_powers", "power decisions retain a separate timing bucket")
	var button: Button = board.sides[1].commission_buttons[project]
	check(not button.disabled, "Commission stays enabled during Lord Powers")
	button.pressed.emit()
	await process_frame
	check(board.castle_plan.get("action") == "Activate" and board.session.choose(board.queued, board._order()).action != "invalid", "Commission stages through authoritative validation at Lord Powers")
	board._goto_flow(5)
	board.pass_round(); await job_done()
	check(board.session._owner.snapshot().world.entities.entities.filter(func(e): return e.id == project)[0].attributes.construction_state == "active", "Commission resolves through the complete round pipeline")
	board.finish_playback(); await job_done()
	board.queue_free(); await process_frame
	print("U13 UI feedback failures: %d" % failures)
	quit(failures)
func fixture() -> Dictionary:
	return Game.Economy.initialize(Game.Scenario.loadout_world(["Deimos", "Gremory"], [Slots.TYPES, Slots.TYPES]), "ui-feedback").world
func mechanics() -> void:
	var w: Dictionary = fixture()
	var id: String = Slots.castle_id(0, 4)
	var ids = Work.Ids.new(); ids.restore(w.entities)
	var castle: Dictionary = ids.get_entity(id)
	castle.attributes.integrity = 9; castle.attributes.status = "standing"; castle.attributes.construction_state = "building"
	ids.update(id, 0, castle.attributes); w.entities = ids.snapshot()
	var choice: Dictionary = {"action": "Activate", "target_id": id, "card_ids": [], "use_repair_token": false}
	check(Work.validate_choice(w, 0, choice).action == "legal", "protected Castle at 9 Integrity can commission")
	check(Work.validate_choice(w, 1, choice).action == "invalid", "opponent cannot commission your Castle")
	for pid in [0, 1]:
		w.data.guard_orders[pid] = {"round": 1, "moves": []}
		w.data.castle_orders[pid] = {"choice": choice if pid == 0 else {}}
	Work.develop(w, 1, [0, 1]); ids.restore(w.entities)
	check(ids.get_entity(id).attributes.construction_state == "active" and ids.get_entity(id).attributes.integrity == 9, "Commission exposes Castle at existing Integrity without free repair")
	var source: Dictionary = {"power_id": Gremory.RUIN, "player_id": 1, "target": {"entity_id": id}, "declaration_id": "ui-ruin"}
	var content = Deimos.new(true, true, true)
	var result: Dictionary = content.resolve({"declaration": source}, {"world": w, "round": 2})
	ids.restore(result.world.entities)
	var ruined: Dictionary = ids.get_entity(id)
	check(ruined.attributes.status == "defunct" and ruined.attributes.integrity == 0, "Inevitable Ruin leaves a defunct Castle")
	check(Work.eligible(result.world, 0, ruined), "Ruin target remains repairable")
	check(ruined.attributes.get("repair_lock_until_round", 0) == 3, "Ruin retains following-round repair lock")
func job_done() -> void:
	while board._job != null: await process_frame
	await process_frame
