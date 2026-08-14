extends Node

## Tracks tilled soil / planted crops / watered soil and draws placeholder overlays.
## Crop stages are numeric: 0 planted … STAGE_MAX mature. Growth ticks once per
## GameTime.date_changed (sleep and midnight both go through _advance_day).

const TILLED_COLOR := Color(0.36, 0.22, 0.12, 0.85)
const WATERED_SOIL_COLOR := Color(0.22, 0.28, 0.45, 0.9)
const SPROUT_COLOR := Color(0.35, 0.85, 0.3, 1.0)
const WATER_DROP_COLOR := Color(0.4, 0.7, 1.0, 0.95)

const STAGE_PLANTED := 0
const STAGE_MAX := 3 # 0, 1, 2, 3 — mature at 3

var _tilled: Dictionary = {} # Vector2i -> true
var _planted: Dictionary = {} # Vector2i -> String (crop/seed id)
var _watered: Dictionary = {} # Vector2i -> true
var _stages: Dictionary = {} # Vector2i -> int
var _overlays: Dictionary = {} # Vector2i -> Polygon2D
var _sprouts: Dictionary = {} # Vector2i -> Node2D (polygon + stage label)
var _water_marks: Dictionary = {} # Vector2i -> Polygon2D
var _tile_map: TileMap
var _overlay_root: Node2D
var _sprout_root: Node2D
var _water_root: Node2D


func _ready() -> void:
	GameTime.date_changed.connect(_on_date_changed)


func _process(_delta: float) -> void:
	if _tile_map == null or not is_instance_valid(_tile_map):
		_resolve_tile_map()


func is_tilled(cell: Vector2i) -> bool:
	return _tilled.has(cell)


func is_planted(cell: Vector2i) -> bool:
	return _planted.has(cell)


func is_watered(cell: Vector2i) -> bool:
	return _watered.has(cell)


func get_stage(cell: Vector2i) -> int:
	return int(_stages.get(cell, -1))


func till(cell: Vector2i) -> bool:
	_resolve_tile_map()
	if _tile_map == null:
		return false
	if _tile_map.get_cell_source_id(0, cell) == -1:
		return false
	if is_tilled(cell):
		return false

	_tilled[cell] = true
	_ensure_overlay(cell)
	return true


func plant(cell: Vector2i, seed_id: String) -> bool:
	_resolve_tile_map()
	if _tile_map == null:
		return false
	if seed_id == "":
		return false
	if not is_tilled(cell):
		return false
	if is_planted(cell):
		return false

	_planted[cell] = seed_id
	_stages[cell] = STAGE_PLANTED
	_ensure_sprout(cell)
	_refresh_sprout(cell)
	return true


func water(cell: Vector2i) -> bool:
	_resolve_tile_map()
	if _tile_map == null:
		return false
	if not is_tilled(cell):
		return false
	if is_watered(cell):
		return false

	_watered[cell] = true
	_refresh_overlay_color(cell)
	_ensure_water_mark(cell)
	return true


func on_new_day() -> void:
	for cell: Vector2i in _planted.keys():
		if not is_watered(cell):
			continue
		var stage := int(_stages.get(cell, STAGE_PLANTED))
		if stage < STAGE_MAX:
			_stages[cell] = stage + 1
			_refresh_sprout(cell)

	_clear_all_water()


func _on_date_changed(_day: int, _season: int, _year: int) -> void:
	on_new_day()


func _clear_all_water() -> void:
	var wet_cells: Array = _watered.keys()
	_watered.clear()
	for cell: Vector2i in wet_cells:
		if _water_marks.has(cell):
			var mark := _water_marks[cell] as Polygon2D
			if is_instance_valid(mark):
				mark.queue_free()
			_water_marks.erase(cell)
		_refresh_overlay_color(cell)


func _resolve_tile_map() -> void:
	var map := get_tree().get_first_node_in_group("farm_tilemap") as TileMap
	if map == null:
		return
	if (
		map == _tile_map
		and is_instance_valid(_overlay_root)
		and is_instance_valid(_sprout_root)
		and is_instance_valid(_water_root)
	):
		return

	_tile_map = map
	_rebuild_overlay_root()


func _rebuild_overlay_root() -> void:
	if is_instance_valid(_overlay_root):
		_overlay_root.queue_free()
	if is_instance_valid(_sprout_root):
		_sprout_root.queue_free()
	if is_instance_valid(_water_root):
		_water_root.queue_free()
	_overlays.clear()
	_sprouts.clear()
	_water_marks.clear()

	_overlay_root = Node2D.new()
	_overlay_root.name = "TilledSoilOverlays"
	_overlay_root.z_index = 5
	_tile_map.add_child(_overlay_root)

	_sprout_root = Node2D.new()
	_sprout_root.name = "CropSprouts"
	_sprout_root.z_index = 6
	_tile_map.add_child(_sprout_root)

	_water_root = Node2D.new()
	_water_root.name = "WaterMarks"
	_water_root.z_index = 7
	_tile_map.add_child(_water_root)

	for cell: Vector2i in _tilled.keys():
		_ensure_overlay(cell)
	for cell: Vector2i in _planted.keys():
		_ensure_sprout(cell)
		_refresh_sprout(cell)
	for cell: Vector2i in _watered.keys():
		_ensure_water_mark(cell)


func _ensure_overlay(cell: Vector2i) -> void:
	if _overlays.has(cell) or _overlay_root == null or _tile_map == null:
		return

	var tile_size := Vector2(_tile_map.tile_set.tile_size) if _tile_map.tile_set else Vector2(16, 16)
	var center := _tile_map.map_to_local(cell)
	var half := tile_size * 0.5

	var poly := Polygon2D.new()
	poly.color = WATERED_SOIL_COLOR if is_watered(cell) else TILLED_COLOR
	poly.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])
	_overlay_root.add_child(poly)
	_overlays[cell] = poly


func _refresh_overlay_color(cell: Vector2i) -> void:
	if not _overlays.has(cell):
		_ensure_overlay(cell)
		return
	var poly := _overlays[cell] as Polygon2D
	if poly != null:
		poly.color = WATERED_SOIL_COLOR if is_watered(cell) else TILLED_COLOR


func _ensure_sprout(cell: Vector2i) -> void:
	if _sprouts.has(cell) or _sprout_root == null or _tile_map == null:
		return

	var center := _tile_map.map_to_local(cell)
	var root := Node2D.new()
	root.position = center
	_sprout_root.add_child(root)

	var poly := Polygon2D.new()
	poly.name = "Sprout"
	poly.color = SPROUT_COLOR
	poly.polygon = PackedVector2Array([
		Vector2(0, -4),
		Vector2(3, 0),
		Vector2(0, 4),
		Vector2(-3, 0),
	])
	root.add_child(poly)

	var label := Label.new()
	label.name = "StageLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-8, -18)
	label.size = Vector2(16, 12)
	root.add_child(label)

	_sprouts[cell] = root


func _refresh_sprout(cell: Vector2i) -> void:
	if not _sprouts.has(cell):
		_ensure_sprout(cell)
	var root := _sprouts.get(cell) as Node2D
	if root == null:
		return

	var stage := int(_stages.get(cell, STAGE_PLANTED))
	var poly := root.get_node_or_null("Sprout") as Polygon2D
	if poly != null:
		poly.scale = Vector2.ONE * (1.0 + stage * 0.25)

	var label := root.get_node_or_null("StageLabel") as Label
	if label != null:
		label.text = str(stage)


func _ensure_water_mark(cell: Vector2i) -> void:
	if _water_marks.has(cell) or _water_root == null or _tile_map == null:
		return

	var center := _tile_map.map_to_local(cell)
	var poly := Polygon2D.new()
	poly.color = WATER_DROP_COLOR
	poly.polygon = PackedVector2Array([
		center + Vector2(4, -5),
		center + Vector2(6, -2),
		center + Vector2(4, 0),
		center + Vector2(2, -2),
	])
	_water_root.add_child(poly)
	_water_marks[cell] = poly
