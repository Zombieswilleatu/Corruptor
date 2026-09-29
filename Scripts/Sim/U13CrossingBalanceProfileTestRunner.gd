extends SceneTree
const Model=preload("res://Prototype/U13/Encounters/U13EncounterModel.gd")
var checks: int=0
var failed: int=0
func check(ok: bool,message: String)->void:
	checks+=1
	if not ok:failed+=1
	print(("PASS " if ok else "FAIL ")+message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var old_path: String=OS.get_environment("CROSSING_SELECTED_MODEL")
	var old=load(old_path) if not old_path.is_empty() else null
	for mode in ["gate","lamp"]:
		for level in range(3):
			for seed_id in [2,6,8,18,22,791341]:
				var m=Model.new("crossing-%d"%seed_id,mode,2,level)
				var spent: int=0
				for wave in m.waves:
					for order in wave:spent+=int(Model.OPPOSITION_COST.get(order.name,2))
				check(spent==m.enemy_spent and spent<=m.enemy_budget,"finite orders match audited spending")
				if mode=="gate" and level==0:
					check(not m.waves[5].is_empty() and m.waves[6].is_empty() and m.waves.slice(20).all(func(w):return w.is_empty()),"Light Gate patrols are finite with gaps")
				else:
					for number in [6,9,12]:check(not m.waves[number-1].is_empty() and m.waves[number].is_empty(),"declared pushes have recovery gaps")
					check(m.waves.slice(12).all(func(w):return w.is_empty()),"push plans end without an infinite tail")
				check(m.reinforcement_round()==(15 if mode=="gate" else 10) and m.round_limit()==(24 if mode=="gate" else 16),"shipment and deadline unchanged")
				if mode=="lamp" and level==0:
					check(not m.waves[1].any(func(o):return o.name=="Muno") and m.waves[2].any(func(o):return o.name=="Muno"),"Light Lamp skirmisher waits until round 3")
				if old!=null:
					var prior=old.new("crossing-%d"%seed_id,mode,2,level)
					check(m.waves==prior.waves and m.enemy_budget==prior.enemy_budget and m.enemy_spent==prior.enemy_spent,"shipping model matches the frozen tested candidate")
					check(m.arena.world==prior.arena.world and m.ordinary==prior.ordinary,"shipping world and player resources match frozen candidate")
	print("Balance profile checks complete: %d passed, %d failed."%[checks-failed,failed])
	quit(1 if failed else 0)
