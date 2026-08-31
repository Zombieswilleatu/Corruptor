# UI2_CASTLE_CARD_TEXT_V1
# Castle rules copy lives here instead of being baked into the art.
# Edit this file when Castle wording changes; the PNGs never need repainting.
class_name UI2CastlePowerText
extends RefCounted


const POWER_NAMES: Dictionary = {
	"Keep": "FORTIFICATION",
	"Bastion": "FORTIFIED LAYERS",
	"SummoningCircle": "BLOOD CONDUIT / BLOOD OFFERING",
	"Stockpile": "SELECTIVE STORES",
	"SiegeEngine": "FORGE DISCIPLINE",
}


const COMPACT_TEXT: Dictionary = {
	"Keep": "After Lord defenses, remaining Hunt Strength hits the Keep first. Operational: reduce it by 3.",
	"Bastion": "Sieges strike Bastion before another Castle.",
	"SummoningCircle": "Exert Integrity to resist Threat or cheapen Summon.",
	"Stockpile": "Draw 2 extra; keep 1 and discard 1.",
	"SiegeEngine": "Sieges use full printed attack value.",
}


const FULL_TEXT: Dictionary = {
	"Keep": (
		"When your Lord is Hunted, resolve Ward, Lord Guards, and Sigil first. "
		+ "Any Hunt Strength still remaining is redirected to the Keep. While "
		+ "the Keep is Operational, reduce that remaining Strength by 3 before "
		+ "damaging the Keep. If the Keep is reduced to 0, only excess Strength "
		+ "continues to your Lord."
	),
	"Bastion": (
		"When a different Castle is Sieged, a standing Bastion absorbs arriving "
		+ "Strength first; overflow continues into the target. This screen "
		+ "remains while Bastion is Defunct. A Siege aimed directly at Bastion "
		+ "does not spill into another Castle."
	),
	"SummoningCircle": (
		"BLOOD CONDUIT — When a Threat gain would cross a Lord-DEF breakpoint, "
		+ "Exert 3 Integrity to prevent 1 Threat. BLOOD OFFERING — When "
		+ "Summoning, Exert 3 Integrity to reduce the Summon cost by 3. "
		+ "Exertion can make the Circle Defunct but cannot Ruin it."
	),
	"Stockpile": (
		"During Draw, draw 2 additional cards, keep 1, and discard 1. "
		+ "You still net one extra card, but you choose which of the two new "
		+ "cards survives."
	),
	"SiegeEngine": (
		"FORGE DISCIPLINE — During Siege, every committed suit contributes its "
		+ "full printed value; ignore the normal off-suit attack penalty."
	),
}


static func power_name(
	castle_name: String
) -> String:
	return String(
		POWER_NAMES.get(
			castle_name,
			"CASTLE POWER"
		)
	)


static func compact_text(
	castle_name: String
) -> String:
	return String(
		COMPACT_TEXT.get(
			castle_name,
			""
		)
	)


static func full_text(
	castle_name: String
) -> String:
	return String(
		FULL_TEXT.get(
			castle_name,
			""
		)
	)
