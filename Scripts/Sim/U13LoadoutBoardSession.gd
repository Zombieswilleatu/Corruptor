extends "res://Scripts/Sim/U13BoardSession.gd"

const Odradek = preload("res://Scripts/Sim/U13Odradek.gd")
const OdradekScenario = preload("res://Scripts/Sim/U13OdradekScenario.gd")
const Orias = preload("res://Scripts/Sim/U13Orias.gd")
const OriasScenario = preload("res://Scripts/Sim/U13OriasScenario.gd")
const Core = preload("res://Scripts/Sim/U13CoreScenario.gd")
const Deimos = preload("res://Scripts/Sim/U13Deimos.gd")
const Humbaba = preload("res://Scripts/Sim/U13Humbaba.gd")
const HumbabaScenario = preload("res://Scripts/Sim/U13HumbabaScenario.gd")
const Slots = preload("res://Scripts/Sim/U13CastleSlots.gd")
const Kalligan = preload("res://Scripts/Sim/U13Kalligan.gd")
const KalliganScenario = preload("res://Scripts/Sim/U13KalliganScenario.gd")
const BOARD_SEED: String = "u13-loadout-board-v1"
var setup_lords: Array = ["Deimos", "Gremory"]
var setup_castles: Array = [
	["SiegeEngine", "SiegeEngine", "Keep", "Bastion", "Stockpile"],
	["SiegeEngine", "SiegeEngine", "Keep", "Bastion", "Stockpile"]
]
var quick_start: bool = true
var hunt_enabled: bool = false


# Only the exercise opening differs from Core's all-unbuilt setup boundary.
# Keep production starting economy undecided, and never mutate a running match.
func configure(lords: Array, castles: Array, quick: bool) -> Dictionary:
	var initial: Dictionary = _initial(lords, castles)
	if initial.get("action") == "invalid":
		return initial
	if quick:
		var entities = Ids.new()
		entities.restore(initial.entities)
		for pid in [0, 1]:
			for slot in [0, 1]:
				var castle: Dictionary = entities.get_entity(Slots.castle_id(pid, slot))
				castle.attributes.integrity = 12 if slot == 0 else 7
				castle.attributes.status = "standing"
				castle.attributes.construction_state = "active" if slot == 0 else "building"
				entities.update(castle.id, pid, castle.attributes)
		initial.entities = entities.snapshot()
	if hunt_enabled:
		initial.data["hunt_profile"] = Combat.HUNT_VERSION
	var content = _content(lords, hunt_enabled)
	var candidate = content.create_combat_match()
	var started: Dictionary = candidate.start(BOARD_SEED, initial, [0, 1])
	if started.action == "invalid":
		return started
	# Finish setup on a temporary session so a rejected draft is atomic.
	var prepared = get_script().new()
	prepared._owner = candidate
	var ready: Dictionary = prepared._to_planning()
	if ready.action == "invalid":
		return ready
	_owner = prepared._owner
	setup_lords = lords.duplicate(true)
	setup_castles = castles.duplicate(true)
	quick_start = quick
	hunt_enabled = (
		hunt_enabled
		or lords.has("Humbaba")
		or lords.has("Kalligan")
		or lords.has("Orias")
		or lords.has("Odradek")
	)
	_scenario = 0
	_lane = "Castle"
	_last_marching = []
	_powers = []
	_order = {}
	_opponent = {}
	return {"action": "loadout_board_ready"}


func reset(_scenario_index: int = 0) -> Dictionary:
	return configure(setup_lords, setup_castles, quick_start)


func declaration(
	power: String, index: int, target: Dictionary, cost: Dictionary = {}
) -> Dictionary:
	var rule: Dictionary = _content(setup_lords, hunt_enabled).rules().get(power, {})
	if rule.is_empty():
		return Data.invalid("power_unknown")
	if cost.is_empty():
		cost = rule.cost.duplicate(true)
	var current: int = round_number()
	return Decl.create(
		MatchOwner.declaration_id(0, current, index),
		0,
		setup_lords[0],
		power,
		current,
		rule.fire_hook,
		current + int(rule.delay_rounds),
		index,
		"public",
		target,
		cost,
		{}
	)


func random_opponent_plan() -> Dictionary:
	if setup_lords.has("Odradek"):
		return RandomLegal.plan(_owner, 1, Callable(OdradekScenario, "enumerate"))
	if setup_lords.has("Orias"):
		return RandomLegal.plan(_owner, 1, Callable(OriasScenario, "enumerate"))
	return RandomLegal.plan(
		_owner,
		1,
		Callable(
			(
				KalliganScenario
				if setup_lords.has("Kalligan")
				else (HumbabaScenario if setup_lords.has("Humbaba") else Core)
			),
			"enumerate"
		)
	)


static func _initial(lords: Array, castles: Array) -> Dictionary:
	if lords.has("Odradek"):
		return OdradekScenario.loadout_world(lords, castles)
	if lords.has("Orias"):
		return OriasScenario.loadout_world(lords, castles)
	if lords.has("Kalligan"):
		return KalliganScenario.loadout_world(lords, castles)
	return (
		HumbabaScenario.loadout_world(lords, castles)
		if lords.has("Humbaba")
		else Core.loadout_world(lords, castles)
	)


static func _content(lords: Array, hunt: bool):
	if lords.has("Odradek"):
		return Odradek.new()
	if lords.has("Orias"):
		return Orias.new()
	if lords.has("Kalligan"):
		return Kalligan.new()
	return Humbaba.new() if lords.has("Humbaba") else Deimos.new(true, true, hunt)


func _fork_for_job():
	var candidate = super._fork_for_job()
	if candidate != null:
		candidate.setup_lords = setup_lords.duplicate(true)
		candidate.setup_castles = setup_castles.duplicate(true)
		candidate.quick_start = quick_start
		candidate.hunt_enabled = hunt_enabled
	return candidate


func checkpoint() -> Dictionary:
	var result: Dictionary = super.checkpoint()
	result["board_setup"] = {
		"lords": setup_lords.duplicate(true),
		"castles": setup_castles.duplicate(true),
		"quick": quick_start,
		"hunt": hunt_enabled
	}
	return result


func restore_checkpoint(raw: Dictionary) -> Dictionary:
	if (
		not Data.is_data(raw)
		or typeof(raw.get("board_setup")) != TYPE_DICTIONARY
		or typeof(raw.get("match")) != TYPE_DICTIONARY
		or typeof(raw.get("marching_events")) != TYPE_ARRAY
		or raw.get("scenario") != 0
		or raw.get("lane") not in ["Lord", "Castle"]
	):
		return Data.invalid("loadout_checkpoint_invalid")
	var setup: Dictionary = raw.board_setup
	if (
		typeof(setup.get("lords")) != TYPE_ARRAY
		or typeof(setup.get("castles")) != TYPE_ARRAY
		or typeof(setup.get("quick")) != TYPE_BOOL
		or typeof(setup.get("hunt", false)) != TYPE_BOOL
	):
		return Data.invalid("loadout_checkpoint_setup_invalid")
	if (
		(
			setup.lords.has("Humbaba")
			or setup.lords.has("Kalligan")
			or setup.lords.has("Orias")
			or setup.lords.has("Odradek")
		)
		and not setup.get("hunt", false)
	):
		return Data.invalid("humbaba_checkpoint_requires_hunt")
	var initial: Dictionary = _initial(setup.lords, setup.castles)
	if initial.get("action") == "invalid":
		return initial
	var content = _content(setup.lords, setup.get("hunt", false))
	var candidate = content.create_combat_match()
	var restored: Dictionary = candidate.restore(raw.match)
	if restored.action == "invalid":
		return restored
	var world: Dictionary = candidate.player_view(0, 0).world
	if world.lord_ids != setup.lords or world.castle_loadouts != setup.castles:
		return Data.invalid("loadout_checkpoint_setup_mismatch")
	_owner = candidate
	setup_lords = setup.lords.duplicate(true)
	setup_castles = setup.castles.duplicate(true)
	quick_start = setup.quick
	hunt_enabled = setup.get("hunt", false)
	_lane = raw.lane
	_scenario = 0
	_last_marching = Data.copy_data(raw.marching_events)
	_powers = []
	_order = {}
	_opponent = {}
	return {"action": "loadout_checkpoint_restored"}


# Read-only whole-plan check for UI readiness, including persistent relocation.
func preview_power(
	power: String, target: Dictionary, queued: Array, order: Dictionary
) -> Dictionary:
	var draft: Array = queued.duplicate(true)
	draft.append(declaration(power, draft.size(), target))
	return _owner.preview_submission(0, draft, order)


func summon_preview(cards: Array) -> Dictionary:
	if not setup_lords.has("Orias") and not setup_lords.has("Odradek"):
		return Data.invalid("summon_profile_unavailable")
	return Orias.Resummon.quote(_owner.snapshot().world, 0, cards)
