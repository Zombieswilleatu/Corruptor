extends RefCounted
# A recorded presentation result uses the same install path as a worker, but
# never starts a thread or executes a simulation hook.
var result: Dictionary = {}
func started() -> bool: return true
func ready() -> bool: return true
func take() -> Dictionary: return result
func join_on_exit() -> void: pass
