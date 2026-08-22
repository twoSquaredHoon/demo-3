extends Resource

## Static registry of placeable furniture (Bed, Selling Box, ...). Mirrors
## farming/crop_data.gd's static-factory pattern (rice()/beans()/
## from_seed()/from_id()) rather than being data-driven from .tres files —
## same "small known set of hardcoded IDs" trade-off crop_data.gd makes.
##
## Each entry pairs an Inventory item_id with the scene to instantiate when
## placed and its footprint size in TILES (not pixels) — see
## autoload/furniture.gd for how the footprint becomes occupied TileMap
## cells, and player/furniture_placer.gd for the mouse-following preview
## that uses the same footprint to draw its highlight rectangle.

@export var id: String = ""
@export var item_id: String = ""
@export var display_name: String = ""
@export var footprint: Vector2i = Vector2i.ONE
@export var scene: PackedScene = null


static func make(furn_id: String, furn_item_id: String, furn_name: String, size: Vector2i, furn_scene: PackedScene):
	var furn = load("res://farming/furniture_data.gd").new()
	furn.id = furn_id
	furn.item_id = furn_item_id
	furn.display_name = furn_name
	furn.footprint = size
	furn.scene = furn_scene
	return furn


## 16x32 px = 1 tile wide x 2 tiles tall (tile size is 16x16 — see
## GAME_SYSTEMS_SUMMARY.md section 6). Was a fixed instance in
## MainFarmSpring.tscn before this system existed; now spawned dynamically
## by autoload/furniture.gd, so the scene's own collision shapes were
## resized to match this footprint exactly (see interactables/bed/bed.tscn).
static func bed():
	return make(
		"bed",
		"bed",
		"Bed",
		Vector2i(1, 2),
		load("res://interactables/bed/bed.tscn")
	)


## 32x16 px = 2 tiles wide x 1 tile tall.
static func selling_box():
	return make(
		"selling_box",
		"selling_box",
		"Selling Box",
		Vector2i(2, 1),
		load("res://interactables/furniture/selling_box/selling_box.tscn")
	)


static func from_item(item_id: String):
	match item_id:
		"bed":
			return bed()
		"selling_box":
			return selling_box()
		_:
			return null
