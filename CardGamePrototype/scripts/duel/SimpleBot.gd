class_name SimpleBot
extends RefCounted
## Oponente automático simples. Cada chamada de take_action() faz UMA ação
## do especialista que está no turno, usando só os métodos públicos do DuelState
## (as mesmas ações que um jogador humano tem).
##
## Estratégia:
## - Acoplagem: joga a criatura mais forte da mão (25% das vezes em defesa).
##   Se o campo de criaturas está cheio e a nova não é melhor que a mais fraca,
##   prefere acoplar uma utilidade.
## - Combate: só ataca quando vence o embate (escolhendo o alvo com maior margem);
##   ataca direto quando o adversário não tem criaturas; senão finaliza o turno.

const DEFEND_CHANCE := 0.25
## Chance de acoplar um boosting útil (com alvo compatível em campo) em vez de uma criatura.
const BOOST_CHANCE := 0.6


## Retorna true se fez alguma ação; false se não conseguiu agir.
func take_action(duel: DuelState) -> bool:
	match duel.phase:
		DuelState.Phase.ATTACH:
			return _attach(duel)
		DuelState.Phase.ACTION:
			return _attack_or_end_turn(duel)
	return false


func _attach(duel: DuelState) -> bool:
	var me := duel.current_player()
	if me.hand.is_empty():
		return false

	var best_creature := -1
	var best_attack := -1
	var first_utility := -1
	for i in me.hand.size():
		var candidate: CardInstance = me.hand[i]
		if candidate.is_creature():
			if candidate.current_attack() > best_attack:
				best_attack = candidate.current_attack()
				best_creature = i
		elif first_utility == -1:
			first_utility = i

	var choice := best_creature
	if choice == -1:
		choice = first_utility
	elif first_utility != -1 and not me.creature_slots.has(null):
		# Campo de criaturas cheio: só troca se a nova for mais forte que a mais fraca.
		if best_attack <= _weakest_attack(me.creature_slots):
			choice = first_utility

	var boost_index := _find_useful_boost(me)
	if boost_index != -1 and me.utility_slots.has(null) and randf() < BOOST_CHANCE:
		choice = boost_index

	var chosen: CardInstance = me.hand[choice]
	var slots: Array = me.creature_slots if chosen.is_creature() else me.utility_slots
	var slot_index := slots.find(null)
	if slot_index == -1:
		slot_index = _weakest_slot(slots) if chosen.is_creature() else 0

	var posture := CardInstance.Posture.ATTACK
	if chosen.is_creature() and randf() < DEFEND_CHANCE:
		posture = CardInstance.Posture.DEFENSE
	return duel.attach_card(choice, chosen.is_creature(), slot_index, posture)


func _attack_or_end_turn(duel: DuelState) -> bool:
	if _try_boost(duel):
		return true

	var me := duel.current_player()
	var foe := duel.other_player()

	var foe_has_creatures := false
	for slot in foe.creature_slots:
		if slot != null:
			foe_has_creatures = true

	var best_attacker := -1
	var best_target := -1
	var best_margin := 0
	for i in me.creature_slots.size():
		if duel.get_attack_block_reason(i) != "":
			continue
		if not foe_has_creatures:
			return duel.attack_directly(i)
		var attacker := me.creature_slots[i] as CardInstance
		for j in foe.creature_slots.size():
			var target := foe.creature_slots[j] as CardInstance
			if target == null:
				continue
			var target_value := target.current_defense()
			if target.posture == CardInstance.Posture.ATTACK:
				target_value = target.current_attack()
			var margin := attacker.current_attack() - target_value
			if margin > best_margin:
				best_margin = margin
				best_attacker = i
				best_target = j

	if best_attacker >= 0:
		return duel.attack_creature(best_attacker, best_target)
	return duel.end_turn()


func _weakest_slot(slots: Array) -> int:
	var weakest := 0
	var weakest_attack := 1 << 30
	for i in slots.size():
		var creature := slots[i] as CardInstance
		if creature != null and creature.current_attack() < weakest_attack:
			weakest = i
			weakest_attack = creature.current_attack()
	return weakest


func _weakest_attack(slots: Array) -> int:
	return (slots[_weakest_slot(slots)] as CardInstance).current_attack()


## Procura na mão um boosting que já tenha alvo compatível no campo. Retorna o índice ou -1.
func _find_useful_boost(me: PlayerState) -> int:
	for i in me.hand.size():
		var candidate: CardInstance = me.hand[i]
		if candidate.is_creature() or not candidate.data.is_manual_effect():
			continue
		for slot in me.creature_slots:
			if slot != null and candidate.data.can_target((slot as CardInstance).data):
				return i
	return -1


## Ativa um boosting acoplado (se houver) na criatura compatível com o maior valor do atributo reforçado.
func _try_boost(duel: DuelState) -> bool:
	var me := duel.current_player()
	for utility_slot in me.utility_slots.size():
		if duel.get_activation_block_reason(utility_slot) != "":
			continue
		var card := me.utility_slots[utility_slot] as CardInstance
		var best_target := -1
		var best_value := -1
		for i in me.creature_slots.size():
			var creature := me.creature_slots[i] as CardInstance
			if creature == null or not card.data.can_target(creature.data):
				continue
			var value := creature.current_attack()
			if card.data.effect_kind == CardData.EffectKind.BOOST_DEFENSE:
				value = creature.current_defense()
			if value > best_value:
				best_value = value
				best_target = i
		if best_target >= 0:
			return duel.activate_utility(utility_slot, best_target)
	return false
