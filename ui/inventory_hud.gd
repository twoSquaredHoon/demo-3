extends CanvasLayer

## AUTOLOAD (singleton) — load order #6 (last), see project.godot [autoload].
## Root script of ui/inventory_hud.tscn, layer 11 (above Location HUD's
## layer 10 — see GAME_SYSTEMS_SUMMARY.md section 21). Renders BOTH the
## always-visible bottom hotbar and the E-to-open/Escape-to-close full
## popup inventory grid — one script drives both, since they share the same
## underlying `Inventory` autoload data and the same slot widget
## (ui/inventory_slot.gd).
##
## This script owns no gameplay state itself. It:
##   1. Builds `Inventory.HOTSLOT_COUNT` (5) hotslot widgets and
##      `Inventory.INVENTORY_COUNT` (20) inventory-grid widgets once, in
##      _ready(), from `ui/inventory_slot.gd`.
##   2. Listens to `Inventory.inventory_changed` / `Inventory.selection_changed`
##      and simply asks every widget to refresh() itself from Inventory —
##      it never pushes data into widgets any other way.
##   3. Translates raw input (E, Escape, keys 1-5) into calls back into
##      `Inventory` (set_menu_open() indirectly via _open_menu()/_close_menu(),
##      select_hotslot()) — opening/closing the menu is what actually pauses
##      GameTime (see Inventory.set_menu_open(), which stamps GameTime.paused).
##
## Because this is an autoload-loaded CanvasLayer rather than a child of the
## farm scene, it persists across any future scene changes, same as
## LocationHud.

const SlotScript := preload("res://ui/inventory_slot.gd")

const HOTSLOT_SIZE := Vector2(52, 56)
const INVENTORY_SLOT_SIZE := Vector2(60, 64)

# %Unique-name lookups resolve nodes inside inventory_hud.tscn regardless of
# their exact path, as long as they're marked "Access as Unique Name" there.
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

	# Deliberately asymmetric with open_inventory: E only OPENS, it never
	# toggles closed — only Escape closes (see GAME_SYSTEMS_SUMMARY.md
	# section 4, "E does not toggle inventory closed").
	if event.is_action_pressed("close_inventory") and Inventory.is_menu_open:
		_close_menu()
		get_viewport().set_input_as_handled()
		return

	# Number keys 1-5 always change the selected hotslot, even while the
	# popup menu is open (this is intentional — see GAME_SYSTEMS_SUMMARY.md
	# section 19, "Number keys still change selected hotslot").
	for i in Inventory.HOTSLOT_COUNT:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			Inventory.select_hotslot(i)
			get_viewport().set_input_as_handled()
			return


func _open_menu() -> void:
	inventory_menu.visible = true
	# This is what pauses GameTime — see Inventory.set_menu_open(), and
	# player.gd/tool_use.gd/interactor.gd, which all check
	# Inventory.is_menu_open to freeze movement/tools/interaction to match.
	Inventory.set_menu_open(true)
	_refresh()


func _close_menu() -> void:
	inventory_menu.visible = false
	Inventory.set_menu_open(false)


## Wipes and rebuilds `parent`'s children as `Inventory.slot_count(kind)`
## fresh ui/inventory_slot.gd widgets. Called twice from _ready() — once for
## the 5 hotslots, once for the 20 inventory-grid slots — with `kind` being
## the only thing that differs between the two calls.
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
	# Only the hotslots need to redraw the gold selection border on
	# selection change — the popup grid's slots don't carry a "selected"
	# state.
	for slot in _hotslots:
		slot.refresh()


## Purely cosmetic: applies a themed StyleBoxFlat to the popup panel at
## runtime rather than baking it into the .tscn, so the look can be tweaked
## here without touching scene resources.
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
