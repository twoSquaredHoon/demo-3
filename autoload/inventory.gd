extends Node

## AUTOLOAD (singleton) — load order #3, see project.godot [autoload].
##
## Two containers: hotslots (the bottom bar, selectable with 1-5, i.e. your
## "pockets") and inventory (the popup grid, your "backpack"). Items can move
## freely between them as stacks.
##
## NOTE ON DOCUMENTATION: as of this pass, `GAME_SYSTEMS_SUMMARY.md` section
## 17 still describes the OLDER add-item rule ("Existing matching stacks
## fill first. Empty normal-inventory slots fill second... Harvested produce
## never automatically enters hotslots."). This script was edited (see
## try_add_item()/_plan_add_item() below) to instead prefer the SELECTED
## pocket first when placing a new item into an empty slot, meaning
## harvested produce CAN now land directly in a hotslot. See
## CODE_REVIEW_NOTES.md and the section 39 addendum in
## GAME_SYSTEMS_SUMMARY.md for the full comparison — the doc has not yet
## been updated to match this newer behavior.
##
## Also owns which hotslot is selected, whether the inventory menu is open,
## and (today) the placeholder display name/color for every item ID — see
## the "Item Presentation" note near item_display_name()/item_color()
## below for why that last part is a known architecture smell.
##
## Who talks to this script:
##   - `player/tool_use.gd` reads get_selected_item() to decide which tool
##     runs on left-click, and calls remove_from_selected() after a seed is
##     successfully planted via Soil.plant().
##   - `player/player.gd` and `player/interactor.gd` check Inventory.is_menu_open
##     to freeze movement/interaction while the popup is open.
##   - `autoload/soil.gd` calls Inventory.try_add_item() when a crop is
##     harvested — the harvest itself is rejected if the inventory/hotslots
##     cannot fit it (see Soil.harvest()), so Inventory is the gatekeeper
##     for whether a harvest can succeed at all.
##   - `ui/inventory_hud.gd` and `ui/inventory_slot.gd` render this state and
##     turn clicks/drags into calls back into this script (select_hotslot(),
##     swap_items()). They also toggle set_menu_open(), which in turn pauses
##     `GameTime` — see GameTime.paused.
##
## KNOWN LIMITATION (tracked in GAME_SYSTEMS_SUMMARY.md section 17): `hotslots`
## and `items` are public arrays, so any script technically *could* mutate a
## stack directly and bypass capacity/validation. Everything in this file
## goes through the helper functions instead; please keep doing that when
## extending this script.

signal inventory_changed
signal selection_changed(hotslot_index: int)
## Emitted whenever the popup inventory opens/closes. Currently has no
## subscriber anywhere in the project (ui/inventory_hud.gd tracks open/close
## itself instead) — kept for future UI/audio hooks that want to react to
## menu visibility without polling Inventory.is_menu_open every frame.
signal menu_visibility_changed(is_open: bool)

const KIND_HOTSLOT := "hotslot"
const KIND_INVENTORY := "inventory"

const HOTSLOT_COUNT := 5
const INVENTORY_COUNT := 20
const INVENTORY_COLUMNS := 5
const MAX_STACK := 99

# Canonical item-ID strings. Every other script that needs to recognize an
# item (tool_use.gd's match statement, soil.gd's harvest lookups, etc.)
# reads these constants rather than hardcoding string literals, so renaming
# an item only requires editing this file.
const ITEM_NONE := ""
const ITEM_HOE := "hoe"
const ITEM_WATERING_CAN := "watering_can"
const ITEM_RICE_SEED := "rice_seed"
const ITEM_BEANS_SEED := "beans_seed"
const ITEM_RICE := "rice"
const ITEM_BEANS := "beans"
const ITEM_BED := "bed"
const ITEM_SELLING_BOX := "selling_box"

## hotslots[i] and items[i] are both {"id": String, "quantity": int} stacks.
## Public on purpose (UI reads them indirectly through get_item()/get_quantity()
## rather than touching these arrays directly) but see the limitation note
## above the class doc comment.
var hotslots: Array[Dictionary] = []
var items: Array[Dictionary] = []
var selected_hotslot: int = 0
var is_menu_open: bool = false


func _ready() -> void:
	hotslots.resize(HOTSLOT_COUNT)
	for i in HOTSLOT_COUNT:
		hotslots[i] = _empty_stack()
	items.resize(INVENTORY_COUNT)
	for i in INVENTORY_COUNT:
		items[i] = _empty_stack()

	# Starting loadout: enough of each tool/seed to try the full farming
	# loop (till → plant → water → sleep → harvest) without needing the
	# (nonexistent) shop system. See crop_data.gd for what the seeds grow.
	hotslots[0] = _make_stack(ITEM_HOE, 1)
	hotslots[1] = _make_stack(ITEM_RICE_SEED, 10)
	hotslots[2] = _make_stack(ITEM_BEANS_SEED, 10)
	hotslots[3] = _make_stack(ITEM_WATERING_CAN, 1)
	# hotslots[4] stays empty by design (5 slots, only 4 starting items).

	# Starting furniture: placeable items live in the BACKPACK, not a
	# hotslot, since they're a one-time setup action rather than a tool
	# used every day — drag one into a hotslot to place it (see
	# player/furniture_placer.gd).
	items[0] = _make_stack(ITEM_BED, 1)
	items[1] = _make_stack(ITEM_SELLING_BOX, 1)

	inventory_changed.emit()
	selection_changed.emit(selected_hotslot)


func set_menu_open(open: bool) -> void:
	if is_menu_open == open:
		return
	is_menu_open = open
	# Directly stamping GameTime.paused (rather than going through a signal)
	# means only ONE thing can ever be the reason time is paused — see risk
	# #10 in GAME_SYSTEMS_SUMMARY.md: a future second pause source (dialogue,
	# a cutscene, etc.) would silently fight with this line.
	GameTime.paused = open
	menu_visibility_changed.emit(is_menu_open)


func slot_count(kind: String) -> int:
	return HOTSLOT_COUNT if kind == KIND_HOTSLOT else INVENTORY_COUNT


func get_item(kind: String, index: int) -> String:
	return str(_stack(kind, index).get("id", ITEM_NONE))


func get_quantity(kind: String, index: int) -> int:
	return int(_stack(kind, index).get("quantity", 0))


func get_selected_item() -> String:
	return get_item(KIND_HOTSLOT, selected_hotslot)


## Unused outside this file today (see GAME_SYSTEMS_SUMMARY.md section 25,
## "API currently unused"); kept as the natural counterpart to
## get_selected_item() for whatever UI eventually wants to show "x/99".
func get_selected_quantity() -> int:
	return get_quantity(KIND_HOTSLOT, selected_hotslot)


func select_hotslot(index: int) -> void:
	if index < 0 or index >= HOTSLOT_COUNT:
		return
	if selected_hotslot == index:
		return
	selected_hotslot = index
	# ui/inventory_hud.gd listens to this to redraw the gold selection border,
	# and player/tool_use.gd reads selected_hotslot indirectly through
	# get_selected_item() on the next left-click — no signal needed there.
	# Also affects future try_add_item() calls: _empty_slot_search_order()
	# below always tries the CURRENTLY selected hotslot first.
	selection_changed.emit(selected_hotslot)


## Adds items picked up in the world (harvests, etc). Placement priority:
##   1) top up any existing matching stack, pockets (hotslots) before backpack
##   2) an empty slot, preferring the *selected* pocket, then any other pocket,
##      then the backpack grid
## All-or-nothing: if the full amount cannot be placed, nothing changes.
##
## This is the entry point `autoload/soil.gd`'s harvest() calls. Because
## placement is planned (see _plan_add_item()) before anything is mutated,
## a harvest that doesn't fully fit leaves the mature crop on the ground,
## still harvestable, rather than silently discarding part of it.
func try_add_item(item_id: String, amount: int) -> bool:
	if item_id == ITEM_NONE or amount <= 0:
		return false
	var plan := _plan_add_item(item_id, amount)
	if _plan_total(plan) < amount:
		return false
	_apply_add_plan(item_id, plan)
	inventory_changed.emit()
	return true


func remove_item(kind: String, index: int, amount: int = 1) -> bool:
	var stack := _stack(kind, index)
	var item_id := str(stack.get("id", ITEM_NONE))
	var quantity := int(stack.get("quantity", 0))
	if item_id == ITEM_NONE or amount <= 0 or quantity < amount:
		return false
	quantity -= amount
	if quantity <= 0:
		_set_stack(kind, index, _empty_stack())
	else:
		_set_stack(kind, index, _make_stack(item_id, quantity))
	inventory_changed.emit()
	return true


## Used by player/tool_use.gd to consume exactly one seed, and ONLY after
## Soil.plant() already reported success — so a failed plant (e.g. tile not
## tilled) never costs the player a seed.
func remove_from_selected(amount: int = 1) -> bool:
	return remove_item(KIND_HOTSLOT, selected_hotslot, amount)


## Backs drag-and-drop in ui/inventory_slot.gd. Same-item stacks merge up to
## MAX_STACK (leftover stays behind in the source slot instead of being
## dropped); different items swap places entirely.
func swap_items(from_kind: String, from_index: int, to_kind: String, to_index: int) -> void:
	if from_kind == to_kind and from_index == to_index:
		return
	var from_stack := _stack(from_kind, from_index).duplicate()
	var to_stack := _stack(to_kind, to_index).duplicate()
	if str(from_stack.get("id", ITEM_NONE)) == ITEM_NONE:
		return

	var from_id := str(from_stack.get("id", ITEM_NONE))
	var to_id := str(to_stack.get("id", ITEM_NONE))
	if to_id != ITEM_NONE and from_id == to_id:
		# Merge path: same item on both ends, top up the destination and
		# leave any overflow sitting in the source (no data is lost).
		var from_qty := int(from_stack.get("quantity", 0))
		var to_qty := int(to_stack.get("quantity", 0))
		var space := MAX_STACK - to_qty
		if space <= 0:
			return
		var moved := mini(space, from_qty)
		_set_stack(to_kind, to_index, _make_stack(to_id, to_qty + moved))
		var remaining := from_qty - moved
		if remaining <= 0:
			_set_stack(from_kind, from_index, _empty_stack())
		else:
			_set_stack(from_kind, from_index, _make_stack(from_id, remaining))
	else:
		# Swap path: different items (or destination empty) just trade places.
		_set_stack(from_kind, from_index, to_stack)
		_set_stack(to_kind, to_index, from_stack)

	inventory_changed.emit()
	# Re-emitted so the HUD refreshes the selection border in case the
	# selected hotslot's contents just changed via drag/drop.
	selection_changed.emit(selected_hotslot)


## NOTE (item presentation): display name/color for every item are
## hardcoded here via item ID, duplicating what `inventory/item_data.gd`
## (an ItemData Resource) was designed to hold. item_data.gd is currently
## unused — see GAME_SYSTEMS_SUMMARY.md sections 18/23 for the intended
## cleanup (make ItemData authoritative and delete these two matches).
func item_display_name(item_id: String) -> String:
	match item_id:
		ITEM_HOE:
			return "Hoe"
		ITEM_WATERING_CAN:
			return "Water"
		ITEM_RICE_SEED:
			return "Rice Seed"
		ITEM_BEANS_SEED:
			return "Beans Seed"
		ITEM_RICE:
			return "Rice"
		ITEM_BEANS:
			return "Beans"
		ITEM_BED:
			return "Bed"
		ITEM_SELLING_BOX:
			return "Selling Box"
		_:
			return ""


func item_color(item_id: String) -> Color:
	match item_id:
		ITEM_HOE:
			return Color(0.55, 0.35, 0.18, 1.0)
		ITEM_WATERING_CAN:
			return Color(0.25, 0.55, 0.95, 1.0)
		ITEM_RICE_SEED:
			return Color(0.85, 0.8, 0.35, 1.0)
		ITEM_BEANS_SEED:
			return Color(0.35, 0.55, 0.2, 1.0)
		ITEM_RICE:
			return Color(0.95, 0.9, 0.55, 1.0)
		ITEM_BEANS:
			return Color(0.45, 0.7, 0.25, 1.0)
		ITEM_BED:
			return Color(0.45, 0.55, 0.85, 1.0)
		ITEM_SELLING_BOX:
			return Color(0.75, 0.55, 0.25, 1.0)
		_:
			return Color(0.2, 0.2, 0.2, 0.5)


## Used by player/tool_use.gd to route the selected item to Soil.plant()
## instead of till()/water(). Keep in sync with crop_data.gd's seed IDs.
func is_seed(item_id: String) -> bool:
	return item_id == ITEM_RICE_SEED or item_id == ITEM_BEANS_SEED


## Builds a placement plan without mutating state: a list of
## {kind, index, add} entries describing where up to `amount` of `item_id`
## would land. Caller checks _plan_total(plan) against `amount` before
## applying, so a too-full inventory never causes a partial add.
##
## Pass order (all four steps run in sequence, each picking up where the
## last left off via `remaining`):
##   1. Top up existing matching stacks in the HOTSLOTS.
##   2. Top up existing matching stacks in the INVENTORY grid.
##   3. Fill empty hotslots, selected hotslot first (_empty_slot_search_order()).
##   4. Fill empty inventory-grid slots, in plain index order.
func _plan_add_item(item_id: String, amount: int) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var remaining := amount

	remaining = _plan_fill_matching(KIND_HOTSLOT, item_id, remaining, plan)
	if remaining <= 0:
		return plan
	remaining = _plan_fill_matching(KIND_INVENTORY, item_id, remaining, plan)
	if remaining <= 0:
		return plan

	for index in _empty_slot_search_order():
		if remaining <= 0:
			break
		if str(hotslots[index].get("id", ITEM_NONE)) != ITEM_NONE:
			continue
		var add := mini(MAX_STACK, remaining)
		plan.append({"kind": KIND_HOTSLOT, "index": index, "add": add})
		remaining -= add

	if remaining > 0:
		for index in INVENTORY_COUNT:
			if remaining <= 0:
				break
			if str(items[index].get("id", ITEM_NONE)) != ITEM_NONE:
				continue
			var add := mini(MAX_STACK, remaining)
			plan.append({"kind": KIND_INVENTORY, "index": index, "add": add})
			remaining -= add

	return plan


## Shared top-up pass used for both container kinds: walks `kind`'s slots in
## order, adding into any stack that already matches `item_id` and has room,
## and returns however much of `remaining` is still left to place.
func _plan_fill_matching(kind: String, item_id: String, remaining: int, plan: Array[Dictionary]) -> int:
	var container := _container(kind)
	for index in container.size():
		if remaining <= 0:
			break
		var stack := container[index]
		if str(stack.get("id", ITEM_NONE)) != item_id:
			continue
		var space := MAX_STACK - int(stack.get("quantity", 0))
		if space <= 0:
			continue
		var add := mini(space, remaining)
		plan.append({"kind": kind, "index": index, "add": add})
		remaining -= add
	return remaining


## Empty-hotslot search order: the selected pocket first, then the rest in
## order. Backpack slots are only tried once every pocket is full.
##
## This is the behavior change from the older "hotslots then inventory, in
## plain index order" rule — see the class-level doc comment at the top of
## this file for why this makes harvested produce able to land directly in
## a hotslot (specifically the currently-selected one) when it's empty.
func _empty_slot_search_order() -> Array[int]:
	var order: Array[int] = [selected_hotslot]
	for i in HOTSLOT_COUNT:
		if i != selected_hotslot:
			order.append(i)
	return order


func _plan_total(plan: Array[Dictionary]) -> int:
	var total := 0
	for entry in plan:
		total += int(entry["add"])
	return total


## Applies a plan built by _plan_add_item(). Only called after
## try_add_item() has already confirmed the full amount fits, so every
## entry here is guaranteed to be a valid placement.
func _apply_add_plan(item_id: String, plan: Array[Dictionary]) -> void:
	for entry in plan:
		var kind: String = entry["kind"]
		var index: int = entry["index"]
		var add: int = entry["add"]
		var existing_quantity := get_quantity(kind, index)
		_set_stack(kind, index, _make_stack(item_id, existing_quantity + add))


func _container(kind: String) -> Array[Dictionary]:
	return hotslots if kind == KIND_HOTSLOT else items


func _stack(kind: String, index: int) -> Dictionary:
	var container := _container(kind)
	if index < 0 or index >= container.size():
		return _empty_stack()
	return container[index]


func _set_stack(kind: String, index: int, stack: Dictionary) -> void:
	var container := _container(kind)
	if index < 0 or index >= container.size():
		return
	container[index] = stack


func _empty_stack() -> Dictionary:
	return _make_stack(ITEM_NONE, 0)


func _make_stack(item_id: String, quantity: int) -> Dictionary:
	return {"id": item_id, "quantity": quantity}
