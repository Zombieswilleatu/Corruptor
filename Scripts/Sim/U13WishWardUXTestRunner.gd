extends "res://Scripts/Sim/U13PlayableBoardTestRunner.gd"

func run() -> void:
 board = Board.new()
 root.add_child(board)
 board._runtime_ok = true
 board.start_loadout(["Kanifous", "Gremory"], [Slots.TYPES, Slots.TYPES], false)
 await process_frame
 await human_choices()
 for lane in ["Lord", "Castle"]:
  board._reset_direct()
  board._refresh()
  var cards: Array = board._available_ids()
  var own: Dictionary = board._entity_target(board._visible_world.entities.filter(func(e): return e.owner == 0 and e.kind == "lord")[0].id) if lane == "Lord" else board._entity_target(Slots.castle_id(0, 1))
  var enemy: Dictionary = board._entity_target(Slots.castle_id(1, 1))
  for attack_first in [false, true]:
   board._reset_direct()
   board._refresh()
   var targets: Array = [enemy, own] if attack_first else [own, enemy]
   for index in range(4):
    board._drop(Vector2.ZERO, {"ui2_type": "commitment_hand_card", "source": "Hand", "card": cards[index]}, targets[int(index / 2.0)])
   var order: Dictionary = board._order()
   check(order.get("action") == "Siege" and order.get("ward", {}).get("card_ids", []).size() == 2 and order.card_ids.size() == 2, lane + " two Ward + two Siege stay separate, attack first=" + str(attack_first))
   check(board.session.choose([], order).action != "invalid", "combined drop order accepted")
   board._show_stacks()
   var stacks: Array = board._order_preview._stacks.filter(func(s): return s.label == "WARD")
   check(stacks.size() == 1 and stacks[0].anchor == (board.sides[1].lord_card if lane == "Lord" else board.sides[1].castle_row), "Ward preview anchors to defended cards")
   if not stacks.is_empty():
    check(board._drop_intent(stacks[0].target) == "Ward" and not board._guard_drop_target(stacks[0].target).has("slot"), "Ward stack forwards drops to Ward, not Guards")
    board._drop(Vector2.ZERO, {"ui2_type": "commitment_hand_card", "source": "Hand", "card": cards[4]}, stacks[0].target)
    check(board.ward_plan.card_ids.size() == 3 and board._draft_combat.card_ids.size() == 2, "adding to Ward stack preserves attack")
   board._select_direct_action("Ward")
   board._choose_target(own)
   check(board._draft_combat.card_ids.size() == 2, "click targeting Ward preserves attack")
 board._reset_direct()
 board.powers_step = true
 board.flow_step = 4
 board._refresh()
 for index in [0, 0, 3, 2]:
  board.wish_choice.select(index)
  board.wish_choice.item_selected.emit(index)
  if index == 0: check(board._intent == "WishPower", "selecting/reselecting Power immediately targets a lane")
  if index == 3:
   check(board.wish_placement.visible, "selecting Death immediately opens placement")
   board.wish_placement.close()
  if index == 2:
   check(board.resurrection_placement.visible, "selecting Resurrection immediately opens placement")
   board.resurrection_placement.close()
 var castle: Dictionary = board._visible_world.entities.filter(func(e): return e.id == Slots.castle_id(0, 1))[0]
 var integrity: int = castle.attributes.integrity
 castle.attributes.integrity = 1
 board.wish_choice.select(1)
 board.wish_choice.item_selected.emit(1)
 check(board._intent == "WishLongevity", "selecting Longevity immediately targets a damaged Castle")
 castle.attributes.integrity = integrity
 board.wish_choice.select(4)
 board.wish_choice.item_selected.emit(4)
 check(board.queued.size() == 1 and board.queued[0].power_id == "WishWealth", "selecting Wealth queues directly")
 board.wish_choice.item_selected.emit(4)
 check(board.queued.size() == 1 and not board.wish_button.visible, "Wish cannot double queue and extra button is hidden")
 finish()
