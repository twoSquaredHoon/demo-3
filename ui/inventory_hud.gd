extends CanvasLayer

const SLOT_SIZE := Vector2(52, 56)

@onready var slots_row: HBoxContainer = %SlotsRow

var _slot_roots: Array[Control] = []
var _slot_panels: Array[Panel] = []
var _slot_icons: Array[ColorRect] = []
var _slot_labels: Array[Label] = []


func _ready() -> void:
	_build_slots()
	Inventory.inventory_changed.connect(_refresh)
	Inventory.selection_changed.connect(_on_selection_changed)
	_refresh()
	_on_selection_changed(Inventory.selected_slot)


func _unhandled_input(event: InputEvent) -> void:
	for i in Inventory.SLOT_COUNT:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			Inventory.select_slot(i)
			get_viewport().set_input_as_handled()
			return


func _build_slots() -> void:
	for child in slots_row.get_children():
		child.queue_free()
	_slot_roots.clear()
	_slot_panels.clear()
	_slot_icons.clear()
	_slot_labels.clear()

	for i in Inventory.SLOT_COUNT:
		var root := Control.new()
		root.custom_minimum_size = SLOT_SIZE

		var panel := Panel.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
		style.border_color = Color(0.55, 0.55, 0.6, 1.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)
		root.add_child(panel)

		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 6
		content.offset_top = 14
		content.offset_right = -6
		content.offset_bottom = -6
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		root.add_child(content)

		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(28, 18)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.color = Color(0.2, 0.2, 0.2, 0.5)
		content.add_child(icon)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.text = ""
		content.add_child(label)

		var index_label := Label.new()
		index_label.text = str(i + 1)
		index_label.add_theme_font_size_override("font_size", 10)
		index_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1))
		index_label.position = Vector2(5, 2)
		root.add_child(index_label)

		slots_row.add_child(root)
		_slot_roots.append(root)
		_slot_panels.append(panel)
		_slot_icons.append(icon)
		_slot_labels.append(label)


func _refresh() -> void:
	for i in Inventory.SLOT_COUNT:
		var item_id := Inventory.slots[i]
		_slot_labels[i].text = Inventory.item_display_name(item_id)
		_slot_icons[i].color = Inventory.item_color(item_id)
		_slot_icons[i].visible = item_id != Inventory.ITEM_NONE
	_on_selection_changed(Inventory.selected_slot)


func _on_selection_changed(slot_index: int) -> void:
	for i in _slot_panels.size():
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
		style.set_corner_radius_all(4)
		if i == slot_index:
			style.border_color = Color(0.95, 0.85, 0.35, 1.0)
			style.set_border_width_all(3)
		else:
			style.border_color = Color(0.55, 0.55, 0.6, 1.0)
			style.set_border_width_all(2)
		_slot_panels[i].add_theme_stylebox_override("panel", style)
