extends Node

signal inventory_changed
signal selection_changed(slot_index: int)

const SLOT_COUNT := 5

## Placeholder item ids. Expand as more tools/seeds are added.
const ITEM_NONE := ""
const ITEM_HOE := "hoe"
const ITEM_SEED := "seed"
const ITEM_WATERING_CAN := "watering_can"

var slots: Array[String] = []
var selected_slot: int = 0


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = ITEM_NONE
	slots[0] = ITEM_HOE
	slots[1] = ITEM_SEED
	slots[2] = ITEM_WATERING_CAN
	inventory_changed.emit()
	selection_changed.emit(selected_slot)


func get_selected_item() -> String:
	if selected_slot < 0 or selected_slot >= slots.size():
		return ITEM_NONE
	return slots[selected_slot]


func select_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	if selected_slot == index:
		return
	selected_slot = index
	selection_changed.emit(selected_slot)


func set_slot(index: int, item_id: String) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	slots[index] = item_id
	inventory_changed.emit()


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
