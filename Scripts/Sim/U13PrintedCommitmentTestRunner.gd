extends SceneTree
const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Combat = preload("res://Scripts/Sim/U13Combat.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const View = preload("res://Scripts/Sim/U13DoctrineView.gd")
const Forecast = preload("res://Scripts/Sim/U13ActionForecast.gd")
const Split = preload("res://Scripts/Sim/U13SplitWard.gd")
const Codec = preload("res://Scripts/Sim/U13ExactData.gd")
const SUITS: Array = ["Butcher", "Penitent", "Vulture", "Wright"]
var checks: int = 0
var failures: int = 0
var cases: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func card(w: Dictionary, suit: String, value: int, pid: int, excluded: Array) -> String:
	var ids = Ids.new(); ids.restore(w.entities)
	var choices: Array = w.entities.entities.filter(func(r): return r.kind == "card" and r.attributes.suit == suit and r.attributes.value == value and r.id not in excluded)
	var row: Dictionary = choices[0].duplicate(true)
	var z: Dictionary = w.data.card_zones
	for pile in [z.deck, z.discard, z.hands[0], z.hands[1], z.committed[0], z.committed[1], z.market, z.market_reserve]: pile.erase(row.id)
	for key in ["role", "lane", "slot"]: row.attributes.erase(key)
	ids.update(row.id, pid, row.attributes)
	z.hands[pid].append(row.id)
	w.entities = ids.snapshot()
	return row.id

func scenario(action: String, attack: Array, ward: Array) -> void:
	var seed: String = "printed-value:" + str(cases.size())
	var w: Dictionary = Game.Economy.initialize(Game.Scenario.loadout_world(["Gremory", "Humbaba"], [Game.Slots.TYPES, Game.Slots.TYPES]), seed).world
	Split.configure(w)
	var used: Array = []
	var paid: Array = []
	var defense: Array = []
	var expected_attack: int = 0
	var expected_ward: int = 0
	for spec in attack:
		var id: String = card(w, spec[0], spec[1], 0, used)
		used.append(id); paid.append(id); expected_attack += spec[1]
	for spec in ward:
		var id: String = card(w, spec[0], spec[1], 1, used)
		used.append(id); defense.append(id); expected_ward += spec[1]
	var lane: String = "Lord" if action == "Hunt" else "Castle"
	var order: Dictionary = {"action": action, "lane": lane, "card_ids": paid, "target_id": w.players[1].lord_entity_id if action == "Hunt" else Game.Slots.castle_id(1, 1)}
	var shield: Dictionary = {"action": "Ward", "lane": lane, "card_ids": defense}
	var ctx: Dictionary = {"round": 1, "seed": seed, "player_order": [0, 1], "hook": "combat_resolution", "combat_orders": [order, shield], "persistent_effects": []}
	var content = Game.Content.new()
	check(content.valid_world(w), "%s fixture is valid" % seed)
	var result: Dictionary = content.on_hook(ctx.merged({"world": w.duplicate(true)}))
	check(result.action == "resolved", "%s resolves" % seed)
	var kind: String = "HUNT_RESOLVED" if action == "Hunt" else "SIEGE_RESOLVED"
	var facts: Array = result.events.filter(func(e): return e.event.type == kind)
	check(facts.size() == 1 and facts[0].event.data.strength == expected_attack and facts[0].event.data.ward_screen == expected_ward, "%s uses printed attack %d and Ward %d" % [seed, expected_attack, expected_ward])
	var public: Dictionary = {"viewer_id": 0, "entities": w.entities.entities, "hand": paid, "guard_work": w.data.guard_work, "ward_experiment": Split.VERSION, "players": w.players, "sigils": w.data.sigils}
	var view = View.new({"world": public})
	check(view.strength(paid) == expected_attack, "%s bot estimate matches attack" % seed)
	var forecast: Dictionary = Forecast.evaluate({"world": public}, order)
	public.hand = defense
	var ward_forecast: Dictionary = Forecast.evaluate({"world": public}, shield)
	check(forecast.get("card_strength") == expected_attack and ward_forecast.get("strength") == expected_ward, "%s forecasts match both payments" % seed)
	var after: Dictionary = result.world
	result = result.duplicate(true); result.erase("world")
	cases.append({"world": w, "context": ctx, "expected_attack": expected_attack, "expected_ward": expected_ward, "result": result, "after": after})

func run() -> void:
	for action in ["Hunt", "Siege"]:
		for suit in range(SUITS.size()):
			for value in range(1, 6):
				scenario(action, [[SUITS[suit], value]], [[SUITS[(suit + 1) % SUITS.size()], 6 - value]])
		for suit in ["Butcher", "Penitent"]:
			scenario(action, [[suit, 3], [suit, 3]], [[suit, 2], [suit, 2]])
		scenario(action, [["Butcher", 3], ["Penitent", 3], ["Vulture", 3], ["Wright", 3]], [["Butcher", 2], ["Penitent", 2], ["Vulture", 2], ["Wright", 2]])
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var encoded: Dictionary = Codec.encode({"schema": "U13_PRINTED_COMMITMENTS_V1", "cases": cases})
		check(encoded.action == "encoded", "native cases encode exactly")
		var file = FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(encoded.text); file.close()
	print("Printed commitments: %d checks, %d failures" % [checks, failures])
	quit(failures)
