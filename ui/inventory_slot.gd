extends Panel

## One clickable, drag-and-drop-capable inventory/hotslot widget. Instanced
## entirely from code by `ui/inventory_hud.gd`'s _build_slots() — there is
## no corresponding .tscn for this script; every child control (icon, name
## label, quantity label, index label) is built in configure() below.
##
## This widget holds NO item data of its own — `kind`/`index` just say
## which Inventory container-slot this widget represents, and refresh()
## always re-reads the actual stack (id + quantity) from `Inventory` via
## get_item()/get_quantity()/item_display_name()/item_color(). It never
## caches or guesses; `ui/inventory_hud.gd` calls refresh() on every slot
## whenever Inventory reports a change.
##
## Interaction:
##   - Left-click a HOTSLOT selects it (Inventory.select_hotslot());
##     left-clicking an inventory-grid slot does nothing by itself.
##   - Drag (from any non-empty slot) + drop onto another slot calls
##     Inventory.swap_items(), which merges matching stacks or swaps
##     mismatched ones — see Inventory.swap_items() for the exact rules.

const NORMAL_BORDER := Color(0.55, 0.55, 0.6, 1.0)
const SELECTED_BORDER := Color(0.95, 0.85, 0.35, 1.0)
const HOVER_BORDER := Color(0.75, 0.8, 0.9, 1.0)

var kind: String = Inventory.KIND_HOTSLOT
var index: int = 0

var _icon: ColorRect
var _name_label: Label
var _qty_label: Label
var _hovered: bool = false


## Called once by ui/inventory_hud.gd right after instancing this Panel.
## Builds the whole child-control tree in code (icon/name/quantity/index
## labels) since there's no scene file backing this widget.
func configure(p_kind: String, p_index: int, slot_size: Vector2, show_index: bool) -> void:
	kind = p_kind
	index = p_index
	custom_minimum_size = slot_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6
	content.offset_top = 14
	content.offset_right = -6
	content.offset_bottom = -6
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	# Child controls all use MOUSE_FILTER_IGNORE so only this root Panel
	# ever catches mouse input — otherwise a label or icon could steal a
	# click/drag meant for the slot itself.
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	_icon = ColorRect.new()
	_icon.custom_minimum_size = Vector2(28, 18)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_icon)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_name_label)

	_qty_label = Label.new()
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_qty_label.add_theme_font_size_override("font_size", 10)
	_qty_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_qty_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_qty_label.add_theme_constant_override("outline_size", 3)
	_qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qty_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_qty_label.offset_left = -22
	_qty_label.offset_top = -16
	_qty_label.offset_right = -4
	_qty_label.offset_bottom = -2
	add_child(_qty_label)

	if show_index:
		# Only hotslots get a "1"-"5" index label (show_index is false for
		# the 20-slot inventory grid — see ui/inventory_hud.gd's two
		# _build_slots() calls).
		var index_label := Label.new()
		index_label.text = str(index + 1)
		index_label.add_theme_font_size_override("font_size", 10)
		index_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1))
		index_label.position = Vector2(5, 2)
		index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(index_label)

	refresh()


## Re-reads this slot's item id/quantity straight from `Inventory` and
## redraws the icon color, name, quantity (hidden when <= 1), and border
## style. Called by ui/inventory_hud.gd on every Inventory.inventory_changed
## / selection_changed signal, so this widget is never out of sync.
func refresh() -> void:
	var item_id := Inventory.get_item(kind, index)
	var quantity := Inventory.get_quantity(kind, index)
	_name_label.text = Inventory.item_display_name(item_id)
	_icon.color = Inventory.item_color(item_id)
	_icon.visible = item_id != Inventory.ITEM_NONE
	_qty_label.text = str(quantity) if quantity > 1 else ""
	_apply_style()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	if kind == Inventory.KIND_HOTSLOT:
		Inventory.select_hotslot(index)


## Godot drag-and-drop entry point: returning null (empty slot) means the
## engine won't start a drag at all. The returned Dictionary is exactly what
## _drop_data() on the DESTINATION slot receives as `data`.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var item_id := Inventory.get_item(kind, index)
	if item_id == Inventory.ITEM_NONE:
		return null

	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(40, 30)
	preview.size = Vector2(40, 30)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Inventory.item_color(item_id)
	preview_style.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", preview_style)
	set_drag_preview(preview)

	return {"kind": kind, "index": index}


## Weak validation on purpose (per GAME_SYSTEMS_SUMMARY.md section 17,
## "UI validates drag payload weakly") — only checks the two keys exist,
## not that `kind`/`index` are actually sane values. Malformed external
## drag data reaching here could still call Inventory.swap_items() with
## bad indices; _stack()/_set_stack() in Inventory clamp out-of-range
## indices defensively, so this can't crash, but it is a known soft spot.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	return data.has("kind") and data.has("index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Inventory.swap_items(str(data["kind"]), int(data["index"]), kind, index)


func _on_mouse_entered() -> void:
	_hovered = true
	_apply_style()


func _on_mouse_exited() -> void:
	_hovered = false
	_apply_style()


## Border color priority: selected hotslot (gold) > hovered (blue-gray) >
## normal (gray). Rebuilds a fresh StyleBoxFlat every call rather than
## caching one per state — simplest correct approach at this widget count.
func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	style.set_corner_radius_all(4)

	if kind == Inventory.KIND_HOTSLOT and index == Inventory.selected_hotslot:
		style.border_color = SELECTED_BORDER
		style.set_border_width_all(3)
	elif _hovered:
		style.border_color = HOVER_BORDER
		style.set_border_width_all(2)
	else:
		style.border_color = NORMAL_BORDER
		style.set_border_width_all(2)

	add_theme_stylebox_override("panel", style)
