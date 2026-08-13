extends Area2D

## Base for world objects the player can interact with (furniture, machines, etc.).

const GROUP_NAME := "interactable"
## Physics layer bit used only for interact Area2D overlap (layer 2).
const INTERACT_LAYER := 2

@export var enabled: bool = true
@export var prompt: String = "Interact"


func _ready() -> void:
	add_to_group(GROUP_NAME)
	monitoring = false
	monitorable = true
	collision_layer = INTERACT_LAYER
	collision_mask = 0


func can_interact(_actor: Node) -> bool:
	return enabled


func get_interact_prompt() -> String:
	return prompt


func interact(_actor: Node) -> void:
	pass
