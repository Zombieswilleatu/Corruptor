# COMMITMENT_TIMING_CLASSIFICATION_V1
class_name CommitmentTimingContractTests
extends RefCounted

const ManifestData = preload(
	"res://Scripts/Sim/HumanContractManifest.gd"
)

const EXPECTED: Dictionary = {
	"orias.marked_prey": "POST_COMMITMENT",
	"orias.snare": "PRE_COMMITMENT",
	"orias.barbed_web": "POST_COMMITMENT",
	"orias.relentless_pursuit": "CROSS_COMMITMENT",
	"orias.breach_frenzy": "PRE_COMMITMENT",
	"deimos.war_machine": "POST_COMMITMENT",
	"deimos.fear_aura": "POST_COMMITMENT",
	"deimos.claim_the_breach": "POST_COMMITMENT",
	"deimos.breach_cracked_foundations": "POST_COMMITMENT",
	"valak.crushing_presence": "POST_COMMITMENT",
	"valak.siphon": "POST_COMMITMENT",
	"valak.projection": "POST_COMMITMENT",
	"valak.breach_gravitational_collapse": "POST_COMMITMENT",
	"kroni.hunger_track_defense": "CROSS_COMMITMENT",
	"kroni.consume": "POST_COMMITMENT",
	"kroni.cannibal_hunger": "POST_COMMITMENT",
	"kroni.hungering_aura": "POST_COMMITMENT",
	"kroni.ravenous": "POST_COMMITMENT",
	"kroni.corruption_milestone": "POST_COMMITMENT",
	"kroni.breach_insatiable_hunger": "POST_COMMITMENT",
	"kalligan.master_builder": "PRE_COMMITMENT",
	"kalligan.pyroclasm": "POST_COMMITMENT",
	"kalligan.wildfire": "CROSS_COMMITMENT",
	"kalligan.inferno": "POST_COMMITMENT",
	"kalligan.breach_rapid_construction": "PRE_COMMITMENT",
	"gremory.picking_the_bones": "PRE_COMMITMENT",
	"gremory.predator_of_ruin": "POST_COMMITMENT",
	"gremory.ruinous_harvest": "CROSS_COMMITMENT",
	"gremory.inevitable_ruin": "POST_COMMITMENT",
	"gremory.breach_sifting_the_ruins": "PRE_COMMITMENT",
	"odradek.psychic_backwash": "POST_COMMITMENT",
	"odradek.psychic_recoil": "POST_COMMITMENT",
	"odradek.reconfiguration": "POST_COMMITMENT",
	"odradek.breach_paradox_geometry": "POST_COMMITMENT",
	"kanifous.invoke": "POST_COMMITMENT",
	"kanifous.death_pact": "POST_COMMITMENT",
	"kanifous.breach_price_of_wishes": "CROSS_COMMITMENT",
	"humbaba.woven_into_the_stones": "POST_COMMITMENT",
	"humbaba.toll": "POST_COMMITMENT",
	"humbaba.reactive_lane": "PRE_COMMITMENT",
	"humbaba.breach_stones_forget": "POST_COMMITMENT",
}


static func _result(
	name: String,
	passed: bool,
	message: String
) -> Dictionary:
	return {
		"name": name,
		"passed": passed,
		"text": "%s  %s - %s" % [
			"PASS" if passed else "FAIL",
			name,
			message,
		],
	}


static func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var exact := EXPECTED.size() == ManifestData.POWERS.size()
	var pre_count := 0
	var post_count := 0
	var cross_count := 0

	for power_id in EXPECTED:
		if not ManifestData.POWERS.has(power_id):
			exact = false
			continue
		var entry: Dictionary = ManifestData.POWERS[power_id]
		var actual := ManifestData.commitment_timing_name(
			int(entry.get("commitment_timing", -1))
		)
		if actual != String(EXPECTED[power_id]):
			exact = false
		match actual:
			"PRE_COMMITMENT": pre_count += 1
			"POST_COMMITMENT": post_count += 1
			"CROSS_COMMITMENT": cross_count += 1
			_: exact = false

	var counts_ok := (
		pre_count == 7
		and post_count == 29
		and cross_count == 5
	)

	results.append(
		_result(
			"TIMING_SCHEMA",
			exact and counts_ok,
			"%d PRE / %d POST / %d CROSS across 41 powers" % [
				pre_count,
				post_count,
				cross_count,
			]
		)
	)

	for lord_name in ManifestData.LORDS:
		var lord_ok := true
		var parts: Array[String] = []
		for power_id in EXPECTED:
			var entry: Dictionary = ManifestData.POWERS.get(power_id, {})
			if String(entry.get("lord", "")) != lord_name:
				continue
			var actual := ManifestData.commitment_timing_name(
				int(entry.get("commitment_timing", -1))
			)
			var expected := String(EXPECTED[power_id])
			if actual != expected:
				lord_ok = false
			parts.append("%s=%s" % [
				String(entry.get("name", power_id)),
				actual.trim_suffix("_COMMITMENT"),
			])

		results.append(
			_result(
				"%s/COMMITMENT_TIMING" % lord_name.to_upper(),
				lord_ok,
				", ".join(parts)
			)
		)

	return results
