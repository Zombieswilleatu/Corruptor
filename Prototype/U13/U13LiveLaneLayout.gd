extends RefCounted

# Geometry shared by rendering, mouse targeting, projectiles and reserve trays.
static func column(size: Vector2, lane: String) -> Rect2:
	var width: float = (size.x - 42) / 2.0
	return Rect2(16 + (width + 10) * (1 if lane == "Castle" else 0), 0, width, size.y)

static func travel(size: Vector2, lane: String) -> Rect2:
	var rect: Rect2 = column(size, lane)
	return Rect2(rect.position.x, 220, rect.size.x, maxf(140, size.y - 394))

static func draw(board) -> void:
	board.draw_rect(Rect2(Vector2.ZERO, board.size), Color("0e100f"))
	var font: Font = ThemeDB.fallback_font
	for lane in ["Lord", "Castle"]:
		var rect: Rect2 = travel(board.size, lane)
		var col: Rect2 = column(board.size, lane)
		board.draw_string(font, Vector2(col.position.x, 46), lane.to_upper() + " LANE", HORIZONTAL_ALIGNMENT_CENTER, col.size.x, 15, Color("ebdab4"))
		board._scenery(Rect2(rect.position.x, 172, rect.size.x, rect.end.y - 164), Rect2(0.36, 0.10, 0.24, 0.82))
		board.draw_rect(rect, Color("68583b"), false, 1)
		for aura in board.active_auras:
			if aura.lane == lane:
				board.draw_rect(rect, Color(Color("9fddb5") if aura.owner == 0 else Color("efada5"), 0.08))
		board.scorch_visuals.draw_area(board, rect, lane)
		board.breath_visuals.draw_lane(board, rect, lane)
		for web in board.active_webs:
			if web.target.lane == lane:
				board.web_visuals.draw_area(board, board.WebVisuals.region_rect(rect, web.target.field_position, int(web.payload.spatial_field.radius_fp)), rect, board._round > int(web.activated_round))
		board._draw_monster_fields(lane)
		board.fortification_visual.draw(board, lane, board.field_structures, board._units)
		var ordered: Array = board._units.duplicate()
		ordered.sort_custom(func(a, b):
			var ax: float = board.SpriteVisuals.position_of(a).x
			var bx: float = board.SpriteVisuals.position_of(b).x
			return ax > bx if ax != bx else str(a.id) < str(b.id))
		for unit in ordered:
			if unit.attributes.lane != lane or board.deaths.seen.has(unit.id): continue
			var center: Vector2 = board._monster_point(unit.attributes)
			board._draw_chit(unit, center)
			if unit.attributes.waiting:
				board.draw_string(font, center + Vector2(-28, 15), "SUPPLICANT", HORIZONTAL_ALIGNMENT_LEFT, 70, 10, Color("ebdab4"))
		# Keep active and queued lane effects visible above the fighting space.
		var notes: PackedStringArray = []
		for aura in board.active_auras:
			if aura.lane == lane: notes.append("%s BREATH %dr" % ["Y" if aura.owner == 0 else "E", aura.remaining])
		for scorch in board.active_scorches:
			if scorch.target.kind == "lane" and scorch.target.lane == lane:
				notes.append("%s FIRE %s" % ["Y" if scorch.owner == 0 else "E", "%d/%dr" % [scorch.intensity, scorch.remaining] if scorch.fire_round == 0 else "R%d" % scorch.fire_round])
		board.draw_string(font, Vector2(rect.position.x, 187), " · ".join(notes), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, Color("ffcc9a"))
	board._draw_monster_attacks()
	board.projectile_visual.draw(board, board.projectiles)
	board.deaths.draw(board)
	board._draw_charm_markers()
