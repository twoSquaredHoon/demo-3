extends Node

@export var display_name: String = "Unknown"


func _ready() -> void:
	GameState.set_location(display_name)
