extends "res://interactables/interactable.gd"

## Sleeps the player through to the next morning via GameTime.


func _ready() -> void:
	super._ready()
	prompt = "Sleep"


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	GameTime.sleep_to_next_morning()
