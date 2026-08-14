extends CanvasLayer

const SlotScript := preload("res://ui/inventory_slot.gd")

const HOTSLOT_SIZE := Vector2(52, 56)
const INVENTORY_SLOT_SIZE := Vector2(60, 64)

@onready var hotslots_row: HBoxContainer = %HotslotsRow
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var inventory_menu: Control = %InventoryMenu

var _hotslots: Array[Panel] = []
var _inventory_slots: Array[Panel] = []


func _ready() -> void:
	_style_menu_panel()
	inventory_grid.columns = Inventory.INVENTORY_COLUMNS
	_build_slots(hotslots_row, Inventory.KIND_HOTSLOT, HOTSLOT_SIZE, true, _hotslots)
	_build_slots(inventory_grid, Inventory.KIND_INVENTORY, INVENTORY_SLOT_SIZE, false, _inventory_slots)
	inventory_menu.visible = false
	Inventory.inventory_changed.connect(_refresh)
	Inventory.selection_changed.connect(_on_selection_changed)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory") and not Inventory.is_menu_open:
		_open_menu()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("close_inventory") and Inventory.is_menu_open:
		_close_menu()
		get_viewport().set_input_as_handled()
		return

	for i in Inventory.HOTSLOT_COUNT:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			Inventory.select_hotslot(i)
			get_viewport().set_input_as_handled()
			return


func _open_menu() -> void:
	inventory_menu.visible = true
	Inventory.set_menu_open(true)
	_refresh()


func _close_menu() -> void:
	inventory_menu.visible = false
	Inventory.set_menu_open(false)


func _build_slots(
	parent: Container,
	kind: String,
	slot_size: Vector2,
	show_index: bool,
	out_slots: Array[Panel]
) -> void:
	for child in parent.get_children():
		child.queue_free()
	out_slots.clear()

	for i in Inventory.slot_count(kind):
		var slot: Panel = SlotScript.new()
		parent.add_child(slot)
		slot.configure(kind, i, slot_size, show_index)
		out_slots.append(slot)


func _refresh() -> void:
	for slot in _hotslots:
		slot.refresh()
	for slot in _inventory_slots:
		slot.refresh()


func _on_selection_changed(_hotslot_index: int) -> void:
	for slot in _hotslots:
		slot.refresh()


func _style_menu_panel() -> void:
	var panel := inventory_menu.get_node_or_null("CenterContainer/Panel") as PanelContainer
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.96)
	style.border_color = Color(0.65, 0.65, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
