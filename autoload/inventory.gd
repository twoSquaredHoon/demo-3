extends Node

## Two containers: hotslots (the bottom bar, selectable with 1-5) and inventory
## (the popup grid). Items can move freely between them.

signal inventory_changed
signal selection_changed(hotslot_index: int)
signal menu_visibility_changed(is_open: bool)

const KIND_HOTSLOT := "hotslot"
const KIND_INVENTORY := "inventory"

const HOTSLOT_COUNT := 5
const INVENTORY_COUNT := 20
const INVENTORY_COLUMNS := 5

## Placeholder item ids. Expand as more tools/seeds are added.
const ITEM_NONE := ""
const ITEM_HOE := "hoe"
const ITEM_SEED := "seed"
const ITEM_WATERING_CAN := "watering_can"

var hotslots: Array[String] = []
var items: Array[String] = []
var selected_hotslot: int = 0
var is_menu_open: bool = false


func _ready() -> void:
	hotslots.resize(HOTSLOT_COUNT)
	for i in HOTSLOT_COUNT:
		hotslots[i] = ITEM_NONE
	items.resize(INVENTORY_COUNT)
	for i in INVENTORY_COUNT:
		items[i] = ITEM_NONE

	hotslots[0] = ITEM_HOE
	hotslots[1] = ITEM_SEED
	hotslots[2] = ITEM_WATERING_CAN

	inventory_changed.emit()
	selection_changed.emit(selected_hotslot)


func set_menu_open(open: bool) -> void:
	if is_menu_open == open:
		return
	is_menu_open = open
	GameTime.paused = open
	menu_visibility_changed.emit(is_menu_open)


func slot_count(kind: String) -> int:
	return HOTSLOT_COUNT if kind == KIND_HOTSLOT else INVENTORY_COUNT


func get_item(kind: String, index: int) -> String:
	var container := _container(kind)
	if index < 0 or index >= container.size():
		return ITEM_NONE
	return container[index]


func set_item(kind: String, index: int, item_id: String) -> void:
	var container := _container(kind)
	if index < 0 or index >= container.size():
		return
	container[index] = item_id
	inventory_changed.emit()


func swap_items(from_kind: String, from_index: int, to_kind: String, to_index: int) -> void:
	if from_kind == to_kind and from_index == to_index:
		return
	var from_container := _container(from_kind)
	var to_container := _container(to_kind)
	if from_index < 0 or from_index >= from_container.size():
		return
	if to_index < 0 or to_index >= to_container.size():
		return

	var moved := from_container[from_index]
	from_container[from_index] = to_container[to_index]
	to_container[to_index] = moved
	inventory_changed.emit()
	selection_changed.emit(selected_hotslot)


func get_selected_item() -> String:
	return get_item(KIND_HOTSLOT, selected_hotslot)


func select_hotslot(index: int) -> void:
	if index < 0 or index >= HOTSLOT_COUNT:
		return
	if selected_hotslot == index:
		return
	selected_hotslot = index
	selection_changed.emit(selected_hotslot)


func item_display_name(item_id: String) -> String:
	match item_id:
		ITEM_HOE:
			return "Hoe"
		ITEM_SEED:
			return "Seed"
		ITEM_WATERING_CAN:
			return "Water"
		_:
			return ""


func item_color(item_id: String) -> Color:
	match item_id:
		ITEM_HOE:
			return Color(0.55, 0.35, 0.18, 1.0)
		ITEM_SEED:
			return Color(0.45, 0.75, 0.25, 1.0)
		ITEM_WATERING_CAN:
			return Color(0.25, 0.55, 0.95, 1.0)
		_:
			return Color(0.2, 0.2, 0.2, 0.5)


func _container(kind: String) -> Array[String]:
	return hotslots if kind == KIND_HOTSLOT else items
