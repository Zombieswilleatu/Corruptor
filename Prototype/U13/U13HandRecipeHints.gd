extends PanelContainer

# Planning guidance only. Combat still validates committed cards through Rules.
const Rules = preload("res://Scripts/Sim/U13MonsterRules.gd")
const SUITS: Array = ["Penitent", "Butcher", "Vulture", "Wright"]
const READY_COLOR: Color = Color("a8d9ad")
const MISSING_COLOR: Color = Color("f2c078")
var grid: GridContainer
var empty_note: Label
var _shown: Array = []
var _missing_labels: Array[Label] = []
var _pulse: float = 0.0

static func suggestions(world: Dictionary, excluded: Array = [], pid: int = 0) -> Array:
	var state: Dictionary = world.get("monsters", {})
	if state.is_empty(): return []
	var blocked: Array = excluded.duplicate()
	# Both Stockpile offers already live in card_zones.hands until one is
	# discarded. Neither is a kept card yet: never count both toward a recipe.
	var pending: Dictionary = world.get("game_economy", {}).get("stockpile_pending", {})
	if pending.get("player_id", -1) == pid:
		blocked.append_array(pending.get("card_ids", []))
	var ids: Array = world.get("hand", []).filter(func(id): return id not in blocked)
	var rows: Array = world.get("entities", []).duplicate()
	for tray in world.get("game_staging", {}).get("lanes", {}).values():
		rows.append_array(tray.get("units", []))
	rows.append_array(world.get("marcher_staging", {}).get("units", []))
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for row in rows:
		if row.kind != "card" or row.id not in ids or seen.has(row.id): continue
		seen[row.id] = true
		var suit: String = row.attributes.suit
		counts[suit] = counts.get(suit, 0) + 1
	var ready: Array = []
	var near: Array = []
	for monster in Rules.NAMES:
		if monster not in state.get("unlocked", [[], []])[pid]: continue
		if Rules.limited(monster) and Rules.living(rows, pid, monster): continue
		var missing: int = 0
		var missing_suit: String = ""
		var recipe: Dictionary = Rules.ROSTER[monster].recipe
		for suit in recipe:
			var deficit: int = maxi(0, int(recipe[suit]) - int(counts.get(suit, 0)))
			missing += deficit
			if deficit > 0: missing_suit = suit
		if missing > 1: continue
		var hint: Dictionary = {"monster": monster, "recipe": recipe.duplicate(), "missing_suit": missing_suit}
		if missing == 0: ready.append(hint)
		else: near.append(hint)
	return ready + near

func _ready() -> void:
	name = "HandRecipeHints"
	custom_minimum_size = Vector2(440, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 0.55
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1c1a16")
	style.border_color = Color("75603d")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	var title := _label("GRIMOIRES", 15)
	column.add_child(title)
	title.tooltip_text = "READY: available cards meet the grimoire. STAGED: its cards are already committed to Hunt or Siege. ONE AWAY: missing exactly one card. Cards allocated to Ward, Guards, powers, rites or other costs do not count. Stockpile offers are excluded until kept. Each grimoire is an alternative; they may share cards."
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(grid)
	empty_note = _label("No grimoires ready or one card away.", 13)
	empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(empty_note)
	var note := _label("READY: cards available · STAGED: cards in Hunt / Siege", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	hide()
	set_process(false)

func show_for(world: Dictionary, excluded: Array = [], combat_cards: Array = []) -> void:
	var hints: Array = suggestions(world, excluded)
	var staged: Array = combat_cards.filter(func(id): return id in world.get("hand", []) and id not in excluded)
	for hint in hints:
		if hint.missing_suit.is_empty() and Rules.qualifies(world.get("entities", []), staged, hint.monster):
			hint["staged"] = true
	show()
	if hints != _shown:
		_shown = hints
		_missing_labels.clear()
		_pulse = 0.0
		for child in grid.get_children():
			if child == empty_note: continue
			grid.remove_child(child)
			child.queue_free()
		for hint in hints: _add_hint(hint)
	empty_note.visible = hints.is_empty()
	set_process(not _missing_labels.is_empty())

func dismiss() -> void:
	hide()
	set_process(false)

func _add_hint(hint: Dictionary) -> void:
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 0)
	tile.tooltip_text = "%s: %s\n%s" % [hint.monster, Rules.recipe_text(hint.monster), Rules.ROSTER[hint.monster].ability]
	grid.add_child(tile)
	var ready: bool = hint.missing_suit.is_empty()
	var status: String = "STAGED" if hint.get("staged", false) else ("READY" if ready else "ONE AWAY")
	var heading := _label(hint.monster + " · " + status, 14)
	heading.add_theme_color_override("font_color", READY_COLOR if ready else MISSING_COLOR)
	tile.add_child(heading)
	var ingredients := HBoxContainer.new()
	ingredients.add_theme_constant_override("separation", 4)
	tile.add_child(ingredients)
	for suit in SUITS:
		if not hint.recipe.has(suit): continue
		if ingredients.get_child_count() > 0: ingredients.add_child(_label("+", 12))
		var ingredient := _label("%d %s" % [hint.recipe[suit], suit], 12)
		ingredients.add_child(ingredient)
		if suit == hint.missing_suit:
			ingredient.text = "%d/%d %s" % [int(hint.recipe[suit]) - 1, hint.recipe[suit], suit]
			ingredient.add_theme_color_override("font_color", MISSING_COLOR)
			ingredient.tooltip_text = "Need 1 more " + suit
			_missing_labels.append(ingredient)

func _label(value: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.mouse_filter = Control.MOUSE_FILTER_PASS
	return result

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_pulse = fmod(_pulse + delta, 2.4)
	for label in _missing_labels:
		label.modulate.a = 0.78 + 0.22 * (0.5 + 0.5 * cos(_pulse * TAU / 2.4))
