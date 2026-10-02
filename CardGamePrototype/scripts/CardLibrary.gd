class_name CardLibrary
extends RefCounted


static func get_test_cards() -> Array[CardData]:
	var entries: Array[Dictionary] = [
		{
			"id": "fire_d_001", "name": "Brasa Rastejante",
			"type": CardData.CardType.CREATURE, "element": CardData.Element.FIRE,
			"tier": CardData.Tier.D, "attack": 600, "defense": 400,
		},
		{
			"id": "water_c_001", "name": "Enguia da Maré",
			"type": CardData.CardType.CREATURE, "element": CardData.Element.WATER,
			"tier": CardData.Tier.C, "attack": 900, "defense": 700,
		},
		{
			"id": "rock_b_001", "name": "Golem de Cascalho",
			"type": CardData.CardType.CREATURE, "element": CardData.Element.ROCK,
			"tier": CardData.Tier.B, "attack": 1100, "defense": 1500,
		},
		{
			"id": "electric_a_001", "name": "Falcão Faísca",
			"type": CardData.CardType.CREATURE, "element": CardData.Element.ELECTRIC,
			"tier": CardData.Tier.A, "attack": 1800, "defense": 900,
		},
		{
			"id": "light_s_001", "name": "Sentinela do Amanhecer",
			"type": CardData.CardType.CREATURE, "element": CardData.Element.LIGHT,
			"tier": CardData.Tier.S, "attack": 2400, "defense": 2000,
		},
		{
			"id": "void_s_001", "name": "Devorador Silente",
			"type": CardData.CardType.CREATURE, "element": CardData.Element.VOID,
			"tier": CardData.Tier.S, "attack": 2800, "defense": 100,
		},
		{
			"id": "boost_001", "name": "Lâmina Ampliada",
			"type": CardData.CardType.BOOSTING,
			"effect_text": "Aumenta o ataque de uma criatura de Fogo.",
		},
		{
			"id": "manip_001", "name": "Maré Alterada",
			"type": CardData.CardType.MANIPULATION,
			"effect_text": "Altera o campo de batalha em favor das criaturas de Água.",
		},
		{
			"id": "sentence_001", "name": "Eco Punitivo",
			"type": CardData.CardType.SENTENCE,
			"effect_text": "Ativa quando uma criatura adversária ataca.",
		},
		{
			"id": "special_001", "name": "Colosso Fragmentado",
			"type": CardData.CardType.CREATURE, "element": CardData.Element.ROCK,
			"is_special": true, "attack": 3500, "defense": 3000,
		},
	]

	var cards: Array[CardData] = []
	for entry in entries:
		var data := CardData.new()
		data.id = entry["id"]
		data.card_name = entry["name"]
		data.card_type = entry["type"]
		data.is_special = entry.get("is_special", false)
		data.element = entry.get("element", CardData.Element.NONE)
		data.tier = entry.get("tier", CardData.Tier.NONE)
		data.attack = entry.get("attack", 0)
		data.defense = entry.get("defense", 0)
		data.effect_text = entry.get("effect_text", "")
		cards.append(data)
	return cards
