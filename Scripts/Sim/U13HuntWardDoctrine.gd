extends RefCounted

# Bounded public estimates, not authoritative forecasts. Concealed Guard faces
# always use DoctrineView's fixed prior; enemy cards/orders are never inspected.
static func threat_penalty(value: int) -> int:
	return 3 if value >= 4 else (2 if value >= 3 else (1 if value >= 2 else 0))

static func circle(c, pid: int) -> Dictionary:
	var choices: Array = c.castles(pid).filter(func(e): return e.attributes.castle_type == "SummoningCircle" and c.Structures.operational(e))
	choices.sort_custom(func(a, b): return a.attributes.castle_slot < b.attributes.castle_slot)
	return {} if choices.is_empty() else choices[0]

static func hunt(c, order: Dictionary, strength: int) -> float:
	var target: Dictionary = c.rows[order.target_id]
	var orias: bool = c.w.lord_ids[c.pid] == "Orias" and c.select("lord", c.pid)[0].attributes.alive
	# Pursuit is attack strength: it must face Guards, not bypass their screen.
	var remaining: int = strength + int(c.w.relentless_pursuit[c.pid].strength_bonus)
	var guards: Array = c.guards(1 - c.pid, "Lord")
	guards.sort_custom(func(a, b): return a.attributes.slot < b.attributes.slot if c.guard_strength(a) == c.guard_strength(b) else c.guard_strength(a) > c.guard_strength(b))
	var removed: int = 0
	var guard_value: int = 0
	for guard in guards:
		var value: int = c.guard_strength(guard)
		if remaining <= value:
			remaining = 0
			break
		remaining -= value
		removed += 1
		guard_value += value
	var score: float = guard_value * 0.8
	var sigil: String = c.w.sigils[1 - c.pid].Lord
	var screen: int = 2 if sigil == "fresh" else (1 if sigil == "flipped" else 0)
	remaining = maxi(0, remaining - screen)
	var keep_damage: int = 0
	for keep in c.castles(1 - c.pid):
		if keep.attributes.castle_type != "Keep": continue
		remaining = maxi(0, remaining - (3 if c.Structures.operational(keep) else 0))
		keep_damage = mini(remaining, int(keep.attributes.integrity))
		remaining -= keep_damage
		# Keep damage is permanent progress even when this Hunt cannot banish.
		score += keep_damage * 1.5
		if keep_damage > 0 and keep_damage == keep.attributes.integrity:
			score += c.castle_value(keep)
		break
	var target_threat: int = int(target.attributes.get("threat", 0))
	var projected_threat: int = target_threat
	var defense: int = int(c.w.lord_stats[1 - c.pid].defense)
	if orias and removed > 0 and target.attributes.lord_id != "Humbaba":
		var defense_drop: bool = target.attributes.lord_id != "Kroni" and threat_penalty(target_threat + 1) > threat_penalty(target_threat)
		if not defense_drop or circle(c, 1 - c.pid).is_empty():
			projected_threat += 1
			if target.attributes.lord_id != "Kroni":
				defense -= threat_penalty(projected_threat) - threat_penalty(target_threat)
		# Accelerate and a cleared Guard slot prepare the next Hunt. Prefer
		# productive pursuit, never award an unconditional "choose Hunt" quota.
		score += 4.0 + (2.0 if target_threat in [1, 2] else 0.0)
	var banish: bool = remaining > defense
	if banish:
		var souls: int = 4 if orias and projected_threat >= 3 else 2
		score += 28.0 + (12.0 if souls == 4 else 0.0)
		if c.w.souls[c.pid] + souls >= 12:
			score += 120.0
	elif orias and (removed > 0 or keep_damage > 0):
		# Hunting setup is Orias's strategic identity; compare it against the
		# real Castle damage/kill value, not against an action-frequency target.
		score += 3.0
	return score

static func ward(c, order: Dictionary, strength: int) -> float:
	var lane: String = order.lane
	var score: float = 0.0
	# A small, explicitly uncertain prior from public hand COUNT. This is not
	# enemy commitment strength. Waiting support is known; travelling units
	# cannot join this combat and contribute nothing to this estimate.
	var hand_pressure: float = mini(6, int(c.w.opponent_hand_count)) * 0.6
	for defended in ["Lord", "Castle"]:
		var pressure: float = c.waiters(1 - c.pid, defended)
		var screen: int = strength if lane == defended else strength >> 1
		# Ward protects Guards too: do not subtract our Guard screen first.
		var blocked: float = minf(screen, pressure)
		var protection: float = blocked * 1.5 + minf(maxi(0, screen - int(blocked)), hand_pressure) * 0.45
		# The opponent chooses one attack lane. Never add both alternative
		# attacks together as though both waiter armies can strike this round.
		score = maxf(score, protection)
	var sigil_allowed: bool = lane == "Lord" or not c.castles(c.pid).is_empty()
	if sigil_allowed:
		var before: String = c.w.sigils[c.pid][lane]
		var gain: int = 0 if before == "fresh" else (1 if before == "flipped" else 2)
		score += gain * 1.0
	if lane == "Lord":
		var own: Dictionary = c.select("lord", c.pid)[0]
		var threat: int = int(own.attributes.get("threat", 0))
		if own.attributes.lord_id != "Humbaba" and threat > 0:
			score += 1.0
			if own.attributes.alive and own.attributes.lord_id != "Kroni":
				score += (threat_penalty(threat) - threat_penalty(threat - 1)) * 4.0
	return score

static func snare_cost(c) -> float:
	var own: Dictionary = c.select("lord", c.pid)[0]
	var threat: int = int(own.attributes.get("threat", 0))
	# Above the last DEF breakpoint, more Threat is still costly: it adds
	# extra recovery Wards before DEF can improve. Do not keep Snaring at DEF 3.
	if threat >= 4: return 8.5 + mini(4, threat - 4)
	var defense_drop: bool = threat_penalty(threat + 1) > threat_penalty(threat)
	if not defense_drop: return 0.75
	var conduit: Dictionary = circle(c, c.pid)
	if conduit.is_empty(): return 8.5 if threat >= 3 else 4.5
	# Three integrity plus next-round Repair lock, even above the operational
	# floor. Crossing that floor also loses the Circle's function.
	return 4.5 + (c.castle_value(conduit) if conduit.attributes.integrity < 10 else 0.0)
