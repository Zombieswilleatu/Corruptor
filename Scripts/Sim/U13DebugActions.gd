extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Cards = preload("res://Scripts/Sim/U13CardZones.gd")
const Battle = preload("res://Scripts/Sim/U13BattleEvents.gd")
const Guards = preload("res://Scripts/Sim/U13GuardDeployment.gd")
const Transfers = preload("res://Scripts/Sim/U13GuardTransfers.gd")
const Marching = preload("res://Scripts/Sim/U13Marching.gd")
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")
const ACTIONS: Array = ["guard", "cards", "marcher", "banish", "defeat_guard", "reconfiguration"]


# Debug edits use a disposable world and the regular reactions. The session
# installs only a completely validated checkpoint; failures are atomic.
static func apply(raw: Dictionary, action: String, pid: int, lane: String, round_number: int, seed_value: String, content) -> Dictionary:
	if action not in ACTIONS or pid not in [0, 1] or lane not in Guards.LANES:
		return Data.invalid("debug_selection_invalid")
	var world: Dictionary = Data.copy_data(raw)
	var serial: int = int(world.data.get("debug_serial", 0)) + 1
	var key: String = "u13-debug:%d" % serial
	var ids = Ids.new()
	ids.restore(world.entities)
	var events: Array = []
	var message: String = ""
	var suit: String = Marching.SUITS[int(Rng.draw(seed_value, key, "SUIT", 0, 4).value)]
	match action:
		"guard":
			var free: Array = Transfers.free_slots(world, pid, lane)
			if free.is_empty():
				return Data.invalid("debug_guard_zone_full")
			var value: int = 1 + int(Rng.draw(seed_value, key, "VALUE", 0, 3).value)
			ids.create("card", key, 0, pid, {"role": "guard", "suit": suit, "value": value, "lane": lane, "slot": free[0]})
			world.entities = ids.snapshot()
			message = "Added %s %d to %s Guards." % [suit, value, lane]
		"cards":
			var count: int = 0
			for index in range(2):
				var drawn: Dictionary = Cards.draw(world, pid, seed_value, key + ":" + str(index))
				if drawn.action == "invalid":
					return drawn
				if drawn.drawn:
					count += 1
			if count == 0:
				return Data.invalid("debug_hand_full_or_deck_empty")
			message = "Drew %d hand card(s)." % count
		"marcher":
			var attributes: Dictionary = Marching.profile(suit, lane, pid, round_number - 1, round_number)
			attributes.x_fp = 800 if pid == 0 else 1600
			attributes.y_fp = 100 + int(Rng.draw(seed_value, key, "LATERAL", 0, 401).value)
			ids.create("marcher", key, 0, pid, attributes)
			world.entities = ids.snapshot()
			message = "Added a %s Marcher in %s lane." % [suit, lane]
		"reconfiguration":
			var lord: Dictionary = ids.get_entity(world.players[pid].lord_entity_id)
			if world.players[pid].lord_id != "Odradek" or not lord.attributes.alive:
				return Data.invalid("debug_requires_active_odradek")
			world.players[pid].resources.reconfiguration = 4
			message = "Reconfiguration filled to 4."
		"banish", "defeat_guard":
			var commands: Array = []
			if action == "banish":
				var lord: Dictionary = ids.get_entity(world.players[pid].lord_entity_id)
				if not lord.attributes.alive:
					return Data.invalid("debug_lord_already_banished")
				commands = [{"kind": "banish_lord", "target_id": lord.id}, {"kind": "set_breach", "lord_id": lord.attributes.lord_id, "source_id": lord.id}]
				message = "Lord banished into the Breach. No Hunt rewards awarded."
			else:
				var targets: Array = []
				for row in world.entities.entities:
					if row.kind == "card" and row.owner == pid and row.attributes.get("role") == "guard" and row.attributes.lane == lane:
						targets.append(row.id)
				if targets.is_empty():
					return Data.invalid("debug_guard_zone_empty")
				targets.sort()
				commands = [{"kind": "defeat_guard", "target_id": targets[0]}]
				message = "Defeated the first Guard in %s; normal defeat triggers applied." % lane
			for index in range(commands.size()):
				var command: Dictionary = commands[index]
				command["command_id"] = key + ":" + str(index)
				var changed: Dictionary = Battle.apply(world, command, round_number, Timeline.SUBMISSION_LOCK)
				if changed.action == "invalid":
					return changed
				var reaction_owner = content if content.has_method("react") else content._humbaba
				var reacted: Dictionary = reaction_owner.react(changed.world, changed.event, seed_value, [0, 1])
				if reacted.action == "invalid":
					return reacted
				world = reacted.world
				if command.kind == "set_breach" and command.lord_id == "Humbaba":
					# Explicitly record a debug-time Breach entry; never falsify the combat clock.
					if not world.data.has("debug_breach_entries"):
						world.data["debug_breach_entries"] = {}
					world.data.debug_breach_entries[changed.event.data.event_id] = round_number
				events.append({"event": changed.event, "views": [changed.event, changed.event]})
				events.append_array(reacted.events)
	world.data["debug_serial"] = serial
	if Guards.enabled(world):
		Guards.capture_limits(world, round_number)
	var event: Dictionary = {"type": "DEBUG_ACTION", "text": "DEBUG · Player %d: %s" % [pid + 1, message], "data": {"action": action, "player_id": pid, "lane": lane, "round": round_number, "serial": serial}}
	events.append({"event": event, "views": [event, event]})
	return {"action": "resolved", "world": world, "events": events, "message": message}
