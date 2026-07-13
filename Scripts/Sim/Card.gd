class_name CorruptorCard
extends RefCounted


var suit: String = ""
var value: int = 0


func _init(p_suit: String = "", p_value: int = 0) -> void:
	suit = p_suit
	value = p_value


func card_id() -> String:
	return "%s:%d" % [suit, value]


func duplicate_card():
	return CorruptorCard.new(suit, value)


func to_dictionary() -> Dictionary:
	return {
		"suit": suit,
		"value": value,
	}


static func from_dictionary(data: Dictionary):
	return CorruptorCard.new(
		str(data.get("suit", "")),
		int(data.get("value", 0))
	)
