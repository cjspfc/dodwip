class_name Card
extends PanelContainer

signal clicked

const COMPACT_SIZE := Vector2(118, 100)

@onready var name_label: Label = $Margin/VBox/HeaderRow/NameLabel
@onready var tier_label: Label = $Margin/VBox/HeaderRow/TierLabel
@onready var art_background: ColorRect = $Margin/VBox/ArtBackground
@onready var art_image: TextureRect = $Margin/VBox/ArtBackground/ArtImage
@onready var type_label: Label = $Margin/VBox/TypeLabel
@onready var description_label: Label = $Margin/VBox/DescriptionLabel
@onready var stats_label: Label = $Margin/VBox/StatsLabel

var _data: CardData
var _compact: bool = false
var _posture_text: String = ""
var _stats_override: String = ""


## compact = true desenha a carta pequena (mão e campo da arena).
## posture_text e stats_override aparecem só no modo compacto
## (ex.: "ATAQUE" / "DEFESA" e "A 1200* D 400", já com boosting).
func setup(data: CardData, compact: bool = false, posture_text: String = "", stats_override: String = "") -> void:
	_data = data
	_compact = compact
	_posture_text = posture_text
	_stats_override = stats_override
	if is_node_ready():
		_refresh()


func set_selected(selected: bool) -> void:
	modulate = Color(1.0, 1.0, 0.55) if selected else Color.WHITE


func _ready() -> void:
	# Só a carta inteira recebe cliques; os filhos ignoram o mouse.
	_ignore_mouse_on_children(self)
	if _data != null:
		_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()


func _ignore_mouse_on_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_on_children(child)


func _refresh() -> void:
	name_label.text = _data.card_name
	tier_label.text = CardData.TIER_LABELS[_data.tier]
	tier_label.visible = _data.tier != CardData.Tier.NONE
	art_image.texture = _data.image
	art_background.color = _get_art_color()
	description_label.text = _data.get_effect_text()
	stats_label.visible = _data.card_type == CardData.CardType.CREATURE

	if _compact:
		stats_label.text = _stats_override if _stats_override != "" else "A %d D %d" % [_data.attack, _data.defense]
		type_label.text = _build_compact_type_text()
		_apply_compact_layout()
	else:
		stats_label.text = "ATK %d   DEF %d" % [_data.attack, _data.defense]
		type_label.text = _build_type_text()
	tooltip_text = _build_tooltip()


func _apply_compact_layout() -> void:
	custom_minimum_size = COMPACT_SIZE
	description_label.visible = false
	art_background.custom_minimum_size = Vector2(0, 10)
	type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	tier_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_font_size_override("font_size", 12)


## Texto que aparece ao passar o mouse sobre a carta (útil no modo compacto, que esconde a descrição).
func _build_tooltip() -> String:
	var lines: PackedStringArray = [_data.card_name, _build_type_text()]
	var effect := _data.get_effect_text()
	if effect != "":
		lines.append(effect)
	if _stats_override.contains("*"):
		lines.append("(* valor com boosting)")
	return "\n".join(lines)


func _build_type_text() -> String:
	var text: String = CardData.TYPE_LABELS[_data.card_type]
	if _data.card_type == CardData.CardType.CREATURE:
		text += " - " + CardData.ELEMENT_LABELS[_data.element]
	if _data.is_special:
		text = "ESPECIAL - " + text
	return text


func _build_compact_type_text() -> String:
	var text: String
	if _data.card_type == CardData.CardType.CREATURE:
		text = CardData.ELEMENT_LABELS[_data.element]
	else:
		text = CardData.TYPE_LABELS[_data.card_type]
	if _data.is_special:
		text = "ESP. " + text
	if _posture_text != "":
		text += " - " + _posture_text
	return text


func _get_art_color() -> Color:
	if _data.card_type == CardData.CardType.CREATURE:
		match _data.element:
			CardData.Element.WATER:
				return Color(0.2, 0.45, 0.85)
			CardData.Element.FIRE:
				return Color(0.85, 0.3, 0.15)
			CardData.Element.ROCK:
				return Color(0.55, 0.4, 0.25)
			CardData.Element.ELECTRIC:
				return Color(0.9, 0.8, 0.2)
			CardData.Element.VOID:
				return Color(0.4, 0.2, 0.55)
			CardData.Element.LIGHT:
				return Color(0.95, 0.92, 0.7)
		return Color(0.4, 0.4, 0.45)
	match _data.card_type:
		CardData.CardType.BOOSTING:
			return Color(0.25, 0.65, 0.35)
		CardData.CardType.MANIPULATION:
			return Color(0.2, 0.6, 0.6)
		CardData.CardType.SENTENCE:
			return Color(0.7, 0.2, 0.35)
	return Color(0.4, 0.4, 0.45)
