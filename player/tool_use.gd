extends Node

## Uses the currently selected inventory item on the farm target tile.

@onready var tile_targeter: Node2D = $"../TileTargeter"


func _unhandled_input(event: InputEvent) -> void:
	if Inventory.is_menu_open:
		return
	if event.is_action_pressed("use_item"):
		_try_use_selected_item()
		get_viewport().set_input_as_handled()


func _try_use_selected_item() -> void:
	var item_id := Inventory.get_selected_item()
	if item_id == Inventory.ITEM_NONE:
		return
	if tile_targeter == null or not tile_targeter.has_target:
		return

	match item_id:
		Inventory.ITEM_HOE:
			Soil.till(tile_targeter.targeted_cell)
		Inventory.ITEM_SEED:
			Soil.plant(tile_targeter.targeted_cell, Inventory.ITEM_SEED)
		Inventory.ITEM_WATERING_CAN:
			Soil.water(tile_targeter.targeted_cell)
		_:
			pass
