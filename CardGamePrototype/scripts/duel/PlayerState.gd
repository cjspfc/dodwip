class_name PlayerState
extends RefCounted
## Tudo o que pertence a um especialista durante a partida:
## HP, deck, mão, abismo sequencial e os slots do campo.

const START_HP := 10000
const HAND_SIZE := 4
const CREATURE_SLOTS := 4
const UTILITY_SLOTS := 3

var display_name: String
var hp: int = START_HP
var deck: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var abyss: Array[CardInstance] = []
var creature_slots: Array = []  # cada posição: CardInstance ou null (vazio)
var utility_slots: Array = []
var turns_played: int = 0
var reshuffled_last_draw: bool = false


func _init(name_text: String) -> void:
	display_name = name_text
	creature_slots.resize(CREATURE_SLOTS)
	utility_slots.resize(UTILITY_SLOTS)
	creature_slots.fill(null)
	utility_slots.fill(null)


func setup_deck(cards: Array[CardData]) -> void:
	deck.clear()
	hand.clear()
	abyss.clear()
	creature_slots.fill(null)
	utility_slots.fill(null)
	for card_data in cards:
		deck.append(CardInstance.new(card_data))
	deck.shuffle()


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)


## Mão inicial: pelo menos 1 criatura Tier D (não especial) + o restante aleatório.
func draw_opening_hand() -> void:
	for i in deck.size():
		var candidate: CardInstance = deck[i]
		if candidate.is_creature() and not candidate.data.is_special and candidate.data.tier == CardData.Tier.D:
			hand.append(deck.pop_at(i))
			break
	while hand.size() < HAND_SIZE:
		if draw_one() == null:
			break


## Compra 1 carta. Se o deck acabou, o abismo é embaralhado e vira o novo deck.
func draw_one() -> CardInstance:
	reshuffled_last_draw = false
	if deck.is_empty():
		if abyss.is_empty():
			return null
		deck.append_array(abyss)
		abyss.clear()
		deck.shuffle()
		reshuffled_last_draw = true
	var card: CardInstance = deck.pop_back()
	hand.append(card)
	return card
