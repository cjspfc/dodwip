extends Control

const CARD_SCENE := preload("res://scenes/Card.tscn")

@onready var card_container: HFlowContainer = $Margin/VBox/Scroll/CardContainer


func _ready() -> void:
	for data in CardLibrary.get_test_cards():
		var card := CARD_SCENE.instantiate() as Card
		card.setup(data)
		card_container.add_child(card)
