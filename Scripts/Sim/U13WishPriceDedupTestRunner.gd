extends SceneTree
const Price = preload("res://Prototype/U13/U13WishPriceVisual.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
 if not ok: failures += 1
 print(("PASS " if ok else "FAIL ") + label)
func _init():
 call_deferred("run")
func run():
 var view = Price.new()
 root.add_child(view)
 var side = Control.new()
 root.add_child(side)
 var e: Dictionary = {"type": "KANIFOUS_PRICE_RESOLVED", "data": {"id": "debt-1", "round": 3, "player_id": 0, "outcome": "Cards", "targets": ["a"]}}
 view.present([e], [side, side])
 check(view.visible and view.current.id == "debt-1", "first collection is shown")
 view.present([e.duplicate(true)], [side, side])
 check(view.pending.is_empty(), "worker replay does not queue a duplicate")
 view._next()
 view.present([e], [side, side])
 check(not view.visible, "acknowledged price does not reappear")
 var second = e.duplicate(true); second.data.id = "debt-2"
 view.present([e, second], [side, side])
 check(view.visible and view.current.id == "debt-2", "another debt in same round is shown")
 view._next()
 var retry = e.duplicate(true); retry.type = "KANIFOUS_PRICE_DEFERRED"; retry.data.id = "deferred"; retry.data.outcome = "Deferred"; retry.data.due_round = 4
 view.present([retry, retry], [side, side])
 check(view.visible and view.pending.is_empty(), "deferred outcome is shown only once in its round")
 view._next(); retry.data.round = 4; retry.data.due_round = 5
 view.present([retry], [side, side])
 check(view.visible, "later retry is a new outcome")
 view.clear()
 check(not view.visible and view.current.is_empty() and view.pending.is_empty(), "reset removes open and queued prices")
 view.present([e], [side, side])
 check(view.visible, "new match may reuse a debt identity")
 view.queue_free(); side.queue_free()
 await process_frame
 print("Wish Price duplicate checks: 8; failures: ",failures)
 quit(0 if failures == 0 else 1)
