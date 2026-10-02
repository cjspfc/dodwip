extends Control

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const CARD_SCENE := preload("res://scenes/Card.tscn")
## Mostra os botões de teste "[Debug]". Troque por false quando terminar de testar.
const SHOW_DEBUG_TOOLS := true
const DEBUG_HP := 1000
## Pausa (em segundos) entre as ações do oponente automático, para dar tempo de acompanhar.
const BOT_DELAY := 0.9

@onready var back_button: Button = %BackButton
@onready var bot_toggle: CheckButton = %BotToggle
@onready var opponent_area: PlayerField = %OpponentArea
@onready var player_area: PlayerField = %PlayerArea
@onready var hand_title: Label = %HandTitle
@onready var hand_row: HBoxContainer = %HandRow
@onready var attack_button: Button = %AttackButton
@onready var defense_button: Button = %DefenseButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var debug_row: HBoxContainer = %DebugRow
@onready var debug_button: Button = %DebugButton
@onready var debug_hp_button: Button = %DebugHpButton
@onready var instruction_label: Label = %InstructionLabel
@onready var event_log: RichTextLabel = %EventLog
@onready var result_overlay: Control = %ResultOverlay
@onready var result_label: Label = %ResultLabel
@onready var rematch_button: Button = %RematchButton
@onready var overlay_menu_button: Button = %OverlayMenuButton

var duel: DuelState
var selected_hand_index: int = -1      # carta da mão escolhida (fase de acoplagem)
var selected_attacker_index: int = -1  # slot da criatura atacante (fase de combate)
var selected_utility_index: int = -1   # slot da utilidade a ativar (fase de combate)
var _hand_cards: Array[Card] = []
var _bot := SimpleBot.new()
var _bot_running: bool = false
var _bot_timer: Timer


func _ready() -> void:
	var posture_group := ButtonGroup.new()
	attack_button.button_group = posture_group
	defense_button.button_group = posture_group
	attack_button.button_pressed = true

	back_button.pressed.connect(_on_back_button_pressed)
	overlay_menu_button.pressed.connect(_on_back_button_pressed)
	rematch_button.pressed.connect(_on_rematch_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	debug_button.pressed.connect(_on_debug_pressed)
	debug_hp_button.pressed.connect(_on_debug_hp_pressed)
	debug_row.visible = SHOW_DEBUG_TOOLS

	player_area.creature_slot_pressed.connect(_on_slot_pressed.bind(0, true))
	player_area.utility_slot_pressed.connect(_on_slot_pressed.bind(0, false))
	opponent_area.creature_slot_pressed.connect(_on_slot_pressed.bind(1, true))
	opponent_area.utility_slot_pressed.connect(_on_slot_pressed.bind(1, false))

	_bot_timer = Timer.new()
	_bot_timer.one_shot = true
	add_child(_bot_timer)
	bot_toggle.toggled.connect(_on_bot_toggled)

	add_log("Arena de duelo carregada.")
	duel = DuelState.new()
	duel.state_changed.connect(_refresh_ui)
	duel.log_added.connect(add_log)
	duel.start_match(TestDeck.build(), TestDeck.build())


func add_log(message: String) -> void:
	event_log.add_text(message + "\n")


func _refresh_ui() -> void:
	selected_hand_index = -1
	selected_attacker_index = -1
	selected_utility_index = -1
	attack_button.button_pressed = true  # a postura padrão é sempre Ataque
	_refresh_fields()
	_rebuild_hand()
	_update_controls()
	_maybe_start_bot()


func _refresh_fields() -> void:
	var player_turn := duel.current_index == 0
	var opponent_turn := duel.current_index == 1
	player_area.show_player(duel.players[0], player_turn,
		selected_attacker_index if player_turn else -1,
		selected_utility_index if player_turn else -1)
	opponent_area.show_player(duel.players[1], opponent_turn,
		selected_attacker_index if opponent_turn else -1,
		selected_utility_index if opponent_turn else -1)


func _rebuild_hand() -> void:
	for child in hand_row.get_children():
		hand_row.remove_child(child)
		child.queue_free()
	_hand_cards.clear()

	var hand := _hand_owner().hand
	for i in hand.size():
		var card := CARD_SCENE.instantiate() as Card
		hand_row.add_child(card)
		card.setup(hand[i].data, true, "", hand[i].stats_text_compact())
		card.clicked.connect(_on_hand_card_clicked.bind(i))
		_hand_cards.append(card)


func _update_controls() -> void:
	var finished := duel.phase == DuelState.Phase.FINISHED
	hand_title.text = "Mão de: %s" % _hand_owner().display_name
	end_turn_button.disabled = duel.phase != DuelState.Phase.ACTION or _is_bot_turn()
	result_overlay.visible = finished
	if finished:
		result_label.text = "Vitória de %s!" % duel.players[duel.winner_index].display_name
	_update_selection()


func _update_selection() -> void:
	for i in _hand_cards.size():
		_hand_cards[i].set_selected(i == selected_hand_index)

	var player := duel.current_player()
	if _is_bot_turn():
		instruction_label.text = "Turno de %s (oponente automático). Aguarde..." % player.display_name
		return
	match duel.phase:
		DuelState.Phase.ATTACH:
			if selected_hand_index >= 0:
				var card: CardInstance = player.hand[selected_hand_index]
				if card.is_creature():
					instruction_label.text = "'%s' selecionada. Escolha a postura e clique em um slot de CRIATURA do seu campo." % card.data.card_name
				else:
					instruction_label.text = "'%s' selecionada. Clique em um slot de UTILIDADE do seu campo." % card.data.card_name
			else:
				instruction_label.text = "Rodada %d de %s: escolha 1 fragmento da mão (acoplagem obrigatória)." % [
					player.turns_played, player.display_name]
		DuelState.Phase.ACTION:
			if selected_utility_index >= 0:
				var utility: CardInstance = player.utility_slots[selected_utility_index]
				instruction_label.text = "'%s' selecionado: %s Clique na criatura alvo do seu campo (ou clique no fragmento de novo para cancelar)." % [
					utility.data.card_name, utility.data.get_effect_text()]
			elif selected_attacker_index >= 0:
				var attacker: CardInstance = player.creature_slots[selected_attacker_index]
				instruction_label.text = "'%s' (ATK %d) selecionada. Clique em uma criatura do adversário (ou em um slot vazio dele, se ele não tiver nenhuma criatura, para atacar direto)." % [
					attacker.data.card_name, attacker.current_attack()]
			else:
				instruction_label.text = "Clique em uma criatura sua em ATAQUE para atacar (1 ataque por criatura por rodada) ou, antes do primeiro ataque, em um boosting seu para ativá-lo. Ou use Finalizar turno."
		DuelState.Phase.FINISHED:
			instruction_label.text = "Partida encerrada."


func _on_hand_card_clicked(index: int) -> void:
	if _is_bot_turn():
		add_log("Aguarde: é a vez do oponente automático.")
		return
	if duel.phase != DuelState.Phase.ATTACH:
		add_log("Você já acoplou um fragmento neste turno.")
		return
	selected_hand_index = index
	_update_selection()


func _on_slot_pressed(slot_index: int, player_index: int, is_creature_slot: bool) -> void:
	if _is_bot_turn():
		add_log("Aguarde: é a vez do oponente automático.")
		return
	match duel.phase:
		DuelState.Phase.ATTACH:
			_try_attach(slot_index, player_index, is_creature_slot)
		DuelState.Phase.ACTION:
			_try_attack_selection(slot_index, player_index, is_creature_slot)


func _try_attach(slot_index: int, player_index: int, is_creature_slot: bool) -> void:
	if player_index != duel.current_index:
		add_log("Esse é o campo do outro especialista. Use o campo de quem está no turno.")
		return
	if selected_hand_index < 0:
		add_log("Selecione primeiro um fragmento da mão.")
		return
	var posture: CardInstance.Posture = CardInstance.Posture.ATTACK
	if defense_button.button_pressed:
		posture = CardInstance.Posture.DEFENSE
	duel.attach_card(selected_hand_index, is_creature_slot, slot_index, posture)


func _try_attack_selection(slot_index: int, player_index: int, is_creature_slot: bool) -> void:
	if not is_creature_slot:
		_try_select_utility(slot_index, player_index)
		return

	if player_index == duel.current_index:
		if selected_utility_index >= 0:
			# Há uma utilidade escolhida: a criatura clicada é o alvo dela.
			duel.activate_utility(selected_utility_index, slot_index)
			return
		# Clique no próprio campo: escolher o atacante.
		var reason := duel.get_attack_block_reason(slot_index)
		if reason != "":
			add_log(reason)
			return
		selected_attacker_index = slot_index
		_refresh_fields()
		_update_selection()
	else:
		if selected_utility_index >= 0:
			add_log("Esse fragmento só pode ser usado em criaturas do seu próprio campo.")
			return
		# Clique no campo do adversário: escolher o alvo do ataque.
		if selected_attacker_index < 0:
			add_log("Selecione primeiro uma criatura sua em postura de ataque.")
			return
		duel.attack_creature(selected_attacker_index, slot_index)


## Clique em um slot de utilidade durante a fase de combate: escolhe (ou desmarca) o fragmento a ativar.
func _try_select_utility(slot_index: int, player_index: int) -> void:
	if player_index != duel.current_index:
		add_log("Esse é o campo do outro especialista.")
		return
	if selected_utility_index == slot_index:
		selected_utility_index = -1
	else:
		var reason := duel.get_activation_block_reason(slot_index)
		if reason != "":
			add_log(reason)
			return
		selected_utility_index = slot_index
		selected_attacker_index = -1
	_refresh_fields()
	_update_selection()


func _on_end_turn_pressed() -> void:
	if _is_bot_turn():
		return
	duel.end_turn()


func _on_debug_pressed() -> void:
	duel.debug_drain_deck()


func _on_debug_hp_pressed() -> void:
	duel.debug_set_hp(DEBUG_HP)


func _on_rematch_pressed() -> void:
	event_log.clear()
	add_log("Nova partida.")
	duel.start_match(TestDeck.build(), TestDeck.build())


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_bot_toggled(_pressed: bool) -> void:
	_refresh_ui()


## Com o oponente automático ligado, a mão mostrada é sempre a do Jogador
## (a mão do Adversário fica escondida). No modo de dois jogadores, é a de quem está no turno.
func _hand_owner() -> PlayerState:
	return duel.players[0] if bot_toggle.button_pressed else duel.current_player()


func _is_bot_turn() -> bool:
	return bot_toggle.button_pressed and duel.current_index == 1 and duel.phase != DuelState.Phase.FINISHED


func _maybe_start_bot() -> void:
	if not _bot_running and _is_bot_turn():
		_run_bot()


## Uma ação por vez, com pausa entre elas. Sai quando o turno deixa de ser do robô.
func _run_bot() -> void:
	_bot_running = true
	while _is_bot_turn():
		_bot_timer.start(BOT_DELAY)
		await _bot_timer.timeout
		if not _is_bot_turn():
			break
		if not _bot.take_action(duel):
			add_log("O oponente automático não conseguiu agir. Desmarque 'Oponente automático' para jogar os dois lados.")
			break
	_bot_running = false
