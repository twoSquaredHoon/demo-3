extends Node

## Child of Player (player/player.tscn: Player → ToolUse), the RIGHT-CLICK
## (`use_item`) half of the input split (see player/interactor.gd for the
## left-click `interact` half). Reads whatever item is currently selected
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
## Harvesting is NOT here — mature crops are harvested via `interact`
## through `interactables/crop/crop_plant.gd` (an interactable), not
## through the tool system. This script never touches Soil.harvest().

@onready var tile_targeter: Node2D = $"../TileTargeter"
@onready var furniture_placer: Node2D = $"../FurniturePlacer"

const Furn := preload("res://farming/furniture_data.gd")


func _unhandled_input(event: InputEvent) -> void:
	if GameTime.paused:
		return
	if event.is_action_pressed("use_item"):
		_try_use_on_target()
		get_viewport().set_input_as_handled()
		return
	# Interact is left-click. Interactor runs first and only consumes the
	# event when it uses a nearby object. If nothing was in range and the
	# selected hotslot is furniture, place it here — otherwise left-click
	# with a bed/selling-box selected would do nothing on empty ground.
	if event.is_action_pressed("interact"):
		var item_id := Inventory.get_selected_item()
		if Furn.from_item(item_id) == null:
			return
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
