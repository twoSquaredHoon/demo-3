extends Area2D

## Finds the nearest overlapping interactable and triggers it on `interact`.

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
	if Inventory.is_menu_open:
		return
	if event.is_action_pressed("interact"):
		var target := get_nearest()
		if target == null:
			return
		var actor := get_parent()
		if not target.can_interact(actor):
			return
		target.interact(actor)
		get_viewport().set_input_as_handled()


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
