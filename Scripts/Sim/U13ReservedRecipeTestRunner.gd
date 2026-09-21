extends SceneTree

const Bot = preload("res://Scripts/Sim/U13BasicDoctrine.gd")
const Monsters = preload("res://Scripts/Sim/U13MonsterRules.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	for name in ["Sooge", "Sinodek", "Varn"]:
		var cards: Array = []
		for suit in Monsters.ROSTER[name].recipe:
			for i in range(Monsters.ROSTER[name].recipe[suit]):
				cards.append({"id": suit + str(i), "kind": "card", "owner": 0, "attributes": {"suit": suit, "value": 1}})
		var unit: Dictionary = {"id": "reserve", "kind": "marcher", "owner": 0, "attributes": Monsters.profile(name, "Lord", 0, 1, 2)}
		var view: Dictionary = {"entities": cards.duplicate(true), "monsters": {"unlocked": [[name], [name]]}, "game_staging": {"lanes": {"Lord": {"units": [unit]}, "Castle": {"units": []}}}}
		var ids: Array = cards.map(func(c): return c.id)
		var before: Dictionary = view.duplicate(true)
		check((name in Bot.monster_choices(view, ids, 0)) == not Monsters.limited(name), name + " reserve copy limit")
		check(view == before, "recipe lookup does not mutate reserve or public entities")
		unit.owner = 1
		check(name in Bot.monster_choices(view, ids, 0), "enemy reserve does not block own recipe")
		unit.attributes["charm_owner"] = 0
		check((name in Bot.monster_choices(view, ids, 0)) == not Monsters.limited(name), "original owner retains charmed slot")
		view.entities.append(unit)
		view.game_staging.lanes.Lord.units.clear()
		check((name in Bot.monster_choices(view, ids, 0)) == not Monsters.limited(name), "release preserves living slot")
		view.entities.pop_back()
		check(name in Bot.monster_choices(view, ids, 0), "death or removal frees slot")
		view.erase("game_staging")
		check(name in Bot.monster_choices(view, ids, 0), "legacy view without staging")
	print("U13 reserved recipes: %d checks; failures: %d" % [checks, failures])
	quit(failures)
