extends Node2D

## Child of the Player (see player/player.tscn: Player → TileTargeter).
## Every frame, figures out which farm tile the mouse is over, whether that
## tile is within the player's reach, and draws a translucent highlight when
## it is. This is purely a targeting/aiming helper — it never mutates farm
## state itself.
##
## Consumers of this node's public state:
##   - `player/tool_use.gd` reads `has_target` and `targeted_cell` on
##     left-click to know which cell to till/water/plant.
##   - `player/interactor.gd` (right-click / "interact") does NOT use this
##     node at all — interaction targeting is proximity-based (nearest
##     overlapping Area2D), not cursor-based. So left-click tool use is
##     cursor-aimed via this script, while right-click interaction is
##     aimed by player position instead. See GAME_SYSTEMS_SUMMARY.md
##     sections 9 and 15 for this split.
##
## target_changed is emitted whenever has_target/targeted_cell actually
## change, but nothing currently subscribes to it (see GAME_SYSTEMS_SUMMARY.md
## section 25, "Emitted but unused") — reserved for e.g. a future cursor/
## crosshair UI reacting to aim state without polling every frame.
##
## KNOWN LIMITATION: the player's 16x32 body rectangle is hardcoded again in
## _get_body_rect_global() below, duplicating the collision shape defined on
## Player in player.tscn. If the player's collision size ever changes, this
## must be updated to match by hand.

signal target_changed(has_target: bool, cell: Vector2i)

@export var reach_radius: float = 16.0
@export var ground_layer: int = 0
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.4)

var targeted_cell: Vector2i = Vector2i.ZERO
var has_target: bool = false

var _tile_map: TileMap
## Runtime-created highlight polygon, reparented onto the TileMap itself
## (not this node) so its z-index (10) sorts correctly against Soil's
## overlays/crops/water marks, which also live under the TileMap.
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


## Finds the single TileMap in the "farm_tilemap" group (see soil.gd, which
## resolves the exact same group independently) and parents the highlight
## polygon under it.
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


## "Farmable" currently just means "has any ground-layer tile at all" — see
## GAME_SYSTEMS_SUMMARY.md section 9: there is no dedicated farmable-cell
## metadata yet, so every painted ground cell is a legal tilling target.
func _is_farmable_cell(cell: Vector2i) -> bool:
	return _tile_map.get_cell_source_id(ground_layer, cell) != -1


func _is_cell_in_reach(cell: Vector2i) -> bool:
	var cell_center := _tile_map.to_global(_tile_map.map_to_local(cell))
	return _distance_to_reach_rect(cell_center) <= reach_radius


## Distance from a point to the closest edge/corner of the player's body
## rectangle (not to its center) — this is what lets tiles directly beside
## the player register as in-reach even though the player origin itself may
## be farther than reach_radius away.
func _distance_to_reach_rect(point: Vector2) -> float:
	var rect := _get_body_rect_global()
	var closest := Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)
	return point.distance_to(closest)


func _get_body_rect_global() -> Rect2:
	# Player body is 16x32 centered on Player origin. Reach is measured only
	# from the UPPER 16x16 half of that rect (see the -16 y-offset with a
	# 32-tall size below being anchored at the top), matching where the
	# player's "hands" would plausibly reach.
	var player := get_parent() as Node2D
	var origin := player.global_position if player else global_position
	return Rect2(origin + Vector2(-8, -16), Vector2(16, 32))


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

	# Only emit when something actually changed, so consumers (if any are
	# ever added) don't get spammed every single frame the mouse holds still.
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
