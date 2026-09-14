extends "res://interactables/interactable.gd"

## Selling Box world object (interactables/furniture/selling_box/selling_box.tscn).
## Spawned dynamically by autoload/furniture.gd via player/furniture_placer.gd —
## see farming/furniture_data.gd for its Vector2i(2, 1) footprint.
##
## Left-click (`interact`):
##   - Selected hotslot is sellable produce → sell that stack (pending gold).
##   - Otherwise → Furniture.pickup(self) to reposition into inventory.
##
## "Sellable" means: Inventory item ID resolves back to a CropData via
## farming/crop_data.gd's from_id() AND has sell_price > 0.

const Crop := preload("res://farming/crop_data.gd")


func _ready() -> void:
	super._ready()
	prompt = "Pick up"


## Always interactable when enabled so pickup works even with an empty hand
## or a non-sellable tool selected. Sell vs pickup is decided in interact().
func can_interact(_actor: Node) -> bool:
	return enabled


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	var crop = _sellable_crop()
	if crop == null:
		Furniture.pickup(self)
		return

	var quantity := Inventory.get_selected_quantity()
	if quantity <= 0:
		return
	var total: int = crop.sell_price * quantity
	# Remove FIRST, only bank the sale if the stack actually left the
	# hotslot — mirrors Soil.harvest()'s "only grant the item if it fits"
	# ordering, just inverted (here we're removing, not adding).
	if not Inventory.remove_from_selected(quantity):
		return
	Wallet.add_pending(total)


func get_interact_prompt() -> String:
	var crop = _sellable_crop()
	if crop == null:
		return "Pick up"
	var quantity := Inventory.get_selected_quantity()
	return "Sell %d %s (%dg)" % [quantity, crop.display_name, crop.sell_price * quantity]


## Returns the CropData for the currently selected hotbar item IF it's
## something this box will actually buy, else null.
func _sellable_crop():
	var item_id := Inventory.get_selected_item()
	if item_id == Inventory.ITEM_NONE:
		return null
	var crop = Crop.from_id(item_id)
	if crop == null or crop.sell_price <= 0:
		return null
	return crop
