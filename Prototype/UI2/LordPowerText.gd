# UI2_LORD_BACK_POWER_TEXT_V1
class_name UI2LordPowerText
extends RefCounted


const POWER_FONT_PATH: String = "res://Fonts/Grenze_Gotisch/GrenzeGotisch-VariableFont_wght.ttf"

const POWERS: Dictionary = {
	"Orias": [
		"[color=#8fc9a3][b]PRE-COMMIT[/b][/color] · [b]Snare[/b] — At the start of Development, if Orias is living and below Threat 3, gain 1 Threat to restrict the enemy Lord to one total Guard move this Development.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Relentless Pursuit[/b] — Hunts gain +1 strength, plus another +1 against a Lord at Threat 2+.",
		"[color=#c5a0d8][b]CROSS-COMMIT[/b][/color] · [b]The Mark[/b] — Defeating a Lord Guard raises that Lord's Threat (2 at Threat 2+). Banishing a Lord at Threat 3+ grants +2 bonus Souls and marks it; it returns with +1 Threat. Orias bypasses that marked target's Recoil/Backwash.",
		"[color=#8fc9a3][b]PRE-COMMIT[/b][/color] · [b]Breach: Frenzy[/b] — Players at Threat 3+ cannot Deploy cards from Garrison to Guard zones.",
	],
	"Deimos": [
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]War Machine[/b] — Sieges gain +2 strength, reduced by 1 for each of Deimos's Ruined or Profaned Castles (minimum +0).",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Fear[/b] — Before a Siege against 2+ Castle Guards, return the lowest Guard to its owner's Hand.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Claim the Breach[/b] — The first Castle Deimos ruins each game gives Deimos the Tear instead of adding a Neutral Tear.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Breach[/b] — Every active Castle has 1 less structural DEF (minimum 0).",
	],
	"Valak": [
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Crushing Presence[/b] — On Hunt or Siege against 2+ Guards, the lowest Guard contributes no defense.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Siphon / Life Essence[/b] — Each enemy Guard defeated by Valak's Hunt or Siege grants 2 Life Essence (max 5). Stored Essence persists and automatically reinforces incoming Hunts after ordinary Ward.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Projection[/b] — Once after primary and Reflex combat, spend 1–5 Life Essence on the enemy Lord or Castle Guard zone. Defeat the highest Guard there with printed value at or below the amount spent; a whiff still spends the Essence. Projection kills do not generate Life Essence.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Breach: Gravitational Collapse[/b] — At Resolution Prelude, each previously attacked zone loses its lowest Guard.",
	],
	"Kroni": [
		"[color=#c5a0d8][b]CROSS-COMMIT[/b][/color] · [b]HUNGER[/b] — a counter that persists across rounds and resets when Kroni is resummoned. Lord DEF is 4 at 0, 6 at 1–2, and 8 at 3+. The first time he reaches 3 each game, gain 1 personal Tear. Warding or Passing loses 1 Hunger.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Consume[/b] — Once per round, after the first combat in which at least 1 Guard or Castle is destroyed, gain 1 Hunger.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Cannibal Hunger[/b] — At Hunger 1+, end each round by removing your lowest deployed Lord or Castle Guard from play; if none is deployed, lose 1 Hunger. The meal grants no Hunger. At Hunger 0, if Consume did not fire, remove your lowest deployed Guard from play without gaining Hunger. Garrison cannot be consumed.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Ravenous[/b] — At Hunger 3+, discard the opponent's lowest committed card. His next destroyed Lord or Castle grants +2 Souls and +1 Hunger.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Breach — Insatiable Hunger[/b] — While Kroni is Banished, both players lose their lowest Guard each round.",
	],
	"Kalligan": [
		"[color=#c5a0d8][b]CROSS-COMMIT[/b][/color] · [b]SCORCH[/b] — A persistent fire starts at level 1, rises by 1 each round to 3, and defeats Guards at or below its level. It also burns matching-lane marchers at current value 2 or less. Each round it stands, gain Flame tokens equal to its level; 5 Flame becomes 1 Soul.",
		"[color=#8fc9a3][b]PRE-COMMIT[/b][/color] · [b]Forge-Repair[/b] — A living Kalligan restores +2 Integrity once per Repair action. After each such Repair, choose the enemy Lord or Castle zone for Scorch.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Pyroclasm[/b] — Sieges gain +1 strength, or +2 if the defender already has a Ruined Castle.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Wildfire / Inferno[/b] — After ruining a Castle, choose the enemy Lord or surviving Castle zone for Scorch. Inferno defeats the highest enemy Lord Guard without gaining Threat; if none exists, Scorch the Lord zone.",
		"[color=#8fc9a3][b]PRE-COMMIT[/b][/color] · [b]Breach[/b] — Every Repair restores +1 additional Integrity.",
	],
	"Gremory": [
		"[color=#8fc9a3][b]PRE-COMMIT[/b][/color] · [b]Picking the Bones[/b] — At the start of Development, if Gremory controls at least one Ruined Castle, draw 1 extra card. Profaned Castles and enemy Ruins do not count.",
		"[color=#c5a0d8][b]CROSS-COMMIT[/b][/color] · [b]Ruinous Harvest[/b] — On the first Tear placed each round, search from the top of the discard for a value-4/5 card and take it. The attempt is spent even if no eligible card exists.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Predator of Ruin[/b] — The first Castle destroyed each round recovers the top discard. Independently, the first Lord Guard Defeated by any effect lets Gremory draw 1 outside the Draw step, then discard the lowest Hand card.",
		"[color=#c5a0d8][b]CROSS-COMMIT[/b][/color] · [b]Inevitable Ruin / Breach: Sifting the Ruins[/b] — At End of Round, after your Siege deals Integrity damage to an Operational Castle and it remains standing, discard exactly 2 Hand/Garrison cards totaling face value 5+ to set it to Defunct (6 Integrity). It remains standing, repairable, and is not Ruined. During Gremory Breach, each player with at least one Ruined Castle draws 1 extra; Profaned Castles do not count.",
	],
	"Odradek": [
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Psychic Recoil / Interlock[/b] — Once each round when living Odradek is Hunted or Sieged by an attack with at least 2 currently committed cards, take the attacker's second-highest committed card and bank it face-up, gaining 1 Soul. A new card replaces the bank only if strictly larger; otherwise Recoil locks. Odradek automatically spends the bank on his next Hunt or Siege.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Reconfiguration[/b] — If fewer than 2 Odradek Guards were Defeated this round, gain 1 token. At 3 tokens, spend them to place 1 Neutral Tear. Banishment clears tokens.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Breach: Paradox Geometry[/b] — Predict the second-action winner's action; a correct guess discards their selected cards and lets Odradek execute it instead.",
	],
	"Kanifous": [
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Invoke[/b] — After Reveal, discard one Hand card as the toll, reveal 2 cards, choose one to bank in Garrison, and discard the other. With no Hand card, Invoke does not fire and the reveals return to the deck.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Suit Invocation[/b] — Vulture: draw 3 then discard the lowest Hand card. Wright: move up to 2 Lord Guards to Castle. Penitent: draw 2 temporary Guards. Butcher: treat the lowest target Guard as already Defeated this round, without triggering Defeat effects.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Resonance / Defiance[/b] — If the chosen card's value equals current Threat, gain 1 Soul. A value-4+ first reveal creates a Neutral Tear. When Kanifous is banished, gain 1 Soul and draw 2 if still behind the attacker.",
		"[color=#c5a0d8][b]CROSS-COMMIT[/b][/color] · [b]Breach[/b] — Every draw outside the Draw step gives its recipient +1 Threat.",
	],
	"Humbaba": [
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Woven Into the Stones[/b] — Lord DEF equals 2 + standing Castles; Threat reductions still apply. Bastion no longer adds Lord DEF.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Toll[/b] — Once per round under severe Soul pressure, ruin one of Humbaba's own Castles to remove 1 enemy Soul and create 1 Neutral Tear.",
		"[color=#8fc9a3][b]PRE-COMMIT[/b][/color] · [b]Reactive Lane[/b] — Humbaba may hold a second marcher only as a response. An enemy marcher must already occupy the lane, and the new marcher is forced into it; Humbaba cannot open two attacks.",
		"[color=#d7a26a][b]POST-COMMIT[/b][/color] · [b]Breach: The Stones Forget[/b] — While Humbaba is Banished, every active Castle has 1 less structural DEF (minimum 1).",
	],
}


static func power_count(
	lord_name: String
) -> int:
	var entries = POWERS.get(
		lord_name,
		[]
	)
	return entries.size()


static func bbcode_for(
	lord_name: String
) -> String:
	var entries = POWERS.get(
		lord_name,
		[]
	)

	var chunks: Array[String] = [
		"[center][b]%s — POWERS[/b][/center]"
		% lord_name.to_upper(),
	]

	for raw_entry in entries:
		chunks.append(
			String(raw_entry)
		)

	return "\n\n".join(chunks)


static func breach_bbcode_for(
	lord_name: String
) -> String:
	var entries = POWERS.get(
		lord_name,
		[]
	)

	var breach_entry: String = ""
	for raw_entry in entries:
		var entry: String = String(raw_entry)
		if "breach" in entry.to_lower():
			breach_entry = entry
			break

	if breach_entry.is_empty():
		breach_entry = "[i]No Breach power is defined for this Lord.[/i]"

	return "[center][b]%s — THE BREACH[/b][/center]\n\n%s" % [
		lord_name.to_upper(),
		breach_entry,
	]


static func font() -> Font:
	if not ResourceLoader.exists(
		POWER_FONT_PATH
	):
		return null

	var resource = load(
		POWER_FONT_PATH
	)
	return resource if resource is Font else null
