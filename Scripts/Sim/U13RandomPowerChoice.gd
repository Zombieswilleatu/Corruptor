extends RefCounted

const Data = preload("res://Scripts/Sim/U13EffectData.gd")
const CHUNK: int = 8

# Discover which power groups have a legal member. Only the selected group needs
# its complete target domain; Pass needs none. This preserves the original keyed
# group/target draws, sorted domains, normalization and deduplication exactly.
static func groups(owner, pid: int, raw: Array) -> Array:
	var by_power: Dictionary = {}
	for item in raw:
		var source: Dictionary = Data.declaration_copy(item)
		if source.is_empty(): continue
		if not by_power.has(source.power_id): by_power[source.power_id] = []
		by_power[source.power_id].append(source)
	var names: Array = by_power.keys()
	names.sort()
	var result: Array = []
	for power in names:
		var sources: Array = by_power[power]
		var row: Dictionary = {"power": power, "sources": sources, "tested": 0, "legal": []}
		while row.tested < sources.size() and row.legal.is_empty():
			var stop: int = mini(maxi(row.tested * 2, CHUNK), sources.size())
			row.legal.append_array(owner.legal_power_candidates(pid, sources.slice(row.tested, stop)))
			row.tested = stop
		if not row.legal.is_empty(): result.append(row)
	return result

static func candidates(owner, pid: int, row: Dictionary) -> Array:
	var legal: Array = row.legal.duplicate(true)
	if row.tested < row.sources.size():
		legal.append_array(owner.legal_power_candidates(pid, row.sources.slice(row.tested)))
	var unique: Dictionary = {}
	for source in legal:
		if source.cost.has("discard_ids"): source.cost.discard_ids.sort()
		unique[JSON.stringify(source, "", true)] = source
	var keys: Array = unique.keys()
	keys.sort()
	var result: Array = []
	for key in keys: result.append(unique[key])
	return result
