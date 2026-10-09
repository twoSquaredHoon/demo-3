extends CharacterBody2D

## Root script of player/player.tscn (the CharacterBody2D itself). Only
## handles WASD movement — everything else the player does (aiming,
## tool use, interacting) lives on sibling nodes under this same scene:
## TileTargeter (farming/tile_targeter.gd), ToolUse (player/tool_use.gd),
## and Interactor (player/interactor.gd). Those siblings reach back up to
## this node via relative paths like `$"../TileTargeter"` and
## `get_parent()`, so this script itself stays deliberately simple.
##
## Movement is deliberately naive right now: 4-directional input, no
## acceleration/sprint/stamina (run animation is built in _build_sprite), and no world/map
## collision besides whatever explicit solid bodies exist (currently just
## the bed) — see GAME_SYSTEMS_SUMMARY.md section 8 for the full list of
## intentionally-missing player features.
##
## Also note: the OTHER player.tscn at the project root (not under
## player/) is an empty, unused legacy stub — this script is only ever
## attached to player/player.tscn, the one actually instanced in
## MainFarmSpring.tscn.

@export var speed: float = 80.0

## Run animations: one horizontal strip per direction (Aseprite
## "Export Sprite Sheet", 7 frames of 32x32). The side strip faces LEFT;
## moving right flips it. Standing still shows frame 0 of the last direction.
const ANIM_SHEETS := {
	"run_front": "res://assets/characters/player/run_front.png",
	"run_back": "res://assets/characters/player/run_back.png",
	"run_side": "res://assets/characters/player/run_side.png",
}
const FRAME_SIZE := Vector2i(32, 32)
const FRAME_COUNT := 7
const ANIM_FPS := 8.0
## The side frames are drawn left of center; nudge them back over the body.
const SIDE_OFFSET_X := 4.0

var _sprite: AnimatedSprite2D
var _facing: String = "run_front"


func _ready() -> void:
	_build_sprite()


func _physics_process(_delta: float) -> void:
	# Inventory, dialogue, and confirm all hold a GameTime pause source.
	if GameTime.paused:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	_update_animation(direction)


func _build_sprite() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name in ANIM_SHEETS:
		var sheet := load(ANIM_SHEETS[anim_name]) as Texture2D
		if sheet == null:
			push_warning("Missing player sheet: %s" % ANIM_SHEETS[anim_name])
			return
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, ANIM_FPS)
		frames.set_animation_loop(anim_name, true)
		for i in FRAME_COUNT:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(anim_name, atlas)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.animation = _facing
	_sprite.frame = 0
	# The art replaces the placeholder rectangle.
	if has_node("Body"):
		$Body.visible = false


func _update_animation(direction: Vector2) -> void:
	if _sprite == null:
		return
	if direction == Vector2.ZERO:
		_sprite.stop()
		_sprite.frame = 0
		return
	if absf(direction.x) > absf(direction.y):
		_facing = "run_side"
		_sprite.flip_h = direction.x > 0.0
		_sprite.offset.x = -SIDE_OFFSET_X if _sprite.flip_h else SIDE_OFFSET_X
	else:
		_facing = "run_back" if direction.y < 0.0 else "run_front"
		_sprite.flip_h = false
		_sprite.offset.x = 0.0
	if _sprite.animation != _facing or not _sprite.is_playing():
		_sprite.play(_facing)
