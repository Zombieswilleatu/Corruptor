extends "res://Scripts/Sim/U13BoardSession.gd"

const Kanifous = preload("res://Scripts/Sim/U13Kanifous.gd")
const KanifousScenario = preload("res://Scripts/Sim/U13KanifousScenario.gd")
const Valak = preload("res://Scripts/Sim/U13Valak.gd")
const ValakScenario = preload("res://Scripts/Sim/U13ValakScenario.gd")
const Kroni = preload("res://Scripts/Sim/U13Kroni.gd")
const KroniScenario = preload("res://Scripts/Sim/U13KroniScenario.gd")
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
var odradek_visuals: Array = []
var kroni_guard_events: Array = []
var valak_events: Array = []
var kanifous_events: Array = []


# This legacy board session keeps its explicit exercise opening. Production
# starting Castles and summon payment belong to U13GameEconomy; never blend that
# path into these focused visual fixtures or mutate a running match.
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
		or lords.has("Kroni")
		or lords.has("Valak")
		or lords.has("Kanifous")
	)
	_scenario = 0
	_lane = "Castle"
	_last_marching = []
	_powers = []
	_order = {}
	_opponent = {}
	odradek_visuals = []
	kroni_guard_events = prepared.kroni_guard_events.duplicate(true)
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
	if setup_lords.has("Kanifous"):
		return KanifousScenario.plan(_owner, 1)
	if setup_lords.has("Valak"):
		return ValakScenario.plan(_owner, 1)
	if setup_lords.has("Kroni"):
		return KroniScenario.plan(_owner, 1)
	if setup_lords.has("Odradek"):
		return OdradekScenario.plan(_owner, 1)
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
	if lords.has("Kanifous"):
		return KanifousScenario.loadout_world(lords, castles)
	if lords.has("Valak"):
		return ValakScenario.loadout_world(lords, castles)
	if lords.has("Kroni"):
		return KroniScenario.loadout_world(lords, castles)
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
	if lords.has("Kanifous"):
		return Kanifous.new()
	if lords.has("Valak"):
		return Valak.new()
	if lords.has("Kroni"):
		return Kroni.new()
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
			or setup.lords.has("Kroni")
			or setup.lords.has("Valak")
			or setup.lords.has("Kanifous")
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
	odradek_visuals = []
	return {"action": "loadout_checkpoint_restored"}


# Read-only whole-plan check for UI readiness, including persistent relocation.
func preview_power(
	power: String, target: Dictionary, queued: Array, order: Dictionary
) -> Dictionary:
	var draft: Array = queued.duplicate(true)
	draft.append(declaration(power, draft.size(), target))
	return _owner.preview_submission(0, draft, order)


func summon_preview(cards: Array) -> Dictionary:
	var world: Dictionary = _owner._world_snapshot()
	if not world.data.has("resummon_profile"):
		return Data.invalid("summon_profile_unavailable")
	return Orias.Resummon.quote(world, 0, cards)


func debug_action(action: String, pid: int, lane: String) -> Dictionary:
	if next_hook() != Timeline.SUBMISSION_LOCK:
		return Data.invalid("debug_planning_only")
	var content = _content(setup_lords, hunt_enabled)
	var candidate = content.create_combat_match()
	var restored: Dictionary = candidate.restore(_owner.snapshot())
	if restored.action == "invalid":
		return restored
	var result: Dictionary = preload("res://Scripts/Sim/U13DebugActions.gd").apply(candidate.snapshot().world, action, pid, lane, round_number(), candidate.rng_seed(), content)
	if result.action == "invalid":
		return result
	var changed: Dictionary = candidate._apply_transform({"action": "resolved", "world": result.world, "events": result.events})
	if changed.action == "invalid":
		return changed
	candidate._presentation_world = candidate._world.duplicate(true)
	var checked = content.create_combat_match()
	var valid: Dictionary = checked.restore(candidate.snapshot())
	if valid.action == "invalid":
		return valid
	_owner = checked
	_powers = []
	_order = {}
	_opponent = {}
	odradek_visuals = []
	return {"action": "debug_applied", "message": result.message}


func run_to_marching() -> Dictionary:
	kanifous_events = []
	valak_events = []
	odradek_visuals = []
	return super.run_to_marching()


func step() -> Dictionary:
	var kanifous_cursor: int = _owner._event_cursor() if setup_lords.has("Kanifous") else -1
	var valak_cursor: int = _owner._event_cursor() if setup_lords.has("Valak") else -1
	var hook: String = next_hook()
	if hook == Timeline.ROUND_START_SCHEDULED:
		kroni_guard_events = []
	var capture: bool = hook in [Timeline.POST_RESOLUTION_POSITION, Timeline.POST_RESOLUTION_ALLEGIANCE, Timeline.ROUND_START_SCHEDULED]
	var cursor: int = _owner._event_cursor() if capture else 0
	var before: Array = _owner.player_view(0, 0).world.entities.duplicate(true) if capture else []
	var result: Dictionary = super.step()
	if kanifous_cursor >= 0 and result.action != "invalid":
		for event in _owner._player_events_since(0, kanifous_cursor):
			if event.type.begins_with("KANIFOUS_") or event.type.begins_with("WISHMASTER_"):
				kanifous_events.append(event.duplicate(true))
	if valak_cursor >= 0 and result.action != "invalid":
		for event in _owner._player_events_since(0, valak_cursor):
			if event.type in ["VALAK_ESSENCE_GAINED", "VALAK_ESSENCE_REINFORCED", "VALAK_PROJECTION_RESOLVED", "GRAVITY_ORB_STARTED"]:
				valak_events.append(event.duplicate(true))
	if capture and result.action != "invalid":
		var events: Array = _owner._player_events_since(0, cursor)
		_capture_odradek_visuals(before, events)
		for event in events:
			if event.type == "GUARD_DEVOURED":
				kroni_guard_events.append(event.duplicate(true))
	return result


func _capture_odradek_visuals(before: Array, events: Array) -> void:
	var working: Array = before.duplicate(true)
	var allegiance_changes: Array = []
	for event in events:
		var data: Dictionary = event.data
		if event.type == "MARCHER_ALLEGIANCE_CHANGED":
			allegiance_changes.append({"before": data.before, "after": data.after})
			continue
		var changes: Array = []
		if event.type == "REDIRECT_RESOLVED":
			changes = data.changes
		elif event.type == "ALLEGIANCE_SHIFT_RESOLVED":
			changes = allegiance_changes
			allegiance_changes = []
		elif event.type == "GUARD_RECONFIGURED":
			changes = [{"before": data.before, "after": data.after}]
		else:
			continue
		var start: Array = working.duplicate(true)
		for change in changes:
			for index in range(working.size()):
				if working[index].id == change.after.id:
					working[index] = change.after.duplicate(true)
		odradek_visuals.append({"type": event.type, "data": data.duplicate(true), "before": start, "after": working.duplicate(true), "round": round_number()})
