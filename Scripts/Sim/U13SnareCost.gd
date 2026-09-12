extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const Ids = preload("res://Scripts/Sim/U13EntityIds.gd")
const Conduit = preload("res://Scripts/Sim/U13BloodConduit.gd")
const Timeline = preload("res://Scripts/Sim/U13RoundTimeline.gd")

# Shared by authoritative submission and its isolated bulk legality preview.
# Threat gain can exert a Circle and change Castle Repair admission immediately.
static func pay(world: Dictionary, source: Dictionary, round_number: int) -> Dictionary:
	var pid: int = source.player_id
	if world.data.snare_paid_rounds[pid] >= round_number:
		return Data.invalid("snare_already_paid")
	var entities = Ids.new()
	entities.restore(world.entities)
	var lord: Dictionary = entities.get_entity(world.players[pid].lord_entity_id)
	var before: int = lord.attributes.threat
	if before >= 1000000:
		return Data.invalid("snare_threat_limit")
	var gain: Dictionary = Conduit.gain(world, lord.id, 1, round_number)
	world = gain.world
	world.data.snare_paid_rounds[pid] = round_number
	var event: Dictionary = {
		"type": "SNARE_ARMED", "text": "", "data": {
			"player_id": pid, "target_player_id": 1 - pid,
			"round": round_number, "hook": Timeline.SUBMISSION_LOCK,
			"declaration_id": source.declaration_id,
			"threat_before": before, "threat_after": gain.after
		}
	}
	return {"action": "resolved", "world": world, "events": gain.events + [{"event": event, "views": [event, event]}]}
