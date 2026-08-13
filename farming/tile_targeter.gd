extends Node2D

## Highlights the mouse-aimed farm tile when it is within reach of the
## player's upper 16x16 body portion.

signal target_changed(has_target: bool, cell: Vector2i)

@export var reach_radius: float = 16.0
@export var ground_layer: int = 0
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.4)

var targeted_cell: Vector2i = Vector2i.ZERO
var has_target: bool = false

var _tile_map: TileMap
var _highlight: Polygon2D


func _ready() -> void:
	_highlight = Polygon2D.new()
	_highlight.color = highlight_color
	_highlight.z_index = 10
	_highlight.visible = false
	_resolve_tile_map()


func _process(_delta: float) -> void:
	if _tile_map == null or not is_instance_valid(_tile_map):
		_resolve_tile_map()
		if _tile_map == null:
			_clear_target()
			return
	_update_target()


func _resolve_tile_map() -> void:
	_tile_map = get_tree().get_first_node_in_group("farm_tilemap") as TileMap
	if _tile_map == null:
		return
	if _highlight.get_parent() != _tile_map:
		if _highlight.get_parent() != null:
			_highlight.reparent(_tile_map)
		else:
			_tile_map.add_child(_highlight)


func _update_target() -> void:
	var mouse_world := get_global_mouse_position()
	var cell := _tile_map.local_to_map(_tile_map.to_local(mouse_world))

	if not _is_farmable_cell(cell) or not _is_cell_in_reach(cell):
		_clear_target()
		return

	_set_target(cell)


func _is_farmable_cell(cell: Vector2i) -> bool:
	return _tile_map.get_cell_source_id(ground_layer, cell) != -1


func _is_cell_in_reach(cell: Vector2i) -> bool:
	var cell_center := _tile_map.to_global(_tile_map.map_to_local(cell))
	return _distance_to_reach_rect(cell_center) <= reach_radius


func _distance_to_reach_rect(point: Vector2) -> float:
	var rect := _get_upper_body_rect_global()
	var closest := Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)
	return point.distance_to(closest)


func _get_upper_body_rect_global() -> Rect2:
	# Player body is 16x32 centered on Player origin; upper half is 16x16.
	var player := get_parent() as Node2D
	var origin := player.global_position if player else global_position
	return Rect2(origin + Vector2(-8, -16), Vector2(16, 16))


func _set_target(cell: Vector2i) -> void:
	var changed := not has_target or targeted_cell != cell
	has_target = true
	targeted_cell = cell

	var tile_size := Vector2(_tile_size())
	var center := _tile_map.map_to_local(cell)
	var half := tile_size * 0.5
	_highlight.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])
	_highlight.color = highlight_color
	_highlight.visible = true

	if changed:
		target_changed.emit(true, cell)


func _clear_target() -> void:
	var changed := has_target
	has_target = false
	targeted_cell = Vector2i.ZERO
	if is_instance_valid(_highlight):
		_highlight.visible = false
	if changed:
		target_changed.emit(false, Vector2i.ZERO)


func _tile_size() -> Vector2i:
	if _tile_map.tile_set != null:
		return _tile_map.tile_set.tile_size
	return Vector2i(16, 16)
