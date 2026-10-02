class_name TestDeck
extends RefCounted
## Gera um deck de teste de 35 fragmentos com a composição do documento:
## 25 criaturas (5 por tier) + 3 boosting + 3 manipulação + 3 sentença + 1 especial.
## Os nomes e números são provisórios, só para testar.
## Para criar um novo fragmento basta adicionar uma linha aqui (ou, no futuro, em um arquivo de dados).

const ELEMENTS := [
	CardData.Element.WATER, CardData.Element.FIRE, CardData.Element.ROCK,
	CardData.Element.ELECTRIC, CardData.Element.VOID, CardData.Element.LIGHT,
]
const TIERS := [
	CardData.Tier.D, CardData.Tier.C, CardData.Tier.B, CardData.Tier.A, CardData.Tier.S,
]
const BASE_ATTACK := [500, 800, 1100, 1600, 2300]
const BASE_DEFENSE := [400, 700, 1000, 1300, 1800]
const NO_EFFECT_TEXT := "Sem efeito nesta etapa."
const LOWER_TIERS := [CardData.Tier.B, CardData.Tier.C, CardData.Tier.D]


static func build() -> Array[CardData]:
	var cards: Array[CardData] = []

	# 25 criaturas: 5 por tier.
	for tier_index in TIERS.size():
		var tier: CardData.Tier = TIERS[tier_index]
		var tier_text: String = CardData.TIER_LABELS[tier]
		for n in range(1, 6):
			var element: CardData.Element = ELEMENTS[(tier_index + n) % ELEMENTS.size()]
			var element_text: String = CardData.ELEMENT_LABELS[element]
			var attack: int = BASE_ATTACK[tier_index] + (n - 1) * 50
			var defense: int = BASE_DEFENSE[tier_index] + (n - 1) * 50
			if element == CardData.Element.VOID:
				defense = 100
			cards.append(_make_card(
				"creature_%s_%d" % [tier_text.to_lower(), n],
				"%s %s%d" % [element_text, tier_text, n],
				CardData.CardType.CREATURE, element, tier, attack, defense, ""))

	# 3 boostings (efeito permanente; o texto é gerado a partir da ficha de efeito).
	cards.append(_make_boost("boosting_1", "Impulso de Ataque",
		CardData.EffectKind.BOOST_ATTACK, 500, LOWER_TIERS, []))
	cards.append(_make_boost("boosting_2", "Escudo Reforçado",
		CardData.EffectKind.BOOST_DEFENSE, 500, LOWER_TIERS, []))
	cards.append(_make_boost("boosting_3", "Chama Intensa",
		CardData.EffectKind.BOOST_ATTACK, 300, [], [CardData.Element.FIRE]))

	# 3 manipulações e 3 sentenças (ainda sem efeito: entram nas próximas etapas).
	for n in range(1, 4):
		cards.append(_make_card("manipulation_%d" % n, "Manipulação %d" % n,
			CardData.CardType.MANIPULATION, CardData.Element.NONE, CardData.Tier.NONE, 0, 0, NO_EFFECT_TEXT))
		cards.append(_make_card("sentence_%d" % n, "Sentença %d" % n,
			CardData.CardType.SENTENCE, CardData.Element.NONE, CardData.Tier.NONE, 0, 0, NO_EFFECT_TEXT))

	# 1 especial (criatura, sem tier).
	var special := _make_card("special_001", "Colosso Fragmentado",
		CardData.CardType.CREATURE, CardData.Element.ROCK, CardData.Tier.NONE, 3500, 3000, "")
	special.is_special = true
	cards.append(special)

	return cards


static func _make_card(
		card_id: String, card_name: String, card_type: CardData.CardType,
		element: CardData.Element, tier: CardData.Tier,
		attack: int, defense: int, effect_text: String) -> CardData:
	var data := CardData.new()
	data.id = card_id
	data.card_name = card_name
	data.card_type = card_type
	data.element = element
	data.tier = tier
	data.attack = attack
	data.defense = defense
	data.effect_text = effect_text
	return data


static func _make_boost(
		card_id: String, card_name: String, kind: CardData.EffectKind, amount: int,
		tiers: Array, elements: Array) -> CardData:
	var data := _make_card(card_id, card_name, CardData.CardType.BOOSTING,
		CardData.Element.NONE, CardData.Tier.NONE, 0, 0, "")
	data.effect_kind = kind
	data.effect_amount = amount
	data.target_tiers = tiers.duplicate()
	data.target_elements = elements.duplicate()
	return data
