class_name GameState
extends RefCounted


const CardData = preload("res://Scripts/Sim/Card.gd")
const PlayerStateData = preload("res://Scripts/Sim/PlayerState.gd")


var round: int = 0
var first_player: int = -1

var breach: String = ""
var breach_owner: int = -1
var reflex_winner: int = -1

var neutral_tears: int = 0
var veil_total: int = 0

var winner: int = -1
var win_by: String = ""

var deck: Array = []
var discard: Array = []
var market: Array = []

var players: Array = []


func _init(
	player_zero_lord_pool: Array[String] = [],
	player_one_lord_pool: Array[String] = []
) -> void:
	players = [
		PlayerStateData.new(0, player_zero_lord_pool),
		PlayerStateData.new(1, player_one_lord_pool),
	]


func get_player(player_id: int):
	if player_id < 0 or player_id >= players.size():
		return null

	return players[player_id]


func get_opponent(player_id: int):
	if players.size() != 2:
		return null

	if player_id == 0:
		return players[1]

	if player_id == 1:
		return players[0]

	return null


func calculate_veil_total() -> int:
	var total: int = neutral_tears

	for player in players:
		total += int(player.tears)

	return total


func refresh_derived_values() -> void:
	veil_total = calculate_veil_total()


func duplicate_state():
	var copy = GameState.new()

	copy.round = round
	copy.first_player = first_player

	copy.breach = breach
	copy.breach_owner = breach_owner
	copy.reflex_winner = reflex_winner

	copy.neutral_tears = neutral_tears
	copy.veil_total = veil_total

	copy.winner = winner
	copy.win_by = win_by

	copy.deck = _duplicate_cards(deck)
	copy.discard = _duplicate_cards(discard)
	copy.market = _duplicate_cards(market)

	copy.players.clear()

	for player in players:
		copy.players.append(player.duplicate_state())

	return copy


static func _duplicate_cards(cards: Array) -> Array:
	var result: Array = []

	for card in cards:
		if card != null and card.has_method("duplicate_card"):
			result.append(card.duplicate_card())
		else:
			result.append(card)

	return result
