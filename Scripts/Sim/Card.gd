class_name CorruptorCard
extends RefCounted


var suit: String = ""
var value: int = 0
var guard_revealed: bool = false


func _init(p_suit: String = "", p_value: int = 0) -> void:
	suit = p_suit
	value = p_value


func card_id() -> String:
	return "%s:%d" % [suit, value]


func duplicate_card():
	var copy = CorruptorCard.new(suit, value)
	copy.guard_revealed = guard_revealed
	return copy


func to_dictionary() -> Dictionary:
	return {
		"suit": suit,
		"value": value,
		"guard_revealed": guard_revealed,
	}


static func from_dictionary(data: Dictionary):
	var card = CorruptorCard.new(
		str(data.get("suit", "")),
		int(data.get("value", 0))
	)
	card.guard_revealed = bool(data.get("guard_revealed", false))
	return card
