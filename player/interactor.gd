extends Area2D

## Child of Player (player/player.tscn: Player → Interactor).
##
## Left-click (`interact`): use the nearest world object (bed sleep, harvest,
## talk, selling box, …) via interact().
## Right-click (`use_item`): if the nearest object implements
## interact_pickup() (currently the bed), pick it up; otherwise leave the
## event for ToolUse (tools / seeds / furniture place).
##
## This is a circular Area2D (radius 28, see player.tscn) on physics layer
## 0 / mask 2, so it only ever detects OTHER Area2Ds on layer 2 — which is
## exactly the layer every interactable base object sets itself to in
## `interactables/interactable.gd`'s _ready(). It maintains a running list
## of everything currently overlapping (_in_range) via area_entered/
## area_exited, so interact doesn't need to re-scan physics each time.
##
## Selection is proximity, not aim: interacting picks whichever eligible
## overlapping object is CLOSEST to the player's origin — it does not care
## where the mouse cursor is. Contrast with TileTargeter (farming/
## tile_targeter.gd), which IS cursor-aimed but only for farming tools.

const INTERACT_LAYER := 2
const INTERACTABLE_GROUP := "interactable"

var _in_range: Array[Area2D] = []


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = INTERACT_LAYER
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if GameTime.paused:
		return
	if event.is_action_pressed("interact"):
		var target := get_nearest()
		if target == null:
			return
		var actor := get_parent()
		if not target.can_interact(actor):
			return
		target.interact(actor)
		# Only consume the click if an object was actually used, so a stray
		# interact with nothing in range doesn't swallow input other
		# systems might otherwise want.
		get_viewport().set_input_as_handled()
		return
	# Right-click: pick up objects that opt in via interact_pickup()
	# (bed, empty hand only). Otherwise do not mark handled — ToolUse
	# places/tools.
	if event.is_action_pressed("use_item"):
		var target := get_nearest()
		if target == null or not target.has_method("interact_pickup"):
			return
		var actor := get_parent()
		if target.has_method("can_interact_pickup"):
			if not target.can_interact_pickup(actor):
				return
		elif target.has_method("can_interact") and not target.can_interact(actor):
			return
		target.interact_pickup(actor)
		get_viewport().set_input_as_handled()


## Picks the closest currently-overlapping interactable that reports
## can_interact(actor) == true (this is where an immature crop_plant.gd
## gets filtered out — see its can_interact() override). Uses squared
## distance purely to avoid an unnecessary sqrt; there's no other tie-break
## beyond whichever happens to compare smaller first.
func get_nearest() -> Area2D:
	var best: Area2D = null
	var best_dist := INF
	var origin := global_position
	var actor := get_parent()
	for item in _in_range:
		if not is_instance_valid(item) or not item.has_method("can_interact"):
			continue
		if not item.can_interact(actor):
			continue
		var dist := origin.distance_squared_to(item.global_position)
		if dist < best_dist:
			best_dist = dist
			best = item
	return best


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(INTERACTABLE_GROUP) and not _in_range.has(area):
		_in_range.append(area)


func _on_area_exited(area: Area2D) -> void:
	_in_range.erase(area)
