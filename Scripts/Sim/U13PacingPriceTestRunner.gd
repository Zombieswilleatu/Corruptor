extends "res://Scripts/Sim/U13VictoryTestRunner.gd"

func run() -> void:
 var w: Dictionary = prepared()
 Victory.SplitWard.configure(w)
 Victory.configure(w)
 w.players[0].resources.souls = 13
 w.players[1].resources.souls = 14
 w.players[0].resources.personal_tears = 0
 w.players[1].resources.personal_tears = 0
 check(Victory.evaluate(w, 19).winner == -1, "new match stays open before round 20")
 check(Victory.evaluate(w, 20) == {"winner": 1, "win_by": "RoundLimit"}, "new match ends at round 20 by Souls")
 w.players[0].resources.souls = 14
 check(Victory.evaluate(w, 20).winner == 0, "deadline preserves existing Soul tie rule")
 w.players[1].resources.souls = 15
 check(Victory.evaluate(w, 20).win_by == "Ritual", "Ritual precedes deadline")
 w.players[1].resources.souls = 14
 w.players[1].resources.personal_tears = 7
 w.data.neutral_tears = 5
 check(Victory.evaluate(w, 20).win_by == "Dominion", "Dominion precedes deadline")
 w.players[1].resources.personal_tears = 0
 w.players[0].resources.personal_tears = 1
 w.players[1].resources.personal_tears = 2
 check(Victory.evaluate(w, 20).winner == 1, "Tears break tied Souls")
 w.players[0].resources.personal_tears = 2
 for row in w.entities.entities:
  if row.kind == "castle":
   row.attributes.status = "ruined"
   row.attributes.integrity = 0
 var castle: Dictionary = w.entities.entities.filter(func(e): return e.kind == "castle" and e.owner == 1)[0]
 castle.attributes.status = "standing"
 castle.attributes.construction_state = "active"
 castle.attributes.integrity = 1
 check(Victory.evaluate(w, 20).winner == 1, "standing Castle breaks tied Souls and Tears")
 castle.attributes.construction_state = "building"
 check(Victory.evaluate(w, 20).winner == 0, "unfinished Castle does not win a tiebreak")
 patch(w, w.players[0].lord_entity_id, {"alive": false})
 check(Victory.evaluate(w, 20).winner == 1, "living Lord breaks remaining tie")
 patch(w, w.players[1].lord_entity_id, {"alive": false})
 check(Victory.evaluate(w, 20).winner == 0, "seat is final fallback only")
 check(Victory.SplitWard.soul_start_round(w) == 17, "new decisive reward begins round 17")
 w.data.victory.erase("round_limit")
 check(Victory.evaluate(w, 24).winner == -1 and Victory.evaluate(w, 25).win_by == "RoundLimit", "existing save retains round 25")
 var price_script = preload("res://Scripts/Sim/U13Kanifous.gd").new()
 var price_world: Dictionary = {"data": {"card_zones": {"hands": [[], []]}}, "entities": {"entities": []}, "players": [{"resources": {"souls": 0}}, {"resources": {"souls": 0}}]}
 for state in ["ruined", "profaned", "defunct"]:
  price_world.entities.entities = [{"id": "castle", "kind": "castle", "owner": 0, "attributes": {"status": state, "construction_state": "active", "integrity": 0}}]
  var result: Dictionary = price_script._price(price_world, {"id": "price", "owner": 0}, {"seed": "excluded-castle", "round": 4})
  check(result.get("deferred", false), "Price cannot collect Stone or Ruin from " + state + " Castle")
 print("Pacing and Price checks failures: ", failures)
 quit(1 if failures else 0)
