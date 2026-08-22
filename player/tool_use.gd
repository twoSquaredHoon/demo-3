extends Node

## Child of Player (player/player.tscn: Player → ToolUse), the LEFT-CLICK
## half of the input split (see player/interactor.gd for the right-click
## half). Reads whatever item is currently selected in the hotbar
## (`Inventory.get_selected_item()`) and, if it's a recognized tool/seed,
## applies it to whatever cell `farming/tile_targeter.gd` is currently
## aiming at.
##
## Dispatch table (see _try_use_on_target()):
##   Hoe            -> Soil.till(cell)
##   Watering Can   -> Soil.water(cell)
##   any known seed -> Soil.plant(cell, item_id); consumes ONE seed, but
##                     ONLY if plant() reported success (so a wasted click
##                     on invalid soil never costs a seed).
##   anything else (produce, empty slot, unknown item) -> no left-click
##                     behavior at all.
##
## Harvesting is NOT here — mature crops are harvested via right-click
## through `interactables/crop/crop_plant.gd` (an interactable), not
## through the tool system. This script never touches Soil.harvest().

@onready var tile_targeter: Node2D = $"../TileTargeter"
@onready var furniture_placer: Node2D = $"../FurniturePlacer"

const Furn := preload("res://farming/furniture_data.gd")


func _unhandled_input(event: InputEvent) -> void:
	# Same Inventory.is_menu_open guard used across Player/Interactor:
	# tools do nothing while the popup inventory is open.
	if Inventory.is_menu_open:
		return
	if event.is_action_pressed("use_item"):
		_try_use_on_target()
		get_viewport().set_input_as_handled()


func _try_use_on_target() -> void:
	var item_id := Inventory.get_selected_item()
	if item_id == Inventory.ITEM_NONE:
		return

	# Furniture placement (see player/furniture_placer.gd) is mouse-position
	# based, NOT gated by tile_targeter's short reach radius, so a
	# furniture item short-circuits the farming dispatch below entirely —
	# it never even needs tile_targeter.has_target to be true.
	if Furn.from_item(item_id) != null:
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
			# nothing on left-click.
			if Inventory.is_seed(item_id):
				if Soil.plant(cell, item_id):
					Inventory.remove_from_selected(1)
