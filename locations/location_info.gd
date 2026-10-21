extends Node

## Identity tag on a location scene root. Pushes display_name into GameState
## and, after travel, moves the player to the matching spawn_point.

@export var display_name: String = "Unknown"
## Tint the world by time of day (locations/day_night.gd). Turn off for
## indoor scenes that should stay evenly lit.
@export var day_night_tint: bool = true
## Camera limits for scenes without a farm TileMap (e.g. interiors).
## Leave size at 0 to use the farm TileMap's painted area instead.
@export var camera_bounds: Rect2 = Rect2()

## Tiles the player can't walk on, per tileset image: texture path ->
## atlas coords. Any TileMap in the scene painted with these gets solid
## collision when the scene loads. Add entries here for new blocking tiles.
const BLOCKING_TILES := {
	"res://assets/tiles/ground.png": [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)],  # rock
}

const DayNight := preload("res://locations/day_night.gd")


func _ready() -> void:
	if day_night_tint:
		var tint := CanvasModulate.new()
		tint.name = "DayNight"
		tint.set_script(DayNight)
		add_child(tint)
	_apply_camera_limits()
	_build_tile_collision()
	GameState.set_location(display_name)
	call_deferred("_apply_spawn")


## Keeps the player's Camera2D inside the map. Bounds come from the
## painted area of the scene's farm TileMap (group "farm_tilemap").
func _apply_camera_limits() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var bounds := camera_bounds
	if bounds.size == Vector2.ZERO:
		var map := get_tree().get_first_node_in_group("farm_tilemap") as TileMap
		if map == null:
			var maps := find_children("*", "TileMap", true, false)
			if maps.is_empty():
				return
			map = maps[0] as TileMap
		var used := map.get_used_rect()
		var tile := Vector2(map.tile_set.tile_size)
		var top_left := map.to_global(Vector2(used.position) * tile)
		var bottom_right := map.to_global(Vector2(used.end) * tile)
		bounds = Rect2(top_left, bottom_right - top_left)
	# The HUD (ui/location_hud.gd) turns these bounds into camera limits after
	# every zoom change: a map smaller than the view is centered with empty
	# space around it instead of being zoomed in to fill the screen.
	cam.set_meta("map_bounds", bounds)
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)


func _apply_spawn() -> void:
	var spawn_id := GameState.consume_spawn_id()
	if spawn_id.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for node in get_tree().get_nodes_in_group("spawn_point"):
		if str(node.get("spawn_id")) == spawn_id:
			player.global_position = (node as Node2D).global_position
			var cam := get_viewport().get_camera_2d()
			if cam:
				cam.reset_smoothing()
			return



## One solid 16x16 box per blocking tile (see BLOCKING_TILES), on the same
## physics layer as walls, so the player can't walk onto rock.
func _build_tile_collision() -> void:
	for node in find_children("*", "TileMap", true, false):
		var map := node as TileMap
		if map.tile_set == null:
			continue
		var blocked_sources := {}
		for i in map.tile_set.get_source_count():
			var id := map.tile_set.get_source_id(i)
			var src := map.tile_set.get_source(id) as TileSetAtlasSource
			if src == null or src.texture == null:
				continue
			if BLOCKING_TILES.has(src.texture.resource_path):
				blocked_sources[id] = BLOCKING_TILES[src.texture.resource_path]
		if blocked_sources.is_empty():
			continue
		var body := StaticBody2D.new()
		body.name = "BlockedTiles"
		body.collision_layer = 1
		body.collision_mask = 0
		var tile := Vector2(map.tile_set.tile_size)
		for layer in map.get_layers_count():
			for cell in map.get_used_cells(layer):
				var sid := map.get_cell_source_id(layer, cell)
				if not blocked_sources.has(sid):
					continue
				if not blocked_sources[sid].has(map.get_cell_atlas_coords(layer, cell)):
					continue
				var shape := CollisionShape2D.new()
				var box := RectangleShape2D.new()
				box.size = tile
				shape.shape = box
				shape.position = map.map_to_local(cell)
				body.add_child(shape)
		if body.get_child_count() > 0:
			map.add_child(body)
		else:
			body.free()
