extends RefCounted

const VERSION: String = "U13_BOT_GUARD_SLOTS_V1"

# Bot-only information boundary. U13's presentation projection currently carries
# concealed guard faces; policies receive only occupied slots.
# Slot handles also hide the suit/tier encoded in physical card identity strings.
var _authority
var _pid: int
var _view: Dictionary
var _to_server: Dictionary = {}
var _to_bot: Dictionary = {}

func _init(authority, pid: int) -> void:
	_authority = authority
	_pid = pid
	_view = authority.player_view(pid, 0)
	if _view.get("action") == "invalid":
		return
	for row in _view.world.entities:
		if row.kind == "card" and row.owner != pid and row.attributes.get("role") == "guard":
			var handle: String = "hidden_guard:%d:%s:%d" % [row.owner, row.attributes.lane, row.attributes.slot]
			_to_server[handle] = row.id
			_to_bot[row.id] = handle
			row.origin = "concealed_guard"
			row.ordinal = row.attributes.slot
			row.attributes = {"role": "guard", "lane": row.attributes.lane, "slot": row.attributes.slot, "concealed": true}
	_view = _map(_view, _to_bot)

func _map(value, replacements: Dictionary):
	if typeof(value) == TYPE_STRING:
		return replacements.get(value, value)
	if typeof(value) == TYPE_ARRAY:
		return value.map(func(x): return _map(x, replacements))
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key in value:
			result[_map(key, replacements)] = _map(value[key], replacements)
		return result
	return value

func player_view(pid: int, _history_limit: int = 0) -> Dictionary:
	return {"action": "invalid", "reason": "bot_view_player_mismatch"} if pid != _pid else _view.duplicate(true)

func legal_power_candidates(pid: int, sources: Array) -> Array:
	return _map(_authority.legal_power_candidates(pid, _map(sources, _to_server)), _to_bot)

func legal_order_candidates(pid: int, powers: Array, orders: Array) -> Array:
	return _map(_authority.legal_order_candidates(pid, _map(powers, _to_server), _map(orders, _to_server)), _to_bot)

func preview_submission(pid: int, powers: Array, order: Dictionary) -> Dictionary:
	return _authority.preview_submission(pid, _map(powers, _to_server), _map(order, _to_server))

func canonical_plan(plan: Dictionary) -> Dictionary:
	# Translate only after the policy finishes choosing; no face information is
	# supplied by this mapping, and the real submit path revalidates every order.
	return _map(plan, _to_server)
