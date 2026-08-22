extends Node

## Sibling of the live TileMap inside MainFarmSpring.tscn (see @onready
## tile_map below: `$"../TileMap"`). Makes the single always-loaded farm
## scene visually change with the seasons WITHOUT ever destroying or
## reloading the scene — which is exactly why player position, Soil's
## tilled/watered/planted state, and every spawned crop survive a season
## change untouched (they simply aren't touched by anything this script does).
##
## How it works, at a glance:
##   1. On _ready(), snapshot the TileMap's OWN current cells as the Spring
##      layer data (the live scene starts out painted as Spring already).
##   2. For Summer/Fall/Winter, temporarily instantiate that season's
##      template scene (MainFarmSummer.tscn / MainFarmFall.tscn /
##      MainFarmWinter.tscn — see SEASON_SCENES below), read every used
##      cell off ITS TileMap, then immediately free the temporary scene.
##      Those templates contain nothing but tile data — no player, no bed,
##      no scripts (see GAME_SYSTEMS_SUMMARY.md section 6) — they exist
##      purely to be raided for cell data once at startup.
##   3. Listen for `GameTime.season_changed` and, whenever it fires, clear
##      and repaint the live TileMap's layers from the cached snapshot for
##      the new season.
##
## This depends on all four farm scenes agreeing on: the same TileSet
## numeric source IDs (Fall=0, Spring=1, Summer=2, Winter=3 — see
## GAME_SYSTEMS_SUMMARY.md section 6) and the same number/order of TileMap
## layers. If a future scene edit breaks that parity, cells will render
## with the wrong seasonal art or silently fail to apply — there is no
## validation of source-ID equality here beyond the push_error() calls
## below for missing nodes/templates.

const SEASON_SCENES := {
	GameTime.Season.SUMMER: "res://MainFarmSummer.tscn",
	GameTime.Season.FALL: "res://MainFarmFall.tscn",
	GameTime.Season.WINTER: "res://MainFarmWinter.tscn",
}

@onready var tile_map: TileMap = $"../TileMap"

## season (int, from GameTime.Season) -> Array of per-layer cell-data arrays.
## Populated once at _ready() and never touched again — season switching
## only ever READS from here, it never re-snapshots.
var _season_layers: Dictionary = {}


func _ready() -> void:
	# Spring is special: it's read directly off the live TileMap (which
	# starts out already painted as Spring in MainFarmSpring.tscn) rather
	# than from a separate MainFarmSpring-only template.
	_season_layers[GameTime.Season.SPRING] = _snapshot_layers(tile_map)
	for season: int in SEASON_SCENES:
		_load_season_template(season, SEASON_SCENES[season])

	GameTime.season_changed.connect(_on_season_changed)
	# Re-apply the CURRENT season immediately, in case Spring wasn't already
	# perfectly matching the cached snapshot, and to make startup behavior
	# consistent regardless of which season the game happens to begin in.
	_apply_season(GameTime.season)


## Instantiates a seasonal template scene just long enough to copy its
## TileMap's cells into _season_layers, then frees the temporary instance.
## Nothing from the template (its root, its TileMap node) survives past
## this function — only the plain cell-data Dictionaries do.
func _load_season_template(season: int, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load seasonal farm template: %s" % scene_path)
		return

	var template_root := packed.instantiate()
	var template_map := template_root.get_node_or_null("TileMap") as TileMap
	if template_map == null:
		push_error("Seasonal farm template has no TileMap: %s" % scene_path)
		template_root.free()
		return

	_season_layers[season] = _snapshot_layers(template_map)
	template_root.free()


## Reads every used cell on every layer of `source_map` into plain data
## (position, source_id, atlas_coords, alternative tile) so it can be
## replayed later onto a DIFFERENT TileMap (the live one) without keeping
## the source TileMap itself alive.
func _snapshot_layers(source_map: TileMap) -> Array:
	var layers: Array = []
	for layer in source_map.get_layers_count():
		var cells: Array = []
		for cell: Vector2i in source_map.get_used_cells(layer):
			cells.append({
				"position": cell,
				"source_id": source_map.get_cell_source_id(layer, cell),
				"atlas_coords": source_map.get_cell_atlas_coords(layer, cell),
				"alternative": source_map.get_cell_alternative_tile(layer, cell),
			})
		layers.append(cells)
	return layers


## Wipes every layer of the LIVE TileMap and repaints it from the cached
## snapshot for `season`. This only touches tile art; it never touches
## Player, Bed, or any Soil/crop state, since none of those live on the
## TileMap's tile layers.
func _apply_season(season: int) -> void:
	if not _season_layers.has(season):
		push_error("No farm tiles registered for season %d" % season)
		return

	var layers: Array = _season_layers[season]
	for layer in tile_map.get_layers_count():
		tile_map.clear_layer(layer)
		if layer >= layers.size():
			continue
		for cell_data: Dictionary in layers[layer]:
			tile_map.set_cell(
				layer,
				cell_data["position"],
				cell_data["source_id"],
				cell_data["atlas_coords"],
				cell_data["alternative"]
			)


## GameTime.season_changed handler — the sole way this script reacts to
## time passing; there is no per-frame polling of the current season.
func _on_season_changed(season: int, _year: int) -> void:
	_apply_season(season)
