extends SceneTree

const Game = preload("res://Scripts/Sim/U13GameConductor.gd")
const Economy = Game.Economy
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)
	return ok

func run() -> void:
	var schema: Dictionary = Game.Scenario.loadout_world(["Kanifous", "Orias"], [Slots.TYPES, Slots.TYPES])
	var opening: Dictionary = Economy.initialize(schema, "game-economy")
	if not check(opening.action != "invalid", "seeded opening"):
		quit(1)
		return
	var world: Dictionary = opening.world
	check(Game.Content.new().valid_world(world), "opening valid under all-Lord content")
	check(world.data.card_zones.hands[0].size() == 5 and world.data.card_zones.hands[1].size() == 5 and world.data.card_zones.deck.size() == 50, "five opening cards each from sixty-card deck")
	var counts: Dictionary = {}
	var high: bool = false
	for row in world.entities.entities:
		if row.kind == "card":
			counts[row.attributes.suit] = int(counts.get(row.attributes.suit, 0)) + 1
			high = high or row.attributes.value >= 4
	check(counts == {"Butcher": 15, "Penitent": 15, "Vulture": 15, "Wright": 15} and high, "real deck distribution includes values four and five")
	check(not world.entities.entities.any(func(e): return e.kind == "marcher" or e.attributes.get("role") == "guard"), "no exercise guards or Marchers")
	check(world.players.all(func(p): return p.resources.values().all(func(n): return n == 0)), "no fixture resources")
	check(world.entities.entities.filter(func(e): return e.kind == "castle").all(func(e): return e.attributes.construction_state == "unbuilt"), "no prebuilt exercise castles")
	check(opening == Economy.initialize(schema, "game-economy"), "same seed reproduces complete opening")
	check(world.data.card_zones.deck != Economy.initialize(schema, "another-seed").world.data.card_zones.deck, "different seed changes deck")
	var ctx: Dictionary = {"hook": Game.Timeline.ROUND_START_AUTOMATIC, "round": 1, "seed": "game-economy", "world": world}
	var first: Dictionary = Economy.on_hook(ctx)
	check(first.world.data.card_zones.hands[0].size() == 10 and first.world.data.card_zones.hands[1].size() == 10, "round one draws five after the opening deal")
	check(world.data.card_zones.hands[0].size() == 5 and world.data.game_economy.draw_round == 0, "draw transform does not mutate input")
	var privacy: bool = true
	for row in first.events:
		var pid: int = row.event.data.player_id
		privacy = privacy and row.views[pid].data.has("card_id") and not row.views[1 - pid].data.has("card_id")
	check(privacy, "draw events hide card identities from opponent")
	ctx.world = first.world
	check(Economy.on_hook(ctx).action == "invalid", "same round cannot draw twice")
	ctx.round = 2
	var capped: Dictionary = Economy.on_hook(ctx)
	check(capped.world.data.card_zones.deck.size() == first.world.data.card_zones.deck.size() and capped.events.all(func(e): return not e.event.data.drawn), "full hands do not consume deck cards")
	# Exhaust the actual shared deck into the discard via legal draw/discard
	# operations, then exercise recycling with both hands cleared.
	var recycled_world: Dictionary = first.world.duplicate(true)
	for pid in [0, 1]:
		Cards.discard(recycled_world, pid, recycled_world.data.card_zones.hands[pid].duplicate())
	while not recycled_world.data.card_zones.deck.is_empty():
		Cards.draw(recycled_world, 0, "recycle", "drain")
		Cards.discard(recycled_world, 0, recycled_world.data.card_zones.hands[0].duplicate())
	ctx.world = recycled_world
	var recycled: Dictionary = Economy.on_hook(ctx)
	check(recycled.action != "invalid" and Cards.valid(recycled.world) and recycled.world.data.card_zones.hands[0].size() == 5 and recycled.world.data.card_zones.deck.size() == 50, "normal draws recycle exhausted deck without lost cards")
	check(recycled == Economy.on_hook(ctx), "recycling and draws replay exactly")
	print("U13 game economy failures: %d" % failures)
	quit(failures)
