extends RefCounted


# Public, read-only presentation of registry records. Never owns a lifetime.
static func records(active: Array, pending: Array, round_number: int) -> Array:
	var result: Array = []
	for row in active:
		if row.get("payload", {}).get("hazard") != "scorch":
			continue
		result.append(
			{
				"id": row.effect_id,
				"owner": row.declaration.player_id,
				"target": row.target.duplicate(true),
				"intensity": int(row.stages[row.stage_index].intensity),
				"remaining": maxi(0, int(row.activated_round) + row.stages.size() - round_number),
				"fire_round": 0
			}
		)
	for row in pending:
		if row.get("declaration", {}).get("power_id") != "Inferno":
			continue
		result.append(
			{
				"id": row.effect_id,
				"owner": row.declaration.player_id,
				"target": row.declaration.target.duplicate(true),
				"intensity": 0,
				"remaining": 0,
				"fire_round": int(row.fire_round)
			}
		)
	return result


static func target_name(target: Dictionary) -> String:
	if target.get("kind") == "lane":
		return String(target.lane) + " lane · both sides"
	return (
		("Your " if target.get("player_id") == 0 else "Enemy ")
		+ String(target.get("lane", ""))
		+ " Guards"
	)


static func active_for(rows: Array, owner: int) -> Dictionary:
	for row in rows:
		if row.owner == owner and row.fire_round == 0 and row.remaining > 0:
			return row
	return {}


static func badge(row: Dictionary) -> String:
	if row.fire_round > 0:
		return "FIRE NEXT R%d" % row.fire_round
	return "SCORCH %d · %dr" % [row.intensity, row.remaining]
