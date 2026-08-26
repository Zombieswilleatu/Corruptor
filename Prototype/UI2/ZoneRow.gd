class_name UI2ZoneRow
extends PanelContainer


const GuardPipData = preload(
	"res://Prototype/UI2/GuardPip.gd"
)

const CastleSpineData = preload(
	"res://Prototype/UI2/CastleSpine.gd"
)


const LordCardData = preload(
	"res://Prototype/UI2/LordCard.gd"
)


const CASTLE_ORDER: Array[String] = [
	"Keep",
	"Bastion",
	"SummoningCircle",
	"Stockpile",
	"SiegeEngine",
]

const BASE_LORD_GUARD_SLOTS: int = 3
const BASE_CASTLE_GUARD_SLOTS: int = 3


var zone_name: String = ""

var zone_label: Label = null
var object_box: HBoxContainer = null
var guard_box: HBoxContainer = null
var sigil_label: Label = null
var _current_reveal_all_guards: bool = false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(
		0,
		66
	)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(
		"separation",
		8
	)
	add_child(row)

	zone_label = Label.new()
	zone_label.custom_minimum_size = Vector2(
		76,
		0
	)
	zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(zone_label)

	object_box = HBoxContainer.new()
	# Card objects keep their physical card geometry. Extra row width is
	# distributed by flexible gaps rather than by stretching cards.
	object_box.custom_minimum_size = Vector2(
		460,
		0
	)
	object_box.add_theme_constant_override(
		"separation",
		5
	)
	row.add_child(object_box)

	var object_guard_gap := Control.new()
	object_guard_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	object_guard_gap.size_flags_stretch_ratio = 1.0
	row.add_child(object_guard_gap)

	guard_box = HBoxContainer.new()
	guard_box.custom_minimum_size = Vector2(
		178,
		0
	)
	guard_box.add_theme_constant_override(
		"separation",
		4
	)
	row.add_child(guard_box)

	var guard_sigil_gap := Control.new()
	guard_sigil_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guard_sigil_gap.size_flags_stretch_ratio = 1.0
	row.add_child(guard_sigil_gap)

	sigil_label = Label.new()
	sigil_label.custom_minimum_size = Vector2(
		54,
		0
	)
	sigil_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(sigil_label)


func bind_zone(
	player,
	p_zone_name: String,
	reveal_all_guards: bool
) -> void:
	if player == null:
		return

	zone_name = p_zone_name
	_current_reveal_all_guards = reveal_all_guards
	zone_label.text = zone_name.to_upper()

	# Step 0.7 introduces perspective-aware row height here. There was no
	# prior per-zone height assignment in the actual Step 0.6 local file.
	custom_minimum_size.y = _zone_height(
		zone_name,
		reveal_all_guards
	)

	_clear_children(object_box)

	if zone_name == "Castle":
		_build_castle_spines(player)
	else:
		_build_lord_object(player)

	_clear_children(guard_box)

	var guards: Array = (
		player.castle_guards
		if zone_name == "Castle"
		else player.lord_guards
	)

	var guard_slots: int = _guard_slot_count(
		player,
		zone_name,
		guards.size()
	)

	for guard_index: int in range(guard_slots):
		var guard = (
			guards[guard_index]
			if guard_index < guards.size()
			else null
		)

		var pip = GuardPipData.new()
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		guard_box.add_child(pip)

		var revealed: bool = false
		if guard != null:
			revealed = (
				reveal_all_guards
				or bool(guard.guard_revealed)
			)

		pip.bind_guard(
			guard,
			revealed
		)

	var sigil_state: String = String(
		player.sigils.get(
			zone_name,
			""
		)
	)

	var sigil_value: int = _sigil_value(sigil_state)

	sigil_label.text = "◈%s" % (
		str(sigil_value)
		if sigil_value > 0
		else "—"
	)

	sigil_label.tooltip_text = (
		"%s Sigil: %s"
		% [
			zone_name,
			sigil_state if not sigil_state.is_empty() else "none",
		]
	)


func _build_castle_spines(
	player
) -> void:
	for castle_name: String in CASTLE_ORDER:
		var spine = CastleSpineData.new()
		object_box.add_child(spine)
		spine.bind_castle(
			player,
			castle_name
		)


func _build_lord_object(
	player
) -> void:
	var lord_card = LordCardData.new()
	object_box.add_child(
		lord_card
	)

	var prominent: bool = (
		zone_name == "Lord"
		and _current_reveal_all_guards
	)

	lord_card.bind_player(
		player,
		prominent
	)


func _zone_height(
	p_zone_name: String,
	_player_side: bool
) -> float:
	if p_zone_name == "Lord":
		return 158.0

	return 132.0


func _guard_slot_count(
	player,
	p_zone_name: String,
	occupied: int
) -> int:
	var slots: int = BASE_LORD_GUARD_SLOTS

	if p_zone_name == "Castle":
		slots = BASE_CASTLE_GUARD_SLOTS

		# Current rules: Humbaba Gate 4 expands the Castle Guard zone
		# while no Castle has been ruined. Do not reserve that fourth
		# slot for every other Lord.
		if (
			String(player.lord) == "Humbaba"
			and player.ruined_castles.is_empty()
		):
			slots = 4

	# Never clip a state that already contains more Guards than the
	# nominal capacity; UI follows authoritative state.
	return maxi(
		slots,
		occupied
	)


func _sigil_value(
	state: String
) -> int:
	match state:
		"fresh":
			return 2
		"flipped":
			return 1
		_:
			return 0


func _clear_children(
	parent: Node
) -> void:
	if parent == null:
		return

	for child in parent.get_children():
		child.free()
