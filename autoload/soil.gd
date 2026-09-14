extends Node

## AUTOLOAD (singleton) — load order #4, see project.godot [autoload].
##
## Owns ALL farming-tile gameplay state: which cells are tilled, watered,
## planted, and what growth stage each planted cell is at. This is the
## authoritative half of the "logic/visual separation" rule described in
## `.cursor/rules/logic-visual-separation.mdc` and GAME_SYSTEMS_SUMMARY.md —
## Soil decides what is true about the farm; everything visual (overlays,
## water drops, the crop's own scale/label) is just a rendering of that
## truth and gets rebuilt from it, never the other way around.
##
## Today Soil ALSO builds its own placeholder visuals directly (tilled-soil
## and water-drop Polygon2Ds) rather than delegating to a separate visual
## helper. That is called out as a known cleanup target in
## GAME_SYSTEMS_SUMMARY.md section 23 ("Needs a cleanup adapter before final
## art") — keep new visual code isolated in the _ensure_*/_refresh_* helpers
## below so it stays easy to peel out later.
##
## Cell coordinates (Vector2i) all key off the single TileMap found via the
## "farm_tilemap" group (see _resolve_tile_map()). There is no location ID
## in these dictionaries — see the persistence limitations note near the
## bottom of this file, and GAME_SYSTEMS_SUMMARY.md section 26 risk #1.
##
## Who talks to this script:
##   - `player/tool_use.gd` calls till()/water()/plant() in response to
##     left-click, using the cell from `farming/tile_targeter.gd`.
##   - `interactables/crop/crop_plant.gd` (the world object spawned by
##     _ensure_crop_plant() below) calls is_harvestable()/get_stage()/
##     get_crop() to draw itself, and calls harvest() on right-click.
##   - `autoload/game_time.gd`'s date_changed signal drives on_new_day():
##     every planted+watered cell grows one stage, then ALL watering is
##     cleared. This runs identically whether the date advanced via natural
##     midnight or via `interactables/bed/bed.gd`'s sleep_to_next_morning().
##   - `locations/seasonal_farm_tiles.gd` swaps the TileMap's *painted tile
##     art* per season but does not touch anything in this file — tilled
##     cells, crops, and stages all survive a season change untouched,
##     which is the whole point of keeping this state in an autoload
##     instead of on the scene.

## Preloading crop_data.gd this way (rather than `class_name Crop`) mirrors
## how the file is documented, and avoids a global class name collision with
## other Resource scripts.
const Crop := preload("res://farming/crop_data.gd")
const CropPlantScene := preload("res://interactables/crop/crop_plant.tscn")

const TILLED_COLOR := Color(0.36, 0.22, 0.12, 0.85)
const WATERED_SOIL_COLOR := Color(0.22, 0.28, 0.45, 0.9)
const WATER_DROP_COLOR := Color(0.4, 0.7, 1.0, 0.95)

const STAGE_PLANTED := 0

# ---- Authoritative gameplay state (the "truth") ----------------------------
var _tilled: Dictionary = {}  # Vector2i -> true
var _planted: Dictionary = {} # Vector2i -> String (crop id, see crop_data.gd)
var _watered: Dictionary = {} # Vector2i -> true
var _stages: Dictionary = {}  # Vector2i -> int (0 = just planted)

# ---- Runtime visual caches (derived from the state above, rebuildable) -----
var _overlays: Dictionary = {}     # Vector2i -> tilled-soil Polygon2D
var _crop_plants: Dictionary = {}  # Vector2i -> crop_plant.tscn instance (Area2D)
var _water_marks: Dictionary = {}  # Vector2i -> water-drop Polygon2D

var _tile_map: TileMap
var _overlay_root: Node2D
var _crop_root: Node2D
var _water_root: Node2D


func _ready() -> void:
	# The one and only trigger for daily crop growth / water reset.
	GameTime.date_changed.connect(_on_date_changed)


func _process(_delta: float) -> void:
	# Cheap self-healing: if the active TileMap instance changes (e.g. scene
	# reload) or the visual root nodes were freed, re-resolve on the next
	# frame rather than requiring every caller to check for that.
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


## Returns a fresh CropData Resource for whatever is planted at `cell`, or
## null if nothing is planted. Note this allocates a new Resource each call
## (see crop_data.gd's from_id()) — fine at this scale, called out in
## GAME_SYSTEMS_SUMMARY.md as a spot to optimize later if crop lookups
## become hot.
func get_crop(cell: Vector2i):
	if not is_planted(cell):
		return null
	return Crop.from_id(str(_planted[cell]))


## True once a planted cell has reached its crop's mature_stage. This is
## exactly what crop_plant.gd's can_interact() checks before allowing a
## right-click harvest.
func is_harvestable(cell: Vector2i) -> bool:
	var crop = get_crop(cell)
	if crop == null:
		return false
	return get_stage(cell) >= crop.mature_stage


## Called by player/tool_use.gd when the Hoe is selected and the player
## left-clicks a targeted cell. Requires an actual ground tile under the
## cell (so clicking off the map or off the painted TileMap does nothing)
## and that the cell isn't already tilled. Does NOT check for crops,
## furniture, season, or player overlap — see GAME_SYSTEMS_SUMMARY.md
## section 11 for the full list of things tilling intentionally ignores
## right now.
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


## Called by tool_use.gd when a seed is selected. Requires tilled, unplanted
## soil and a seed ID that crop_data.gd recognizes (from_seed()). On success,
## plants at STAGE_PLANTED (0) and spawns the crop_plant.tscn world object
## via _ensure_crop_plant(). tool_use.gd only removes the seed from the
## hotslot AFTER this returns true, so a failed plant never costs a seed.
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
	var crop = Crop.from_seed(seed_id)
	if crop == null:
		return false

	_planted[cell] = crop.id
	_stages[cell] = STAGE_PLANTED
	_ensure_crop_plant(cell)
	_refresh_crop_plant(cell)
	return true


## Called by tool_use.gd when the Watering Can is selected. Any tilled,
## dry cell can be watered, INCLUDING tilled soil with nothing planted on
## it (watering does not require a crop to be present).
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


## Called by crop_plant.gd's interact() on right-click. Harvesting is
## transactional: Inventory.try_add_item() must succeed FIRST (i.e. there
## must be room for the produce) before any plant state is changed, so a
## full inventory simply leaves the mature crop standing, still harvestable,
## instead of silently discarding the produce.
##
## SINGLE_HARVEST crops (Rice) are removed entirely afterward — the tile
## stays tilled but needs a brand-new seed. REGROWABLE crops (Beans) instead
## reset to regrow_stage and keep growing from there indefinitely, so the
## same crop_plant instance stays on the map through the whole loop.
func harvest(cell: Vector2i) -> bool:
	var crop = get_crop(cell)
	if crop == null or not is_harvestable(cell):
		return false
	if not Inventory.try_add_item(crop.harvest_item_id, 1):
		return false

	if crop.harvest_type == Crop.HarvestType.SINGLE_HARVEST:
		_remove_crop(cell)
	else:
		_stages[cell] = crop.regrow_stage
		_refresh_crop_plant(cell)
	return true


## The daily tick: everything that should happen exactly once per in-game
## day, driven by GameTime.date_changed (see _on_date_changed below). Grows
## every watered+planted cell by one stage (capped at mature_stage — mature
## crops just stay mature rather than overflowing), refreshes each crop's
## visual to match, then dries out ALL watered soil for the new day. Missing
## a watering simply pauses growth for that cell; it never kills the plant.
func on_new_day() -> void:
	for cell: Vector2i in _planted.keys():
		if not is_watered(cell):
			continue
		var crop = get_crop(cell)
		if crop == null:
			continue
		var stage := int(_stages.get(cell, STAGE_PLANTED))
		if stage < crop.mature_stage:
			_stages[cell] = stage + 1
			_refresh_crop_plant(cell)

	_clear_all_water()


## GameTime fires date_changed both at natural midnight AND after
## sleep_to_next_morning() — either way this runs once per calendar day,
## which is exactly the "once per day" contract on_new_day() is written for.
func _on_date_changed(_day: int, _season: int, _year: int) -> void:
	on_new_day()


func _remove_crop(cell: Vector2i) -> void:
	_planted.erase(cell)
	_stages.erase(cell)
	if _crop_plants.has(cell):
		var plant := _crop_plants[cell] as Node
		if is_instance_valid(plant):
			plant.queue_free()
		_crop_plants.erase(cell)


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


## Locates the live TileMap (the one in the "farm_tilemap" group — see
## MainFarmSpring.tscn) and, if it's a NEW map instance or the visual roots
## went stale, rebuilds the visual root nodes under it. This is what lets
## Soil survive scene reloads without every till()/plant()/water() caller
## having to worry about node lifetime.
func _resolve_tile_map() -> void:
	var map := get_tree().get_first_node_in_group("farm_tilemap") as TileMap
	if map == null:
		return
	if (
		map == _tile_map
		and is_instance_valid(_overlay_root)
		and is_instance_valid(_crop_root)
		and is_instance_valid(_water_root)
	):
		return

	_tile_map = map
	_rebuild_overlay_root()


## Recreates the three Node2D "layers" that hold Soil's runtime visuals
## (see z-index constants in the node names below, which match the
## "Render and UI Layers" table in GAME_SYSTEMS_SUMMARY.md section 21), then
## replays every already-known tilled/planted/watered cell into the fresh
## roots. This is why swapping the TileMap (or reloading the scene) doesn't
## lose any visible farm progress — the underlying dictionaries never
## changed, only their on-screen representation was rebuilt.
func _rebuild_overlay_root() -> void:
	if is_instance_valid(_overlay_root):
		_overlay_root.queue_free()
	if is_instance_valid(_crop_root):
		_crop_root.queue_free()
	if is_instance_valid(_water_root):
		_water_root.queue_free()
	_overlays.clear()
	_crop_plants.clear()
	_water_marks.clear()

	_overlay_root = Node2D.new()
	_overlay_root.name = "TilledSoilOverlays"
	_overlay_root.z_index = 5
	_tile_map.add_child(_overlay_root)

	_crop_root = Node2D.new()
	_crop_root.name = "CropPlants"
	_crop_root.z_index = 6
	_tile_map.add_child(_crop_root)

	_water_root = Node2D.new()
	_water_root.name = "WaterMarks"
	_water_root.z_index = 7
	_tile_map.add_child(_water_root)

	for cell: Vector2i in _tilled.keys():
		_ensure_overlay(cell)
	for cell: Vector2i in _planted.keys():
		_ensure_crop_plant(cell)
		_refresh_crop_plant(cell)
	for cell: Vector2i in _watered.keys():
		_ensure_water_mark(cell)


## Procedurally draws a full-tile placeholder rectangle for tilled soil
## (brown when dry, blue-gray when watered — see _refresh_overlay_color).
## This is exactly the kind of hardcoded Polygon2D construction flagged in
## GAME_SYSTEMS_SUMMARY.md section 23 as needing a "SoilVisual" adapter
## before final art — swap this function's body, not its callers, when
## that happens.
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


## Instantiates interactables/crop/crop_plant.tscn at the cell's world
## position and calls its setup(cell) so the crop object knows which soil
## cell it represents. The crop scene owns NO gameplay state itself — see
## crop_plant.gd — it always re-reads stage/crop data from Soil (this file)
## via refresh_visual().
func _ensure_crop_plant(cell: Vector2i) -> void:
	if _crop_plants.has(cell) or _crop_root == null or _tile_map == null:
		return

	var plant := CropPlantScene.instantiate()
	plant.position = _tile_map.map_to_local(cell)
	_crop_root.add_child(plant)
	plant.setup(cell)
	_crop_plants[cell] = plant


func _refresh_crop_plant(cell: Vector2i) -> void:
	if not _crop_plants.has(cell):
		_ensure_crop_plant(cell)
	var plant = _crop_plants.get(cell)
	if plant == null or not is_instance_valid(plant):
		return
	if plant.has_method("refresh_visual"):
		plant.refresh_visual()


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

# ---- Persistence limitation (see GAME_SYSTEMS_SUMMARY.md section 11 & 26) --
# All of the dictionaries above are memory-only and keyed purely by
# Vector2i cell coordinate, with no location/map identity attached. There is
# currently only one farm map, so this is invisible in practice, but adding
# a second location with overlapping tile coordinates would make that
# location inherit this one's tilled/planted/watered state. Any future
# save/load or multi-location system needs to namespace these keys by
# location first.
