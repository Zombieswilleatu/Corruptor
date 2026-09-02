# HUMAN_AGENCY_CONTRACT_LAYER_A_V1
# HUMAN_AGENCY_RUNTIME_CONTRACT_LAYER_B0_V1
class_name HumanContractManifest
extends RefCounted


enum Agency {
	PASSIVE,
	AUTOMATIC,
	TRIGGERED_CHOICE,
	PLAYER_ACTIVATED,
}


enum CommitmentTiming {
	PRE_COMMITMENT,
	POST_COMMITMENT,
	CROSS_COMMITMENT,
}


const LORDS: Array[String] = [
	"Orias",
	"Deimos",
	"Valak",
	"Kroni",
	"Kalligan",
	"Gremory",
	"Odradek",
	"Kanifous",
	"Humbaba",
]


const POWERS: Dictionary = {
	"orias.marked_prey": {
		"lord": "Orias",
		"name": "Marked Prey",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"orias.snare": {
		"lord": "Orias",
		"name": "Snare",
		"agency": Agency.PLAYER_ACTIVATED,
		"commitment_timing": CommitmentTiming.PRE_COMMITMENT,
		"candidate_stage": "DEVELOPMENT_SNARE",
	},
	"orias.barbed_web": {
		"lord": "Orias",
		"name": "Barbed Web",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"orias.relentless_pursuit": {
		"lord": "Orias",
		"name": "Relentless Pursuit",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.CROSS_COMMITMENT,
	},
	"orias.breach_frenzy": {
		"lord": "Orias",
		"name": "Breach: Frenzy",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.PRE_COMMITMENT,
	},
	"deimos.war_machine": {
		"lord": "Deimos",
		"name": "War Machine",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"deimos.fear_aura": {
		"lord": "Deimos",
		"name": "Fear Aura",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"deimos.claim_the_breach": {
		"lord": "Deimos",
		"name": "Claim the Breach",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"deimos.breach_cracked_foundations": {
		"lord": "Deimos",
		"name": "Breach: Cracked Foundations",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"valak.crushing_presence": {
		"lord": "Valak",
		"name": "Crushing Presence",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"valak.siphon": {
		"lord": "Valak",
		"name": "Siphon",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"valak.projection": {
		"lord": "Valak",
		"name": "Projection",
		"agency": Agency.PLAYER_ACTIVATED,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
		"candidate_stage": "RESOLUTION_VALAK_PROJECTION",
	},
	"valak.breach_gravitational_collapse": {
		"lord": "Valak",
		"name": "Breach: Gravitational Collapse",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kroni.hunger_track_defense": {
		"lord": "Kroni",
		"name": "Hunger Track - Defense",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.CROSS_COMMITMENT,
	},
	"kroni.consume": {
		"lord": "Kroni",
		"name": "Consume",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kroni.cannibal_hunger": {
		"lord": "Kroni",
		"name": "Cannibal Hunger",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kroni.hungering_aura": {
		"lord": "Kroni",
		"name": "Hungering Aura",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kroni.ravenous": {
		"lord": "Kroni",
		"name": "Ravenous",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kroni.corruption_milestone": {
		"lord": "Kroni",
		"name": "Corruption Milestone",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kroni.breach_insatiable_hunger": {
		"lord": "Kroni",
		"name": "Breach: Insatiable Hunger",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kalligan.master_builder": {
		"lord": "Kalligan",
		"name": "Master Builder",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.PRE_COMMITMENT,
	},
	"kalligan.pyroclasm": {
		"lord": "Kalligan",
		"name": "Pyroclasm",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kalligan.wildfire": {
		"lord": "Kalligan",
		"name": "Wildfire",
		"agency": Agency.TRIGGERED_CHOICE,
		"commitment_timing": CommitmentTiming.CROSS_COMMITMENT,
		"candidate_stage": "KALLIGAN_SCORCH",
	},
	"kalligan.inferno": {
		"lord": "Kalligan",
		"name": "Inferno",
		"agency": Agency.PLAYER_ACTIVATED,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kalligan.breach_rapid_construction": {
		"lord": "Kalligan",
		"name": "Breach: Rapid Construction",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.PRE_COMMITMENT,
	},
	"gremory.picking_the_bones": {
		"lord": "Gremory",
		"name": "Picking the Bones",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.PRE_COMMITMENT,
	},
	"gremory.predator_of_ruin": {
		"lord": "Gremory",
		"name": "Predator of Ruin",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"gremory.ruinous_harvest": {
		"lord": "Gremory",
		"name": "Ruinous Harvest",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.CROSS_COMMITMENT,
	},
	"gremory.inevitable_ruin": {
		"lord": "Gremory",
		"name": "Inevitable Ruin",
		"agency": Agency.PLAYER_ACTIVATED,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
		"candidate_stage": "RESOLUTION_GREMORY",
	},
	"gremory.breach_sifting_the_ruins": {
		"lord": "Gremory",
		"name": "Breach: Sifting the Ruins",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.PRE_COMMITMENT,
	},
	"odradek.psychic_backwash": {
		"lord": "Odradek",
		"name": "Psychic Backwash",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"odradek.psychic_recoil": {
		"lord": "Odradek",
		"name": "Psychic Recoil",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"odradek.reconfiguration": {
		"lord": "Odradek",
		"name": "Reconfiguration",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"odradek.breach_paradox_geometry": {
		"lord": "Odradek",
		"name": "Breach: Paradox Geometry",
		"agency": Agency.TRIGGERED_CHOICE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
		"candidate_stage": "RESOLUTION_ODRADEK_BREACH",
	},
	"kanifous.invoke": {
		"lord": "Kanifous",
		"name": "Invoke",
		"agency": Agency.TRIGGERED_CHOICE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
		"candidate_stage": "KANIFOUS_INVOKE",
	},
	"kanifous.death_pact": {
		"lord": "Kanifous",
		"name": "Death Pact",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"kanifous.breach_price_of_wishes": {
		"lord": "Kanifous",
		"name": "Breach: The Price of Wishes",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.CROSS_COMMITMENT,
	},
	"humbaba.woven_into_the_stones": {
		"lord": "Humbaba",
		"name": "Woven Into the Stones",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
	"humbaba.toll": {
		"lord": "Humbaba",
		"name": "Toll",
		"agency": Agency.PLAYER_ACTIVATED,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
		"candidate_stage": "RESOLUTION_HUMBABA_TOLL",
	},
	"humbaba.reactive_lane": {
		"lord": "Humbaba",
		"name": "Reactive Lane",
		"agency": Agency.AUTOMATIC,
		"commitment_timing": CommitmentTiming.PRE_COMMITMENT,
	},
	"humbaba.breach_stones_forget": {
		"lord": "Humbaba",
		"name": "Breach: The Stones Forget",
		"agency": Agency.PASSIVE,
		"commitment_timing": CommitmentTiming.POST_COMMITMENT,
	},
}


static func agency_name(value: int) -> String:
	match value:
		Agency.PASSIVE: return "PASSIVE"
		Agency.AUTOMATIC: return "AUTOMATIC"
		Agency.TRIGGERED_CHOICE: return "TRIGGERED_CHOICE"
		Agency.PLAYER_ACTIVATED: return "PLAYER_ACTIVATED"
		_: return "UNKNOWN"


static func commitment_timing_name(value: int) -> String:
	match value:
		CommitmentTiming.PRE_COMMITMENT: return "PRE_COMMITMENT"
		CommitmentTiming.POST_COMMITMENT: return "POST_COMMITMENT"
		CommitmentTiming.CROSS_COMMITMENT: return "CROSS_COMMITMENT"
		_: return "UNKNOWN"


static func powers_for_lord(lord_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for power_id in POWERS:
		var entry: Dictionary = POWERS[power_id]
		if String(entry.get("lord", "")) != lord_name:
			continue
		var copy := entry.duplicate(true)
		copy["id"] = String(power_id)
		out.append(copy)
	return out


static func active_powers_for_lord(lord_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in powers_for_lord(lord_name):
		if int(entry.get("agency", -1)) == Agency.PLAYER_ACTIVATED:
			out.append(entry)
	return out
