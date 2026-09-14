# Frozen e4d9501 installer, including its existing validation cache.
extends "res://Scripts/Sim/U13Match.gd"

func _install_world(raw: Dictionary) -> Dictionary:
	if (
		not Data.is_data(raw)
		or typeof(raw.get("players")) != TYPE_ARRAY
		or raw.players.size() != 2
		or typeof(raw.get("entities")) != TYPE_DICTIONARY
		or typeof(raw.get("data")) != TYPE_DICTIONARY
	):
		return Data.invalid("world_data_invalid")
	# Always enforce the raw plain-data/type boundary before comparison. Normalize
	# as ordinary install does: equivalent JSON integer/float encodings are safe.
	# No hashes, mutable object identity, or unchecked caller-provided cache tokens.
	if _cache_world_validation and not _world_validation_cache.is_empty() and _world_validation_cache.validator == _world_validator:
		var canonical: Dictionary = Data.copy_data(raw)
		# Native Variant bytes preserve types (including bool versus integer).
		# A different dictionary insertion order only causes a harmless cache miss.
		if var_to_bytes(canonical) == _world_validation_cache.encoded:
			_world = canonical
			_entities = _world_validation_cache.entities._fork()
			_world_cache_hits += 1
			return {"action": "u13_world_installed"}
	_world_validations += 1
	var candidate = Entities.new()
	if candidate.restore(raw.entities).action == "invalid":
		return Data.invalid("world_entities_invalid")
	for player_id in [0, 1]:
		var player = raw.players[player_id]
		if (
			typeof(player) != TYPE_DICTIONARY
			or typeof(player.get("lord_id")) != TYPE_STRING
			or typeof(player.get("lord_entity_id")) != TYPE_STRING
			or typeof(player.get("resources")) != TYPE_DICTIONARY
		):
			return Data.invalid("world_player_invalid")
		var lord: Dictionary = candidate.get_entity(player.lord_entity_id)
		if (
			lord.is_empty()
			or lord.kind != "lord"
			or lord.owner != player_id
			or lord.attributes.get("lord_id") != player.lord_id
			or typeof(lord.attributes.get("alive")) != TYPE_BOOL
		):
			return Data.invalid("world_lord_invalid")
		for amount in player.resources.values():
			if not Data.is_integer(amount) or amount < 0:
				return Data.invalid("world_resources_invalid")
	if raw.data.has("card_zones") and not Cards.valid(raw):
		return Data.invalid("world_card_zones_invalid")
	if _world_validator.is_valid():
		var accepted = _world_validator.call(Data.copy_data(raw))
		if typeof(accepted) != TYPE_BOOL or not accepted:
			return Data.invalid("content_world_invalid")
	_world = Data.copy_data(raw)
	_entities = candidate
	if _cache_world_validation:
		_world_validation_cache = {"encoded": var_to_bytes(_world), "entities": _entities._fork(), "validator": _world_validator}
	return {"action": "u13_world_installed"}


static func from_owner(owner):
	var candidate = load("res://Scripts/Sim/U13InstallNormalizationReference.gd").new(owner._policy_id, owner._rules, owner._validators, owner._resolvers, owner._projector, owner._hook_handler, owner._context_hook, owner._content_owner, owner._world_validator, owner._order_handler, owner._order_screen, owner._order_validator)
	candidate._cache_world_validation = owner._cache_world_validation
	return candidate if candidate.restore(owner.snapshot()).action != "invalid" else null
