extends RefCounted

# U13 rules text is separate from the printed art and from legacy U12 cards.
const RULES: Dictionary = {
	"Valak": {
		"passive": "LIFE ESSENCE\nEnemy Guards defeated by your Hunt or Siege grant 2 Essence each, capped at 5. Unreserved Essence absorbs incoming Hunt strength after Ward.\n\nPROJECTION\nReserve 1–5 stored Essence and an enemy Lord or Castle Guard zone during submission. After combat, defeat its highest-value Guard at or below the spend. A miss still spends Essence. Projection kills grant no Essence.",
		"breach": "GRAVITATIONAL COLLAPSE\nAll Marchers move at 50% speed while Valak is in the Breach."
	},
	"Kroni": {
		"passive": "HUNGER\nStarts at 0. Defense is 4 at 0 Hunger, 6 at 1–2, and 8 at 3+. Ward or Pass loses 1 Hunger. First reaching 3 each game grants 1 personal Tear.\n\nCANNIBAL HUNGER\nAfter the round-start Consume check, if Consume did not feed Kroni, devour your lowest-value Guard. If none exists, lose 1 Hunger. Eating your own Guard does not increase Hunger.",
		"breach": "INSATIABLE HUNGER\nOnce each Marching phase, manifest at a random field point and move briefly in a random direction. Devour any friendly or enemy Marchers touched, then disappear. This grants no Hunger, Souls, Tears or Ravenous progress."
	},
	"Odradek": {
		"passive": "RECONFIGURATION\nGain 1 each round while active, up to 4. Banishment resets it to 0. Spend it on powers during submission.\n\nPSYCHIC INTERLOCK\nOnce per round, after an enemy Marcher kills one of yours, reflect the killing attack's damage onto the attacker. Armor applies; the original kill still happens.",
		"breach": "PARADOX GEOMETRY\nOnce per round after combat, randomly change allegiance: one Lord Guard, one Castle Guard, or all Marchers in a small circle around a random Marcher. Only legal transfers are chosen. Either side can benefit."
	},
	"Orias": {
		"passive": "RELENTLESS PURSUIT\nHunts gain +1 Strength, plus another +1 against a Lord at Threat 2+.\n\nACCELERATE\nThe first enemy Lord Guard you defeat each round adds 1 Threat to that Lord.\n\nTHE MARK\nBanish a Lord at Threat 3+ to gain 2 Souls, place 1 Neutral Tear and mark it. A marked Lord returns with +1 Threat.",
		"breach": "ENTANGLEMENT\nPlayers at Threat 2+ may deploy no more than 2 Guards total during Development. Applies when this Breach is active before submission."
	},
	"Gremory": {
		"passive": "PICKING THE BONES\nOnce per round, when your Vulture Marcher kills an enemy Marcher in combat, draw 1 card and place 1 Neutral Tear.\n\nSIFTING THE RUINS\nAfter the first Castle is destroyed each round, take the top discard into your Hand.",
		"breach": "GEM DAGGER\nThe first Guard defeated each round makes both players draw 1 card."
	},
	"Deimos": {
		"passive": "THE WAR FOUNDRY\nYou may reconstruct a Ruined Siege Engine using normal Construction rules. A Profaned Engine cannot be reconstructed.\n\nFEAR AURA\nWhen you Siege, return the lowest-value enemy Castle Guards to their owner's Hand: 1 Guard plus 1 per Threat.\n\nSPOILS OF WAR\nThe first Castle you ruin grants an additional personal Tear. Later ruins grant an additional Neutral Tear.",
		"breach": "CRACKED FOUNDATIONS\nAll Castles have 5 less maximum Integrity. Ending this Breach restores the ceiling without healing damage."
	},
	"Humbaba": {
		"passive": "DEFENSE\nDefense is 2 plus your standing Castles. Humbaba has no Threat stat.\n\nENDURANCE OF THE FAITHFUL\nAt the end of Marching, place 1 Neutral Tear if at least one of your Penitents has exactly 1 HP and Humbaba is active.",
		"breach": "THE STONES FORGET\nOn entering the Breach, deal 4 damage to every exposed Castle. This happens on entry, not every round."
	},
	"Kalligan": {
		"passive": "FORGE-REPAIR\nAt round start, each of your damaged standing Castles restores 2 Integrity. Ruined and Profaned Castles cannot be restored.\n\nREKINDLE\nOnce per round, when one of your Defunct Castles becomes operational, place 1 Neutral Tear.",
		"breach": "RAPID CONSTRUCTION\nAt round start, both players' damaged standing Castles restore 2 Integrity. Ruined and Profaned Castles are unaffected. Forge-Repair does not stack while Kalligan is Banished."
	}
}


static func for_lord(lord: String) -> Dictionary:
	return RULES.get(lord, {"passive": "No passive rules available.", "breach": "No Breach rules available."})
