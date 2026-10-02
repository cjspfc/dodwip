class_name PlayerField
extends PanelContainer
## A área de um especialista: informações (nome, HP, contagens) e os slots do campo.

signal creature_slot_pressed(slot_index: int)
signal utility_slot_pressed(slot_index: int)

const FIELD_SLOT_SCENE := preload("res://scenes/FieldSlot.tscn")

@onready var info_label: Label = $Margin/VBox/InfoLabel
@onready var creature_row: HBoxContainer = $Margin/VBox/SlotsRow/CreatureRow
@onready var utility_row: HBoxContainer = $Margin/VBox/SlotsRow/UtilityRow

var _creature_slots: Array[FieldSlot] = []
var _utility_slots: Array[FieldSlot] = []


func _ready() -> void:
	for i in PlayerState.CREATURE_SLOTS:
		var slot := FIELD_SLOT_SCENE.instantiate() as FieldSlot
		creature_row.add_child(slot)
		slot.setup(i, "Criatura %d" % (i + 1))
		slot.pressed.connect(_on_creature_slot_pressed)
		_creature_slots.append(slot)

	for i in PlayerState.UTILITY_SLOTS:
		var slot := FIELD_SLOT_SCENE.instantiate() as FieldSlot
		utility_row.add_child(slot)
		slot.setup(i, "Utilidade %d" % (i + 1))
		slot.pressed.connect(_on_utility_slot_pressed)
		_utility_slots.append(slot)


## selected_creature_index: slot da criatura atacante escolhida (-1 = nenhuma).
## selected_utility_index: slot da utilidade escolhida para ativar (-1 = nenhuma).
func show_player(state: PlayerState, is_active: bool, selected_creature_index: int = -1, selected_utility_index: int = -1) -> void:
	var marker := "   <<< TURNO ATUAL" if is_active else ""
	info_label.text = "%s  |  HP %d  |  Deck %d  |  Abismo %d  |  Mão %d  |  Rodadas %d%s" % [
		state.display_name, state.hp, state.deck.size(), state.abyss.size(),
		state.hand.size(), state.turns_played, marker]

	for i in _creature_slots.size():
		_creature_slots[i].set_card(state.creature_slots[i], i == selected_creature_index)
	for i in _utility_slots.size():
		_utility_slots[i].set_card(state.utility_slots[i], i == selected_utility_index)

	modulate = Color.WHITE if is_active else Color(0.72, 0.72, 0.72)


func _on_creature_slot_pressed(slot_index: int) -> void:
	creature_slot_pressed.emit(slot_index)


func _on_utility_slot_pressed(slot_index: int) -> void:
	utility_slot_pressed.emit(slot_index)
