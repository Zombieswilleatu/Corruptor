extends RefCounted

const VERSION: String = "U13_BOT_PUBLIC_GUARDS_V2"

# Both human and bot read the same deployed Guard faces and values.
# The authority projection still protects hands and simultaneous submissions.
var _authority
var _pid: int
var _view: Dictionary

func _init(authority, pid: int) -> void:
	_authority = authority
	_pid = pid
	_view = authority.player_view(pid, 0)

func player_view(pid: int, _history_limit: int = 0) -> Dictionary:
	return {"action": "invalid", "reason": "bot_view_player_mismatch"} if pid != _pid else _view.duplicate(true)

func legal_power_candidates(pid: int, sources: Array) -> Array:
	return [] if pid != _pid else _authority.legal_power_candidates(pid, sources)

func legal_order_candidates(pid: int, powers: Array, orders: Array) -> Array:
	return [] if pid != _pid else _authority.legal_order_candidates(pid, powers, orders)

func preview_submission(pid: int, powers: Array, order: Dictionary) -> Dictionary:
	return {"action": "invalid", "reason": "bot_view_player_mismatch"} if pid != _pid else _authority.preview_submission(pid, powers, order)

func canonical_plan(plan: Dictionary) -> Dictionary:
	# Public Guard IDs already match authority; retain an owned plan boundary.
	return plan.duplicate(true)
