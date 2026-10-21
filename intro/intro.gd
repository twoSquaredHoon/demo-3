extends Node2D

## Opening scene: the character is asleep on the floor of the dark, messy
## room. Press W to stand up, then hold D to walk to the door.
## (Next step later: the knock at the door -> title card.)

enum Step { SLEEPING, STANDING, AT_DOOR }

const WALK_SPEED := 40.0
## Where the character stops (the door side of the room).
const DOOR_X := 112.0
## Standing position height (feet on the floor).
const STAND_Y := 58.0
## The side frame is drawn left of center; this keeps it over the body.
const SIDE_OFFSET_X := 4.0

@onready var _player: Sprite2D = $Player
@onready var _prompt: Label = $UI/Prompt

var _step := Step.SLEEPING
var _hidden_huds: Array = []


func _ready() -> void:
	# No game HUD during the intro (clock, money, hotbar).
	for hud_name in ["LocationHud", "InventoryHud"]:
		var hud := get_node_or_null("/root/" + hud_name)
		if hud is CanvasLayer and hud.visible:
			hud.visible = false
			_hidden_huds.append(hud)
	# Lying down: the side frame turned on its back, head toward the wall.
	_player.rotation_degrees = -90.0
	_prompt.text = "W"


func _exit_tree() -> void:
	for hud in _hidden_huds:
		if is_instance_valid(hud):
			hud.visible = true


func _process(delta: float) -> void:
	match _step:
		Step.SLEEPING:
			if Input.is_action_just_pressed("move_up"):
				_stand_up()
		Step.STANDING:
			if Input.is_action_pressed("move_right"):
				_player.position.x += WALK_SPEED * delta
				if _player.position.x >= DOOR_X:
					_player.position.x = DOOR_X
					_reach_door()


func _stand_up() -> void:
	_player.rotation_degrees = 0.0
	_player.position.y = STAND_Y
	# Face the door (the side frame faces left, so flip it).
	_player.flip_h = true
	_player.offset.x = -SIDE_OFFSET_X
	_step = Step.STANDING
	_prompt.text = "D"


func _reach_door() -> void:
	_step = Step.AT_DOOR
	_prompt.text = ""
	# Next: knock on the door -> open it -> title card.
