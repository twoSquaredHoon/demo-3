extends Node

## Autoload #3. Owns hotslot (pocket) and inventory (backpack) stacks,
## hotslot selection, and whether the backpack menu is open.
## Item names/colors live in ItemData — this script only stores stacks.

signal inventory_changed
signal selection_changed(hotslot_index: int)

const KIND_HOTSLOT := "hotslot"
const KIND_INVENTORY := "inventory"

const HOTSLOT_COUNT := 5
const INVENTORY_COUNT := 20
const INVENTORY_COLUMNS := 5
const MAX_STACK := 99

const ITEM_NONE := ""
const ITEM_HOE := "hoe"
const ITEM_WATERING_CAN := "watering_can"
const ITEM_RICE_SEED := "rice_seed"
const ITEM_BEANS_SEED := "beans_seed"
const ITEM_RICE := "rice"
const ITEM_BEANS := "beans"
const ITEM_BED := "bed"
const ITEM_SELLING_BOX := "selling_box"

## Prefer get_item()/get_quantity() over mutating these arrays directly.
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

	hotslots[0] = _make_stack(ITEM_HOE, 1)
	hotslots[1] = _make_stack(ITEM_RICE_SEED, 10)
	hotslots[2] = _make_stack(ITEM_BEANS_SEED, 10)
	hotslots[3] = _make_stack(ITEM_WATERING_CAN, 1)
	items[0] = _make_stack(ITEM_BED, 1)
	items[1] = _make_stack(ITEM_SELLING_BOX, 1)

	inventory_changed.emit()
	selection_changed.emit(selected_hotslot)


func set_menu_open(open: bool) -> void:
	if is_menu_open == open:
		return
	is_menu_open = open
	if open:
		GameTime.request_pause("inventory")
	else:
		GameTime.release_pause("inventory")


func slot_count(kind: String) -> int:
	return HOTSLOT_COUNT if kind == KIND_HOTSLOT else INVENTORY_COUNT


func get_item(kind: String, index: int) -> String:
	return str(_stack(kind, index).get("id", ITEM_NONE))


func get_quantity(kind: String, index: int) -> int:
	return int(_stack(kind, index).get("quantity", 0))


func get_selected_item() -> String:
	return get_item(KIND_HOTSLOT, selected_hotslot)


func get_selected_quantity() -> int:
	return get_quantity(KIND_HOTSLOT, selected_hotslot)


func select_hotslot(index: int) -> void:
	if index < 0 or index >= HOTSLOT_COUNT:
		return
	if selected_hotslot == index:
		return
	selected_hotslot = index
	selection_changed.emit(selected_hotslot)


## All-or-nothing add. Tops up matching stacks (hotslots, then inventory),
## then empty slots: selected hotslot, other hotslots, then inventory.
func try_add_item(item_id: String, amount: int) -> bool:
	if item_id == ITEM_NONE or amount <= 0:
		return false
	var plan := _plan_add_item(item_id, amount)
	if _plan_total(plan) < amount:
		return false
	_apply_add_plan(item_id, plan)
	inventory_changed.emit()
	return true


## First empty hotslot, else first empty inventory slot. No merge.
## Used by Furniture.pickup() so repositioned furniture does not follow
## try_add_item()'s selected-hotslot / merge rules.
func try_add_to_first_empty(item_id: String, amount: int = 1) -> bool:
	if item_id == ITEM_NONE or amount <= 0 or amount > MAX_STACK:
		return false
	var dest_kind := KIND_HOTSLOT
	var dest_index := _first_empty_index(KIND_HOTSLOT)
	if dest_index < 0:
		dest_kind = KIND_INVENTORY
		dest_index = _first_empty_index(KIND_INVENTORY)
	if dest_index < 0:
		return false
	_set_stack(dest_kind, dest_index, _make_stack(item_id, amount))
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


func remove_from_selected(amount: int = 1) -> bool:
	return remove_item(KIND_HOTSLOT, selected_hotslot, amount)


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
		_set_stack(from_kind, from_index, to_stack)
		_set_stack(to_kind, to_index, from_stack)

	inventory_changed.emit()


## Menu-only. Whole stack to the first empty slot of the other container.
func quick_transfer(kind: String, index: int) -> bool:
	if not is_menu_open:
		return false
	var source := _stack(kind, index).duplicate()
	if str(source.get("id", ITEM_NONE)) == ITEM_NONE:
		return false

	var dest_kind := KIND_INVENTORY if kind == KIND_HOTSLOT else KIND_HOTSLOT
	var dest_index := _first_empty_index(dest_kind)
	if dest_index < 0:
		return false

	_set_stack(dest_kind, dest_index, source)
	_set_stack(kind, index, _empty_stack())
	inventory_changed.emit()
	return true


func is_seed(item_id: String) -> bool:
	return item_id == ITEM_RICE_SEED or item_id == ITEM_BEANS_SEED


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


func _apply_add_plan(item_id: String, plan: Array[Dictionary]) -> void:
	for entry in plan:
		var kind: String = entry["kind"]
		var index: int = entry["index"]
		var add: int = entry["add"]
		var existing_quantity := get_quantity(kind, index)
		_set_stack(kind, index, _make_stack(item_id, existing_quantity + add))


func _container(kind: String) -> Array[Dictionary]:
	return hotslots if kind == KIND_HOTSLOT else items


func _first_empty_index(kind: String) -> int:
	var container := _container(kind)
	for i in container.size():
		if str(container[i].get("id", ITEM_NONE)) == ITEM_NONE:
			return i
	return -1


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
