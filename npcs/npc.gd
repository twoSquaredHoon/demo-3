extends "res://interactables/interactable.gd"

## Generic talker (npcs/npc.tscn). `npc_id` must match dialogue/content/<id>.json.
## Forwards left-click interact to Dialogue; owns no conversation state.

@export var npc_id: String = ""

const NPC_GROUP := "npc"
## How far the player may stand from an NPC and still start a conversation
## by clicking their body. The Interactor overlap circle stays at 28px
## (player.tscn) for beds/crops/boxes; this extra range is click-on-NPC only.
const TALK_RANGE := 56.0

@onready var _body_shape: Polygon2D = $Visual/BodyShape
@onready var _name_label: Label = $Visual/NameLabel


func _ready() -> void:
	super._ready()
	add_to_group(NPC_GROUP)
	prompt = "Talk"
	_refresh_visual()


func can_interact(_actor: Node) -> bool:
	return enabled and Dialogue.can_start(npc_id)


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	Dialogue.start(npc_id)


func _refresh_visual() -> void:
	if Dialogue.has_npc(npc_id):
		_body_shape.color = Dialogue.npc_color(npc_id)
		_name_label.text = Dialogue.npc_display_name(npc_id)
	elif not npc_id.is_empty():
		_name_label.text = npc_id
		push_error("NPC '%s' has no dialogue/content/%s.json" % [npc_id, npc_id])
