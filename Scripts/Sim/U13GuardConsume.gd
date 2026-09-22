extends RefCounted
const Rng = preload("res://Scripts/Sim/U13KeyedRng.gd")
const Actors = preload("res://Scripts/Sim/U13KroniActors.gd")
const MODE: String = "guard_bounce"
const VELOCITIES: Array = [[31,7],[29,13],[23,19],[19,23],[13,29],[7,31]]
const LIMIT: int = 2048

static func guards(world: Dictionary) -> Array:
	var rows: Array = world.entities.entities.filter(func(r): return r.kind == "card" and r.attributes.get("role") == "guard")
	rows.sort_custom(func(a,b): return a.id < b.id)
	return rows

static func point(row: Dictionary) -> Array:
	var slot: int = row.attributes.slot
	if row.attributes.lane == "Lord": return [80,640+130*slot if row.owner == 0 else 100+130*slot]
	return [720+100*slot,590 if row.owner == 0 else 410]

static func route(rows: Array, vx: int, vy: int) -> Dictionary:
	var x: int = 450
	var y: int = 500
	var path: Array = [[x,y]]
	for tick in range(LIMIT):
		var ax: int = x
		var ay: int = y
		var nx: int = x+vx
		var ny: int = y+vy
		var bounce: bool = false
		if nx < 0 or nx > 1000:
			nx = -nx if nx < 0 else 2000-nx
			vx = -vx
			bounce = true
		if ny < 0 or ny > 1000:
			ny = -ny if ny < 0 else 2000-ny
			vy = -vy
			bounce = true
		var hits: Array = []
		for row in rows:
			var p: Array = point(row)
			if Actors.touches(ax,ay,nx,ny,p[0],p[1],45): hits.append(row)
		x = nx
		y = ny
		if not hits.is_empty():
			hits.sort_custom(func(a,b):
				var pa: Array = point(a)
				var pb: Array = point(b)
				var da: int = (pa[0]-ax)*(pa[0]-ax)+(pa[1]-ay)*(pa[1]-ay)
				var db: int = (pb[0]-ax)*(pb[0]-ax)+(pb[1]-ay)*(pb[1]-ay)
				return da < db if da != db else a.id < b.id)
			path.append([x,y])
			return {"victim_id":hits[0].id,"path":path,"ticks":tick+1}
		if bounce: path.append([x,y])
	path.append([x,y])
	return {"victim_id":"","path":path,"ticks":LIMIT}

static func choose(world: Dictionary, pid: int, seed_value: String, key: String) -> Dictionary:
	var enemy_first: bool = int(Rng.draw(seed_value,key,"CONSUME_ENEMY_DIRECTION",0,100).value) < 60
	var side: int = 1-pid if enemy_first else pid
	var velocity: Array = VELOCITIES[int(Rng.draw(seed_value,key,"CONSUME_ANGLE",0,VELOCITIES.size()).value)]
	var vx: int = velocity[0]
	var vy: int = velocity[1]
	if int(Rng.draw(seed_value,key,"CONSUME_HORIZONTAL",0,2).value) == 0: vx = -vx
	if side == 1: vy = -vy
	var rows: Array = guards(world)
	var result: Dictionary = route(rows,vx,vy) if not rows.is_empty() else {"victim_id":"","path":[[450,500]],"ticks":0}
	result.merge({"initial_enemy":enemy_first,"initial_velocity":[vx,vy],"mode":MODE})
	return result
