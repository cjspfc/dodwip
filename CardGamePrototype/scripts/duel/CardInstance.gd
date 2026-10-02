class_name CardInstance
extends RefCounted
## Uma carta "viva" dentro de uma partida: os dados fixos (CardData)
## mais o estado que muda durante o duelo.

enum Posture { ATTACK, DEFENSE }

var data: CardData
var posture: Posture = Posture.ATTACK
var has_attacked: bool = false  # já atacou nesta rodada?
var attack_bonus: int = 0       # boosting permanente (vale pelo resto da partida)
var defense_bonus: int = 0


func _init(card_data: CardData) -> void:
	data = card_data


func is_creature() -> bool:
	return data.card_type == CardData.CardType.CREATURE


func posture_label() -> String:
	return "ATAQUE" if posture == Posture.ATTACK else "DEFESA"


## Valores usados no combate. Por enquanto são os valores da carta; mais
## tarde é aqui que boostings e vantagem elemental serão somados.
func current_attack() -> int:
	return data.attack + attack_bonus


func current_defense() -> int:
	return data.defense + defense_bonus


## Texto dos valores para a carta compacta. O asterisco (*) indica valor com boosting.
func stats_text_compact() -> String:
	var attack_mark := "*" if attack_bonus != 0 else ""
	var defense_mark := "*" if defense_bonus != 0 else ""
	return "A %d%s D %d%s" % [current_attack(), attack_mark, current_defense(), defense_mark]
