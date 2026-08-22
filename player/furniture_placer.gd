extends Node2D

## Child of Player (player/player.tscn: Player → FurniturePlacer). Shows a
## mouse-following, grid-snapped preview whenever the selected hotbar item
## is furniture (see farming/furniture_data.gd), colored green/red for
## valid/invalid placement, and performs the actual placement when
## player/tool_use.gd routes a left-click here via try_place().
##
## Mirrors farming/tile_targeter.gd's lazy TileMap-resolve + reparented-
## overlay-node trick, but highlights a whole FOOTPRINT of cells instead of
## a single one, and is NOT restricted by tile_targeter's short reach
## radius — furniture placement is mouse-position based only (per the
## original request), so this resolves its own target cell independently
## rather than reading tile_targeter.targeted_cell.
##
## This node has no _unhandled_input of its own on purpose: input stays
## single-entry through player/tool_use.gd so there is exactly one place
## that decides what a left-click does.

const Furn := preload("res://farming/furniture_data.gd")

const VALID_COLOR := Color(0.4, 0.9, 0.5, 0.45)
const INVALID_COLOR := Color(0.95, 0.3, 0.3, 0.45)

var _tile_map: TileMap
var _preview: Polygon2D
var _current_data = null # FurnitureData Resource, or null when nothing furniture-like is selected
var _anchor_cell: Vector2i = Vector2i.ZERO
var _is_valid_target: bool = false


func _ready() -> void:
	_preview = Polygon2D.new()
	_preview.z_index = 20
	_preview.visible = false
	_resolve_tile_map()


func _process(_delta: float) -> void:
	if _tile_map == null or not is_instance_valid(_tile_map):
		_resolve_tile_map()
		if _tile_map == null:
			return
	_update_preview()


## Called by player/tool_use.gd on left-click when the selected item
## resolves to furniture data. Returns true if placement succeeded — the
## caller (tool_use.gd) is then responsible for consuming the item from
## Inventory, same "validate in here, mutate over there" split
## Soil.plant()/tool_use.gd already use for seeds.
func try_place() -> bool:
	if _current_data == null or not _is_valid_target:
		return false
	return Furniture.place(_current_data.item_id, _anchor_cell)


func _update_preview() -> void:
	var item_id := Inventory.get_selected_item()
	var data = Furn.from_item(item_id)
	_current_data = data
	if data == null:
		_preview.visible = false
		return

	var footprint: Vector2i = data.footprint
	_anchor_cell = _mouse_anchor_cell(footprint)
	_is_valid_target = Furniture.can_place(_anchor_cell, footprint)

	var tile_size := _tile_size()
	var top_left := _tile_map.map_to_local(_anchor_cell) - tile_size * 0.5
	var size := Vector2(footprint) * tile_size
	_preview.polygon = PackedVector2Array([
		top_left,
		top_left + Vector2(size.x, 0),
		top_left + size,
		top_left + Vector2(0, size.y),
	])
	_preview.color = VALID_COLOR if _is_valid_target else INVALID_COLOR
	_preview.visible = true


## Anchor is the footprint's TOP-LEFT cell; centering the footprint on the
## cursor's own cell (rather than always growing down-right from it) keeps
## placement feeling centered under the mouse. Integer division biases a
## footprint with an even side toward the cursor's cell being its
## bottom/right half rather than a perfectly even split — acceptable for a
## 1x2 or 2x1 footprint.
func _mouse_anchor_cell(footprint: Vector2i) -> Vector2i:
	var mouse_world := get_global_mouse_position()
	var center_cell := _tile_map.local_to_map(_tile_map.to_local(mouse_world))
	return center_cell - Vector2i(footprint.x / 2, footprint.y / 2)


func _tile_size() -> Vector2:
	if _tile_map != null and _tile_map.tile_set != null:
		return Vector2(_tile_map.tile_set.tile_size)
	return Vector2(16, 16)


func _resolve_tile_map() -> void:
	_tile_map = get_tree().get_first_node_in_group("farm_tilemap") as TileMap
	if _tile_map == null:
		return
	if _preview.get_parent() != _tile_map:
		if _preview.get_parent() != null:
			_preview.reparent(_tile_map)
		else:
			_tile_map.add_child(_preview)
