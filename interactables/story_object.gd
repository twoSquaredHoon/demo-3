extends "res://interactables/interactable.gd"

## World object that starts a Dialogue file (sign, landmark, …). `npc_id` must
## match dialogue/content/<id>.json the same way NPCs do.

@export var npc_id: String = ""


func can_interact(_actor: Node) -> bool:
	return enabled and Dialogue.can_start(npc_id)


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	Dialogue.start(npc_id)
