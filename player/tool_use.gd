extends Node

## Child of Player (player/player.tscn: Player → ToolUse). Handles every
## farming action on LEFT-click (`interact`), including harvesting the crop
## under the targeted tile (see player/interactor.gd, which defers to this
## via wants_click()). Reads whatever item is currently selected
## in the hotbar (`Inventory.get_selected_item()`) and, if it's a recognized
## tool/seed/furniture, applies it.
##
## Dispatch table (see _try_use_on_target()):
##   Hoe            -> Soil.till(cell)
##   Watering Can   -> Soil.water(cell)
##   any known seed -> Soil.plant(cell, item_id); consumes ONE seed, but
##                     ONLY if plant() reported success (so a wasted click
##                     on invalid soil never costs a seed).
##   furniture      -> Furniture.place via furniture_placer
##   anything else (produce, empty slot, unknown item) -> no use_item
##                     behavior at all.
##
## Harvesting: a mature crop on the targeted tile is harvested by the same
## left-click before any tool is used (Soil.harvest via _try_harvest_target).

@onready var tile_targeter: Node2D = $"../TileTargeter"
@onready var furniture_placer: Node2D = $"../FurniturePlacer"

const Furn := preload("res://farming/furniture_data.gd")


func _unhandled_input(event: InputEvent) -> void:
	if GameTime.paused:
		return
	# Everything farming is LEFT-click (`interact`): harvest, till, water,
	# plant, place furniture. Interactor runs first; it only talks to NPCs
	# under the cursor and leaves the click here when wants_click() is true.
	if event.is_action_pressed("interact"):
		if _try_harvest_target():
			get_viewport().set_input_as_handled()
			return
		var item_id := Inventory.get_selected_item()
		if Furn.from_item(item_id) == null and not _is_farming_item(item_id):
			return
		_try_use_on_target()
		get_viewport().set_input_as_handled()


## True when a left-click should farm instead of using a nearby object:
## a mature crop is under the targeted tile, or a farming tool/seed/
## furniture item is selected.
func wants_click() -> bool:
	if tile_targeter != null and tile_targeter.has_target \
			and Soil.is_harvestable(tile_targeter.targeted_cell):
		return true
	var item_id := Inventory.get_selected_item()
	if Furn.from_item(item_id) != null:
		return true
	return _is_farming_item(item_id) and tile_targeter != null and tile_targeter.has_target


func _is_farming_item(item_id: String) -> bool:
	return item_id == Inventory.ITEM_HOE \
		or item_id == Inventory.ITEM_WATERING_CAN \
		or Inventory.is_seed(item_id)


func _try_harvest_target() -> bool:
	if tile_targeter == null or not tile_targeter.has_target:
		return false
	var cell: Vector2i = tile_targeter.targeted_cell
	if not Soil.is_harvestable(cell):
		return false
	return Soil.harvest(cell)


func _try_use_on_target() -> void:
	var item_id := Inventory.get_selected_item()
	if item_id == Inventory.ITEM_NONE:
		return

	# Furniture placement (see player/furniture_placer.gd) is mouse-position
	# based, NOT gated by tile_targeter's short reach radius, so a
	# furniture item short-circuits the farming dispatch below entirely —
	# it never even needs tile_targeter.has_target to be true.
	if Furn.from_item(item_id) != null:
		if furniture_placer == null:
			push_error("ToolUse: FurniturePlacer missing")
			return
		if furniture_placer.try_place():
			Inventory.remove_from_selected(1)
		return

	if tile_targeter == null or not tile_targeter.has_target:
		return
	var cell: Vector2i = tile_targeter.targeted_cell

	match item_id:
		Inventory.ITEM_HOE:
			Soil.till(cell)
		Inventory.ITEM_WATERING_CAN:
			Soil.water(cell)
		_:
			# Anything that isn't the Hoe or Watering Can but IS a
			# recognized seed (see Inventory.is_seed()) attempts planting;
			# produce items and unrecognized IDs simply fall through and do
			# nothing on use_item.
			if Inventory.is_seed(item_id):
				if Soil.plant(cell, item_id):
					Inventory.remove_from_selected(1)
