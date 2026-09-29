extends SceneTree
const Model=preload("res://Prototype/U13/Encounters/U13EncounterModel.gd")
const Policy=preload("res://Scripts/Sim/U13CrossingTacticalPolicy.gd")
var checks: int=0
var failed: int=0
func check(ok: bool,message: String)->void:
	checks+=1
	if not ok:failed+=1
	print(("PASS " if ok else "FAIL ")+message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var decisions: Array=[]
	for incoming in ["Vulture","Butcher"]:
		var m=Model.new("visible-test","lamp")
		m.waves=[[],[{"name":incoming,"bodies":8}]]
		decisions.append(Policy.choose(m))
	check(decisions[0].names!=decisions[1].names,"changing only next visible wave changes deployments")
	check("Penitent" in decisions[0].names and "Vulture" in decisions[1].names,"archers draw shields; butchers draw archers")
	var a=Model.new("no-peeking","gate")
	var b=Model.new("no-peeking","gate")
	for i in range(2,b.waves.size()):b.waves[i]=[]
	check(Policy.choose(a)==Policy.choose(b),"unseen waves cannot change the policy")
	var hold=Model.new("hold","gate")
	hold.waves=[]
	for i in range(6):hold.arena.spawn("Penitent",0)
	var before: int=hold.ordinary_remaining()
	var response: Dictionary=Policy.choose(hold)
	check(hold.ordinary_remaining()==before-2,"counter policy builds two initial engineers and preserves other reserves with ample screen")
	var save=Model.new("save","lamp")
	save.power=6
	for i in range(2):save.arena.spawn("Penitent",0)
	save.waves=[[{"name":"Kurchin","bodies":5}],[]]
	response=Policy.choose(save)
	check(response.saving_for=="Sinodek" and save.power==6,"sufficient screen permits saving for armored-threat banishment")
	for mode in ["gate","lamp"]:
		for style in ["counter","engineer"]:
			for seed_id in [2,6,8]:
				var m=Model.new("crossing-%d"%seed_id,mode,2,1)
				var initial: Array=m.waves.duplicate(true)
				Policy.choose(m,style)
				check(m.deployments<=4 and m.power>=0 and m.capacity_used()<=7 and m.ordinary.values().all(func(x):return x>=0),"policy respects all resources")
				check(m.waves==initial,"policy leaves enemy orders intact")
	print("Tactical policy checks complete: %d passed, %d failed."%[checks-failed,failed])
	quit(1 if failed else 0)
