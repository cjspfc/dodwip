class_name DuelState
extends RefCounted
## As regras da partida (sem nenhuma interface). A tela apenas mostra este
## estado e chama os métodos abaixo quando o jogador clica.

signal state_changed
signal log_added(message: String)

## ATTACH: falta fazer a acoplagem obrigatória do turno.
## ACTION: acoplagem feita; já é possível atacar ou finalizar o turno.
## FINISHED: a partida terminou (veja winner_index).
enum Phase { ATTACH, ACTION, FINISHED }

## Na primeira rodada de cada especialista não é possível atacar.
const MIN_ROUND_TO_ATTACK := 2

var players: Array[PlayerState] = []
var current_index: int = 0
var phase: Phase = Phase.ATTACH
var winner_index: int = -1
## Já houve algum ataque neste turno? (depois do primeiro ataque, a janela de ativação de utilidades fecha)
var attacked_this_turn: bool = false


func current_player() -> PlayerState:
	return players[current_index]


func other_player() -> PlayerState:
	return players[(current_index + 1) % players.size()]


func start_match(player_deck: Array[CardData], opponent_deck: Array[CardData]) -> void:
	players.clear()
	var first := PlayerState.new("Jogador")
	var second := PlayerState.new("Adversário")
	first.setup_deck(player_deck)
	second.setup_deck(opponent_deck)
	first.draw_opening_hand()
	second.draw_opening_hand()
	players.append(first)
	players.append(second)
	current_index = 0
	winner_index = -1
	_log("Partida iniciada: cada especialista comprou 4 fragmentos (com ao menos 1 criatura Tier D).")
	_begin_turn(false)


## Acoplagem obrigatória: move uma carta da mão para um slot do campo.
## Retorna true se deu certo.
func attach_card(hand_index: int, wants_creature_slot: bool, slot_index: int, posture: CardInstance.Posture) -> bool:
	if phase == Phase.FINISHED:
		return false
	if phase != Phase.ATTACH:
		_log("A acoplagem obrigatória deste turno já foi feita.")
		return false

	var player := current_player()
	if hand_index < 0 or hand_index >= player.hand.size():
		return false

	var card: CardInstance = player.hand[hand_index]
	if card.is_creature() != wants_creature_slot:
		if card.is_creature():
			_log("Criaturas só podem ser acopladas nos slots de criatura.")
		else:
			_log("Fragmentos de utilidade só podem ser acoplados nos slots de utilidade.")
		return false

	var slots: Array = player.creature_slots if card.is_creature() else player.utility_slots
	if slot_index < 0 or slot_index >= slots.size():
		return false

	var replaced: CardInstance = slots[slot_index]
	if replaced != null and slots.has(null):
		_log("Esse slot está ocupado e ainda há slots vazios. Escolha um slot vazio.")
		return false

	player.hand.remove_at(hand_index)
	if replaced != null:
		player.abyss.append(replaced)
	if card.is_creature():
		card.posture = posture
		card.has_attacked = false
	slots[slot_index] = card
	phase = Phase.ACTION

	if card.is_creature():
		_log("%s acoplou '%s' no slot de criatura %d em postura de %s." % [
			player.display_name, card.data.card_name, slot_index + 1, card.posture_label()])
	else:
		_log("%s acoplou '%s' no slot de utilidade %d." % [
			player.display_name, card.data.card_name, slot_index + 1])
	if replaced != null:
		_log("O campo estava cheio: '%s' foi substituído e enviado ao abismo." % replaced.data.card_name)

	_after_action()
	return true


## Motivo pelo qual a criatura do slot não pode atacar agora ("" = pode atacar).
func get_attack_block_reason(slot_index: int) -> String:
	if phase == Phase.FINISHED:
		return "A partida já terminou."
	if phase == Phase.ATTACH:
		return "Faça a acoplagem obrigatória antes de atacar."
	var player := current_player()
	if player.turns_played < MIN_ROUND_TO_ATTACK:
		return "Na primeira rodada de cada especialista ainda não é possível atacar."
	if slot_index < 0 or slot_index >= player.creature_slots.size():
		return "Slot inválido."
	var creature: CardInstance = player.creature_slots[slot_index]
	if creature == null:
		return "Esse slot de criatura está vazio."
	if creature.posture == CardInstance.Posture.DEFENSE:
		return "Criaturas em postura de defesa não podem atacar."
	if creature.has_attacked:
		return "Essa criatura já atacou nesta rodada."
	return ""


## A criatura do slot "attacker_slot" ataca a criatura do slot "target_slot" do adversário.
func attack_creature(attacker_slot: int, target_slot: int) -> bool:
	var reason := get_attack_block_reason(attacker_slot)
	if reason != "":
		_log(reason)
		return false

	var attacker_owner := current_player()
	var defender_owner := other_player()
	if target_slot < 0 or target_slot >= defender_owner.creature_slots.size():
		return false
	var target: CardInstance = defender_owner.creature_slots[target_slot]
	if target == null:
		# Slot vazio: é um ataque direto (só vale se o adversário não tiver criaturas).
		return attack_directly(attacker_slot)

	var attacker: CardInstance = attacker_owner.creature_slots[attacker_slot]
	attacker.has_attacked = true
	attacked_this_turn = true

	var attack_value := attacker.current_attack()
	var target_is_attacking := target.posture == CardInstance.Posture.ATTACK
	var target_value := target.current_attack() if target_is_attacking else target.current_defense()
	var diff := attack_value - target_value

	_log("%s ataca com '%s' (ATK %d) a criatura '%s' do adversário (%s %d)." % [
		attacker_owner.display_name, attacker.data.card_name, attack_value,
		target.data.card_name, "ATK" if target_is_attacking else "DEF", target_value])

	if diff > 0:
		# O atacante vence: a criatura atacada vai para o abismo do dono dela.
		defender_owner.creature_slots[target_slot] = null
		defender_owner.abyss.append(target)
		if target_is_attacking:
			defender_owner.take_damage(diff)
			_log("'%s' venceu o embate (%d x %d). '%s' foi para o abismo e %s perdeu %d de HP." % [
				attacker.data.card_name, attack_value, target_value,
				target.data.card_name, defender_owner.display_name, diff])
		else:
			_log("'%s' superou a defesa (%d x %d). '%s' foi para o abismo, sem dano ao HP." % [
				attacker.data.card_name, attack_value, target_value, target.data.card_name])
	elif diff < 0:
		# O atacante perde: ele vai para o abismo e o dono dele perde a diferença de HP.
		var loss := -diff
		attacker_owner.creature_slots[attacker_slot] = null
		attacker_owner.abyss.append(attacker)
		attacker_owner.take_damage(loss)
		_log("O ataque falhou (%d x %d): '%s' foi para o abismo e %s perdeu %d de HP." % [
			attack_value, target_value, attacker.data.card_name, attacker_owner.display_name, loss])
	else:
		_log("Empate (%d x %d): ninguém perde HP e as criaturas continuam no campo." % [
			attack_value, target_value])

	_after_action()
	return true


## Ataque direto ao HP do adversário (só vale se ele não tiver nenhuma criatura em campo).
## Na tela, é feito clicando em um slot de criatura vazio do adversário.
func attack_directly(attacker_slot: int) -> bool:
	var reason := get_attack_block_reason(attacker_slot)
	if reason != "":
		_log(reason)
		return false

	var attacker_owner := current_player()
	var defender_owner := other_player()
	for slot in defender_owner.creature_slots:
		if slot != null:
			_log("O adversário ainda tem criaturas em campo: ataque uma delas.")
			return false

	var attacker: CardInstance = attacker_owner.creature_slots[attacker_slot]
	attacker.has_attacked = true
	attacked_this_turn = true
	var damage := attacker.current_attack()
	defender_owner.take_damage(damage)
	_log("%s atacou diretamente com '%s': %d de dano. HP de %s: %d." % [
		attacker_owner.display_name, attacker.data.card_name, damage,
		defender_owner.display_name, defender_owner.hp])

	_after_action()
	return true


## Motivo pelo qual o fragmento de utilidade do slot não pode ser ativado agora ("" = pode).
func get_activation_block_reason(utility_slot: int) -> String:
	if phase == Phase.FINISHED:
		return "A partida já terminou."
	if phase == Phase.ATTACH:
		return "Faça a acoplagem obrigatória antes de ativar fragmentos."
	if attacked_this_turn:
		return "Depois do primeiro ataque do turno não é mais possível ativar fragmentos de utilidade."
	var player := current_player()
	if utility_slot < 0 or utility_slot >= player.utility_slots.size():
		return "Slot inválido."
	var card: CardInstance = player.utility_slots[utility_slot]
	if card == null:
		return "Esse slot de utilidade está vazio."
	if not card.data.is_manual_effect():
		return "Esse fragmento não é ativado manualmente (ou ainda não tem efeito nesta etapa)."
	if not _has_compatible_creature(player, card.data):
		return "Você não tem nenhuma criatura compatível com esse fragmento em campo."
	return ""


## Ativa um fragmento de utilidade (boosting) do campo sobre uma criatura sua.
## O fragmento é consumido: vai para o abismo e libera o slot.
func activate_utility(utility_slot: int, target_slot: int) -> bool:
	var reason := get_activation_block_reason(utility_slot)
	if reason != "":
		_log(reason)
		return false

	var player := current_player()
	if target_slot < 0 or target_slot >= player.creature_slots.size():
		return false
	var target: CardInstance = player.creature_slots[target_slot]
	if target == null:
		_log("Escolha uma criatura sua como alvo.")
		return false

	var card: CardInstance = player.utility_slots[utility_slot]
	if not card.data.can_target(target.data):
		_log("'%s' não é um alvo compatível: %s" % [target.data.card_name, card.data.get_effect_text()])
		return false

	match card.data.effect_kind:
		CardData.EffectKind.BOOST_ATTACK:
			target.attack_bonus += card.data.effect_amount
		CardData.EffectKind.BOOST_DEFENSE:
			target.defense_bonus += card.data.effect_amount

	player.utility_slots[utility_slot] = null
	player.abyss.append(card)
	_log("%s ativou '%s' em '%s' (ATK %d / DEF %d agora). O fragmento foi consumido e enviado ao abismo." % [
		player.display_name, card.data.card_name, target.data.card_name,
		target.current_attack(), target.current_defense()])

	_after_action()
	return true


func end_turn() -> bool:
	if phase == Phase.FINISHED:
		return false
	if phase == Phase.ATTACH:
		_log("Você precisa acoplar um fragmento antes de finalizar o turno.")
		return false
	_log("%s finalizou o turno." % current_player().display_name)
	_pass_turn()
	return true


## Ferramenta de teste: manda o deck inteiro do jogador atual para o abismo,
## para permitir ver o reembaralhamento sem jogar dezenas de turnos.
func debug_drain_deck() -> void:
	var player := current_player()
	while not player.deck.is_empty():
		player.abyss.append(player.deck.pop_back())
	_log("[Debug] O deck de %s foi enviado ao abismo (abismo: %d)." % [
		player.display_name, player.abyss.size()])
	state_changed.emit()


## Ferramenta de teste: define o HP dos dois especialistas, para terminar a partida rápido.
func debug_set_hp(value: int) -> void:
	for player in players:
		player.hp = value
	_log("[Debug] O HP dos dois especialistas agora é %d." % value)
	state_changed.emit()


func _pass_turn() -> void:
	current_index = (current_index + 1) % players.size()
	_begin_turn(true)


func _begin_turn(draw_cards: bool) -> void:
	var player := current_player()
	player.turns_played += 1
	phase = Phase.ATTACH
	attacked_this_turn = false
	for slot in player.creature_slots:
		if slot != null:
			(slot as CardInstance).has_attacked = false
	_log("--- Rodada %d de %s ---" % [player.turns_played, player.display_name])
	if draw_cards:
		_draw_to_full(player)
	state_changed.emit()


func _draw_to_full(player: PlayerState) -> void:
	var drawn := 0
	while player.hand.size() < PlayerState.HAND_SIZE:
		var card := player.draw_one()
		if card == null:
			_log("%s não tem mais fragmentos para comprar." % player.display_name)
			break
		if player.reshuffled_last_draw:
			_log("O deck de %s acabou: o abismo foi embaralhado e virou o novo deck." % player.display_name)
		drawn += 1
	if drawn > 0:
		_log("%s comprou %d fragmento(s)." % [player.display_name, drawn])


## Chamado depois de cada ação (acoplar ou atacar): verifica vitória e,
## se o especialista não tem mais nada a fazer, passa a vez sozinho.
func _after_action() -> void:
	for i in players.size():
		if players[i].hp <= 0:
			phase = Phase.FINISHED
			winner_index = (i + 1) % players.size()
			_log("%s zerou os pontos de harmonia. Vitória de %s!" % [
				players[i].display_name, players[winner_index].display_name])
			state_changed.emit()
			return

	if phase == Phase.ACTION and not _has_available_attacker(current_player()) \
			and not _has_activable_utility(current_player()):
		_log("%s não tem mais ações disponíveis: o turno passou automaticamente." % current_player().display_name)
		_pass_turn()
		return

	state_changed.emit()


func _has_available_attacker(player: PlayerState) -> bool:
	if player.turns_played < MIN_ROUND_TO_ATTACK:
		return false
	for slot in player.creature_slots:
		if slot != null:
			var creature := slot as CardInstance
			if creature.posture == CardInstance.Posture.ATTACK and not creature.has_attacked:
				return true
	return false


func _has_compatible_creature(player: PlayerState, effect_card: CardData) -> bool:
	for slot in player.creature_slots:
		if slot != null and effect_card.can_target((slot as CardInstance).data):
			return true
	return false


## Existe algum fragmento de utilidade que o especialista ainda pode ativar neste turno?
func _has_activable_utility(player: PlayerState) -> bool:
	if attacked_this_turn:
		return false
	for slot in player.utility_slots:
		if slot != null:
			var card := slot as CardInstance
			if card.data.is_manual_effect() and _has_compatible_creature(player, card.data):
				return true
	return false


func _log(message: String) -> void:
	log_added.emit(message)
