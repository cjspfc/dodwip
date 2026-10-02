class_name CardData
extends Resource

enum CardType { CREATURE, BOOSTING, MANIPULATION, SENTENCE }
enum Element { NONE, WATER, FIRE, ROCK, ELECTRIC, VOID, LIGHT }
enum Tier { NONE, D, C, B, A, S }
## O que um fragmento de utilidade faz. Novos efeitos entram aqui (e no DuelState).
enum EffectKind { NONE, BOOST_ATTACK, BOOST_DEFENSE }

const TYPE_LABELS := {
	CardType.CREATURE: "Criatura",
	CardType.BOOSTING: "Boosting",
	CardType.MANIPULATION: "Manipulação",
	CardType.SENTENCE: "Sentença",
}

const ELEMENT_LABELS := {
	Element.NONE: "Neutro",
	Element.WATER: "Água",
	Element.FIRE: "Fogo",
	Element.ROCK: "Rocha",
	Element.ELECTRIC: "Elétrico",
	Element.VOID: "Vazio",
	Element.LIGHT: "Luz",
}

const TIER_LABELS := {
	Tier.NONE: "",
	Tier.D: "D",
	Tier.C: "C",
	Tier.B: "B",
	Tier.A: "A",
	Tier.S: "S",
}

@export var id: String = ""
@export var card_name: String = ""
@export var card_type: CardType = CardType.CREATURE
@export var is_special: bool = false
@export var image: Texture2D
@export var element: Element = Element.NONE
@export var tier: Tier = Tier.NONE
@export var attack: int = 0
@export var defense: int = 0
## Texto de efeito escrito à mão. Se ficar vazio, o texto é gerado a partir da ficha de efeito.
@export_multiline var effect_text: String = ""

## --- Ficha de efeito (fragmentos de utilidade) ---
@export var effect_kind: EffectKind = EffectKind.NONE
@export var effect_amount: int = 0
## Filtros de compatibilidade (lista vazia = qualquer). Guardam valores de Tier / Element.
@export var target_tiers: Array = []
@export var target_elements: Array = []


## Efeito que o próprio jogador ativa, escolhendo uma criatura sua como alvo (boosting).
func is_manual_effect() -> bool:
	return effect_kind == EffectKind.BOOST_ATTACK or effect_kind == EffectKind.BOOST_DEFENSE


## Esta criatura é um alvo compatível com a ficha de efeito deste fragmento?
func can_target(creature: CardData) -> bool:
	if creature.card_type != CardType.CREATURE:
		return false
	if not target_tiers.is_empty() and not target_tiers.has(creature.tier):
		return false
	if not target_elements.is_empty() and not target_elements.has(creature.element):
		return false
	return true


func get_effect_text() -> String:
	if effect_text != "":
		return effect_text
	match effect_kind:
		EffectKind.BOOST_ATTACK:
			return "+%d ATK permanente a %s." % [effect_amount, _describe_targets()]
		EffectKind.BOOST_DEFENSE:
			return "+%d DEF permanente a %s." % [effect_amount, _describe_targets()]
	return ""


func _describe_targets() -> String:
	var text := "uma criatura"
	if not target_tiers.is_empty():
		var tier_names: PackedStringArray = []
		for tier_value in target_tiers:
			tier_names.append(TIER_LABELS[tier_value])
		text += " de tier " + ", ".join(tier_names)
	if not target_elements.is_empty():
		var element_names: PackedStringArray = []
		for element_value in target_elements:
			element_names.append(ELEMENT_LABELS[element_value])
		text += " do elemento " + ", ".join(element_names)
	return text
