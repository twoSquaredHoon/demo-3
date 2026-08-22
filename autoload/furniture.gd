extends Node

## AUTOLOAD (singleton) — see project.godot [autoload]. Loaded after Soil.
##
## Tracks placed furniture (Bed, Selling Box, ...) as footprints of occupied
## TileMap cells, mirroring autoload/soil.gd's cell-Dictionary +
## lazy-tile-map-resolve pattern. Furniture instances are spawned as
## children of a dedicated Node2D root under the live farm TileMap (see
## _resolve_tile_map()/_rebuild_furniture_root()) — z_index is set ONCE on
## that root only, never also on the spawned scene's own root node, on
## purpose: setting z_index on both a container AND its child stacks
## additively in Godot, which is exactly the bug already hit once with
## CropPlants (see the Obsidian vault's Dev Log/Known Bugs.md #7).
##
## Who talks to this script:
##   - `player/furniture_placer.gd` calls can_place() every frame to color
##     its mouse-following preview, and place() on a validated left-click.
##   - `player/tool_use.gd` routes left-click here (via furniture_placer)
##     instead of the farming dispatch whenever the selected item resolves
##     through farming/furniture_data.gd.

signal furniture_changed

const Furn := preload("res://farming/furniture_data.gd")

var _occupied: Dictionary = {} # Vector2i cell -> String furniture id (owner)
var _placements: Dictionary = {} # Vector2i anchor cell -> Array[Vector2i] occupied cells

var _tile_map: TileMap
var _furniture_root: Node2D


func _process(_delta: float) -> void:
	if _tile_map == null or not is_instance_valid(_tile_map):
		_resolve_tile_map()


## Returns true only if every cell in the footprint (anchored at its
## top-left cell, `anchor_cell`) is a real ground tile and not already
## occupied by other furniture. Ground-layer check mirrors
## autoload/soil.gd's till()/farming/tile_targeter.gd's farmable check.
func can_place(anchor_cell: Vector2i, footprint: Vector2i) -> bool:
	_resolve_tile_map()
	if _tile_map == null:
		return false
	for cell in _footprint_cells(anchor_cell, footprint):
		if _tile_map.get_cell_source_id(0, cell) == -1:
			return false
		if _occupied.has(cell):
			return false
	return true


## Instantiates furniture_data's scene at `anchor_cell` and registers every
## footprint cell as occupied. Caller (player/furniture_placer.gd) is
## responsible for consuming the item from Inventory only after this
## returns true — the same "validate, then apply" order try_add_item()
## uses in autoload/inventory.gd.
func place(item_id: String, anchor_cell: Vector2i) -> bool:
	_resolve_tile_map()
	if _tile_map == null:
		return false
	var data = Furn.from_item(item_id)
	if data == null or data.scene == null:
		return false
	var footprint: Vector2i = data.footprint
	if not can_place(anchor_cell, footprint):
		return false

	var instance: Node2D = data.scene.instantiate()
	instance.position = _tile_map.map_to_local(anchor_cell) + _anchor_offset(footprint)
	_furniture_root.add_child(instance)

	var cells := _footprint_cells(anchor_cell, footprint)
	for cell in cells:
		_occupied[cell] = data.id
	_placements[anchor_cell] = cells

	furniture_changed.emit()
	return true


func _tile_size() -> Vector2:
	if _tile_map != null and _tile_map.tile_set != null:
		return Vector2(_tile_map.tile_set.tile_size)
	return Vector2(16, 16)


## anchor_cell is the footprint's TOP-LEFT cell; furniture scenes are drawn
## centered on their own origin, so offset by half the footprint (minus one
## tile) to land the visual centered over every occupied cell instead of
## just the anchor cell.
func _anchor_offset(footprint: Vector2i) -> Vector2:
	return Vector2(footprint - Vector2i.ONE) * _tile_size() * 0.5


func _footprint_cells(anchor_cell: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in footprint.x:
		for y in footprint.y:
			cells.append(anchor_cell + Vector2i(x, y))
	return cells


func _resolve_tile_map() -> void:
	var map := get_tree().get_first_node_in_group("farm_tilemap") as TileMap
	if map == null:
		return
	if map == _tile_map and is_instance_valid(_furniture_root):
		return
	_tile_map = map
	_rebuild_furniture_root()


func _rebuild_furniture_root() -> void:
	if is_instance_valid(_furniture_root):
		_furniture_root.queue_free()
	_furniture_root = Node2D.new()
	_furniture_root.name = "PlacedFurniture"
	_furniture_root.z_index = 6
	_tile_map.add_child(_furniture_root)
	# NOTE: unlike autoload/soil.gd's overlay/crop/water roots, placements
	# already in _placements are NOT re-instantiated here. Nothing in this
	# project currently swaps out the live TileMap at runtime —
	# locations/seasonal_farm_tiles.gd repaints the same TileMap's cells in
	# place rather than replacing the node — so this path only ever runs
	# once, on first resolve. If that assumption changes, mirror Soil's
	# _rebuild_overlay_root() and re-spawn every entry in _placements here.
