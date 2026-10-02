class_name FieldSlot
extends PanelContainer
## Um slot do campo: mostra "vazio" ou a carta acoplada, e avisa quando é clicado.

signal pressed(slot_index: int)

const CARD_SCENE := preload("res://scenes/Card.tscn")

@onready var empty_label: Label = $EmptyLabel

var slot_index: int = 0
var _card_view: Card


func setup(index: int, caption: String) -> void:
	slot_index = index
	empty_label.text = caption


## selected = true destaca a carta (atacante escolhido).
## Criaturas que já atacaram na rodada aparecem escurecidas.
func set_card(instance: CardInstance, selected: bool = false) -> void:
	if _card_view != null:
		remove_child(_card_view)
		_card_view.queue_free()
		_card_view = null

	empty_label.visible = instance == null
	tooltip_text = ""
	if instance == null:
		return

	_card_view = CARD_SCENE.instantiate() as Card
	_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_view)
	var posture_text := instance.posture_label() if instance.is_creature() else ""
	_card_view.setup(instance.data, true, posture_text, instance.stats_text_compact())
	tooltip_text = _card_view.tooltip_text
	_card_view.set_selected(selected)
	if instance.has_attacked and not selected:
		_card_view.modulate = Color(0.6, 0.6, 0.6)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(slot_index)
