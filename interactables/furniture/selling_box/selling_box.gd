extends "res://interactables/interactable.gd"

## Selling Box world object (interactables/furniture/selling_box/selling_box.tscn).
## Unlike interactables/bed/bed.gd (still a fixed instance in
## MainFarmSpring.tscn), this scene is ONLY ever spawned dynamically by
## autoload/furniture.gd via player/furniture_placer.gd — see
## farming/furniture_data.gd for its Vector2i(2, 1) footprint.
##
## SELLING: right-click while a sellable produce item (Rice, Beans, ...) is
## the SELECTED hotbar item sells that entire stack — same "acts on
## whatever's selected" convention player/tool_use.gd uses for tools/seeds.
## There is no drag-and-drop shipping-bin UI; walk up, select the stack you
## want to sell (switch hotbar slot or drag from the backpack first), and
## right-click. Money does NOT appear in the wallet immediately — see
## autoload/wallet.gd's class doc comment for why the payout is delayed to
## the next day-advance (GameTime.date_changed).
##
## "Sellable" means: Inventory item ID resolves back to a CropData via
## farming/crop_data.gd's from_id() AND has sell_price > 0. This is why
## seeds/tools/furniture (and any future crop someone forgets to price)
## correctly do nothing here — from_id() only recognizes HARVESTED produce
## IDs ("rice", "beans"), never seed IDs ("rice_seed") or other item kinds.

const Crop := preload("res://farming/crop_data.gd")


func _ready() -> void:
	super._ready()
	prompt = "Sell"


## Gates BOTH whether right-click does anything AND whether
## player/interactor.gd even considers this box a candidate "nearest
## interactable" (see interactables/interactable.gd's shared contract) —
## so standing next to the box with nothing sellable selected simply does
## nothing, the same way an immature crop_plant.gd can't be harvested.
func can_interact(_actor: Node) -> bool:
	return enabled and _sellable_crop() != null


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	var crop = _sellable_crop()
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


## Shown by anything that calls get_interact_prompt() (see
## interactables/interactable.gd) — dynamic like crop_plant.gd's prompt,
## instead of the static "Sell" set in _ready(), so the player sees exactly
## what right-clicking will do before they commit to it.
func get_interact_prompt() -> String:
	var crop = _sellable_crop()
	if crop == null:
		return prompt
	var quantity := Inventory.get_selected_quantity()
	return "Sell %d %s (%dg)" % [quantity, crop.display_name, crop.sell_price * quantity]


## Returns the CropData for the currently selected hotbar item IF it's
## something this box will actually buy, else null. Single source of truth
## for both can_interact() and get_interact_prompt() so they can never
## disagree about what's sellable right now.
func _sellable_crop():
	var item_id := Inventory.get_selected_item()
	if item_id == Inventory.ITEM_NONE:
		return null
	var crop = Crop.from_id(item_id)
	if crop == null or crop.sell_price <= 0:
		return null
	return crop
