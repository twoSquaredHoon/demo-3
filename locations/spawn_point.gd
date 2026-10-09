extends Marker2D

## Named landing spot for GameState.travel(). location_info applies
## pending_spawn_id to the player after the new scene is ready.

@export var spawn_id: String = ""


func _ready() -> void:
	add_to_group("spawn_point")
