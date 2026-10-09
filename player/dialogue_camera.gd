extends Camera2D

## Child of Player (player/player.tscn → Camera2D). Visual-only: listens to
## Dialogue line/choice/end signals and pans this camera between the player
## and the NPC being talked to. Conversation state stays on the Dialogue
## autoload; this script only moves the view.
##
## The camera stays parented to the player. Looking at a speaker is done by
## setting `position` to (speaker_global - player_global); smoothing is
## switched on only during conversations so those moves pan, not snap. Zoom stays with
## ui/location_hud.gd.

const NPC_GROUP := "npc"
const PLAYER_SPEAKERS := ["You", "Player", "나"]
## Nudge the framed body up so the bottom dialogue panel covers less of it.
const FRAME_OFFSET := Vector2(0, -20)
const TALK_SMOOTHING := 5.0

var _idle_smoothing: float = 8.0
var _talking: bool = false


func _ready() -> void:
	_idle_smoothing = position_smoothing_speed
	# Walking: camera locked on the player (no smoothing), so the character
	# stays fixed at screen center and the world scrolls. Smoothing is only
	# turned on for the dialogue pans below.
	position_smoothing_enabled = false
	Dialogue.conversation_started.connect(_on_conversation_started)
	Dialogue.line_changed.connect(_on_line_changed)
	Dialogue.choices_changed.connect(_on_choices_changed)
	Dialogue.conversation_ended.connect(_on_conversation_ended)


func _on_conversation_started(_npc_id: String) -> void:
	_talking = true
	position_smoothing_enabled = true
	position_smoothing_speed = TALK_SMOOTHING


func _on_line_changed(speaker: String, _text: String) -> void:
	if not _talking:
		return
	if _is_player_speaker(speaker):
		_look_at_player()
	else:
		_look_at_npc()


func _on_choices_changed(choices: Array) -> void:
	if not _talking or choices.is_empty():
		return
	# Keep the view on the other speaker while the player picks a reply.
	_look_at_npc()


func _on_conversation_ended() -> void:
	_talking = false
	position_smoothing_speed = _idle_smoothing
	position = Vector2.ZERO


func _process(_delta: float) -> void:
	# After a conversation, let the pan back finish, then lock on again.
	if not _talking and position_smoothing_enabled:
		if get_screen_center_position().distance_to(get_target_position()) < 0.5:
			position_smoothing_enabled = false


func _look_at_player() -> void:
	position = FRAME_OFFSET


func _look_at_npc() -> void:
	var npc := _find_current_npc()
	if npc == null:
		_look_at_player()
		return
	var player := get_parent() as Node2D
	if player == null:
		return
	position = npc.global_position - player.global_position + FRAME_OFFSET


func _is_player_speaker(speaker: String) -> bool:
	return PLAYER_SPEAKERS.has(speaker)


func _find_current_npc() -> Node2D:
	var npc_id := Dialogue.current_npc_id
	if npc_id.is_empty():
		return null
	for node in get_tree().get_nodes_in_group(NPC_GROUP):
		if node is Node2D and str(node.get("npc_id")) == npc_id:
			return node
	return null
