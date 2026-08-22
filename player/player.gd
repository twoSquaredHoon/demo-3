extends CharacterBody2D

## Root script of player/player.tscn (the CharacterBody2D itself). Only
## handles WASD movement — everything else the player does (aiming,
## tool use, interacting) lives on sibling nodes under this same scene:
## TileTargeter (farming/tile_targeter.gd), ToolUse (player/tool_use.gd),
## and Interactor (player/interactor.gd). Those siblings reach back up to
## this node via relative paths like `$"../TileTargeter"` and
## `get_parent()`, so this script itself stays deliberately simple.
##
## Movement is deliberately naive right now: 4-directional input, no facing
## state, no acceleration/sprint/stamina, no animation, and no world/map
## collision besides whatever explicit solid bodies exist (currently just
## the bed) — see GAME_SYSTEMS_SUMMARY.md section 8 for the full list of
## intentionally-missing player features.
##
## Also note: the OTHER player.tscn at the project root (not under
## player/) is an empty, unused legacy stub — this script is only ever
## attached to player/player.tscn, the one actually instanced in
## MainFarmSpring.tscn.

@export var speed: float = 120.0


func _physics_process(_delta: float) -> void:
	# While the inventory popup is open, freeze movement entirely rather
	# than just ignoring input — this guarantees the player can't drift
	# from residual velocity while browsing items (Inventory.is_menu_open
	# is the same flag ToolUse and Interactor check before acting).
	if Inventory.is_menu_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
