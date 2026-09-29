extends RefCounted
const Model = preload("res://Prototype/U13/Encounters/U13EncounterModel.gd")
# Public information only: current field, reserves and two visible waves.
# No seed, unseen schedule, simulated future rolls or restart selection.
static func read_threat(m) -> Dictionary:
	var t: Dictionary = {"Penitent":0.0,"Vulture":0.0,"Butcher":0.0,"Wright":0.0,"Lemek":0.0,"Kopita":0.0,"Fyra":0.0,"Sooge":0.0,"Kurchin":0.0,"Varn":0.0,"Tumler":0.0,"Muno":0.0,"Dotra":0.0,"Sinodek":0.0,"total":0.0,"close":0.0}
	for unit in m.arena.units():
		if unit.owner != 1: continue
		var name: String = unit.attributes.get("monster_id",unit.attributes.suit)
		var weight: float = 1.0 if unit.attributes.x_fp < 1500 else 0.7
		t[name] += weight
		t.total += weight
		if unit.attributes.x_fp < 850: t.close += 1.0
	for offset in [0,1]:
		for order in m.forecast(offset):
			var weight: float = (0.8 if offset == 0 else 0.4) * int(order.bodies)
			t[order.name] += weight
			t.total += weight
	return t
static func pick_retinue(m) -> String:
	var t: Dictionary = read_threat(m)
	if m.scenario == "gate": return "Wright"
	return "Penitent" if t.Vulture > t.Butcher else "Vulture"
static func placement(m, name: String, slot: int, t: Dictionary) -> Vector2:
	var y: float = float(m.enemy_line)
	var close: Array = m.arena.units().filter(func(u):return u.owner==1)
	if not close.is_empty():
		close.sort_custom(func(a,b): return a.attributes.x_fp < b.attributes.x_fp)
		y = float(close[0].attributes.y_fp)
	if m.scenario == "lamp": y = float(m.arena.world.data.encounter.lamp_y)
	var support: bool = name in ["Vulture","Kopita","Sooge","Sinodek"]
	var x: float = 270.0 if support and t.close>0 else 410.0
	if name == "Wright":
		x = 400.0
		y = [180.0,300.0,420.0][slot % 3]
	else: y += [-55.0,0.0,55.0][slot%3]
	return Vector2(x,clampf(y,70,530))
static func place(m, name: String, slot: int, t: Dictionary) -> bool:
	var point: Vector2 = placement(m,name,slot,t)
	for dx in [0,-65,-130,-210,-300]:
		for dy in [0,65,-65,130,-130]:
			if m.deploy(name,Vector2(clampf(point.x+dx,60,420),clampf(point.y+dy,60,540))).has("ok"): return true
	return false
static func choose(m, style: String = "counter") -> Dictionary:
	var t: Dictionary = read_threat(m)
	var chosen: Array = []
	var own: Array = m.arena.units().filter(func(u):return u.owner==0)
	var front: int = own.filter(func(u):return u.attributes.get("monster_id",u.attributes.suit) in ["Penitent","Butcher","Lemek","Kurchin","Tumler","Varn","Muno","Dotra"]).size()
	var wounds: int = own.filter(func(u):return u.attributes.hp < u.attributes.max_hp).size()
	var engineers: int = own.filter(func(u):return u.attributes.suit=="Wright").size()
	var ranged: int = own.filter(func(u):return u.attributes.suit=="Vulture").size()
	# Build a defensive foundation in Gate; Lamp needs bodies contesting the center.
	var engineering_goal: int = 3 if style=="engineer" else 2
	if m.scenario=="gate" and m.arena.round_number==1:
		for i in range(engineering_goal):
			if m.unavailable("Wright").is_empty() and place(m,"Wright",i,t): chosen.append("Wright");engineers+=1
	var scores: Dictionary = {"Lemek":7.0,"Fyra":4.0,"Varn":3.0,"Kopita":2.0,"Tumler":3.0,"Kurchin":2.0,"Muno":2.0,"Dotra":2.0,"Sooge":1.0,"Sinodek":1.0}
	scores.Lemek += 3.0 if front<2 else 0.0
	scores.Fyra += 1.0*t.Lemek + 1.5*t.Kurchin
	scores.Muno += 6.0*t.Lemek
	scores.Dotra += 3.0*t.Lemek
	scores.Varn += 2.0*t.Muno
	scores.Tumler += 2.0*t.Kopita + 2.5*t.Sooge + 0.6*t.Vulture
	scores.Kopita += mini(wounds,4)*1.5 + (2.0 if front>=2 else 0.0)
	scores.Kurchin += 2.0 if ranged>=2 and front<2 else 0.0
	scores.Sinodek += 2.5*t.Lemek + 2.0*t.Kurchin + 0.5*t.total
	scores.Sooge += 0.65*t.total if front>=2 else 0.0
	scores.Dotra += 0.5*t.total if front>=2 else 0.0
	if style=="engineer": scores.Lemek+=3.0; scores.Kopita+=1.0
	# Avoid buying a second support with no screen; prefer a saved expensive answer
	# when it becomes affordable next round and our existing front can hold.
	var desired: String = ""
	var best: float = -1.0
	for name in scores:
		if Model.WEIGHT[name]+m.capacity_used()>Model.CAPACITY: continue
		if Model.Monsters.limited(name) and Model.Monsters.living(own,0,name): continue
		if name in ["Kopita","Sooge","Sinodek"] and front<1: continue
		if m.power+m.income<int(Model.COST[name]): continue
		if float(scores[name])>best: best=scores[name];desired=name
	var saving: bool = not desired.is_empty() and m.power<int(Model.COST[desired]) and front>=2 and t.close==0
	if not saving:
		var ranked: Array = scores.keys()
		ranked.sort_custom(func(a,b):return float(scores[a])>float(scores[b]))
		for name in ranked:
			if m.unavailable(name).is_empty() and (name not in ["Kopita","Sooge","Sinodek"] or front>0) and place(m,name,chosen.size(),t):
				chosen.append(name)
				if name in ["Lemek","Varn","Kurchin","Tumler","Muno","Dotra"]: front+=1
				break
	var reserve_target: int = 4
	if m.arena.round_number==1 and m.scenario=="lamp": reserve_target=3
	elif t.close==0 and own.size()>=int(ceil(t.total))+2: reserve_target=chosen.size()
	elif t.close==0 and own.size()>=4: reserve_target=mini(4,chosen.size()+1)
	while chosen.size()<reserve_target and m.deployments<Model.DEPLOYMENTS:
		var troop: Dictionary = {"Penitent":3.0+1.7*t.Vulture+(4.0 if front<2 else 0.0),"Vulture":4.0+1.7*t.Butcher+0.6*t.Lemek,"Butcher":3.0+0.7*t.Penitent,"Wright":0.0}
		if ranged<1 and front>=1: troop.Vulture+=3.0
		if m.scenario=="gate" and engineers<engineering_goal: troop.Wright=7.0
		# Ensure an ordinary carrier exists even when saving combat reserves.
		var ranked: Array = troop.keys()
		ranked.sort_custom(func(a,b):return float(troop[a])>float(troop[b]))
		var deployed: bool = false
		for name in ranked:
			if m.unavailable(name).is_empty() and place(m,name,chosen.size(),t):
				chosen.append(name);deployed=true
				if name in ["Penitent","Butcher"]:front+=1
				if name=="Vulture":ranged+=1
				if name=="Wright":engineers+=1
				break
		if not deployed: break
	return {"names":chosen,"threat":t,"saving_for":desired if saving else "","held":m.ordinary_remaining(),"retinue":m.leader}
