extends Node

## AUTOLOAD (singleton) — load order #1, see project.godot [autoload].
##
## Owns the active location name and scene travel (pending spawn id).
## location_info.gd announces the name; map exits call travel().

signal location_changed(location_name: String)

var current_location_name: String = ""
## Set by travel(), consumed once by the arriving location's spawn points.
var pending_spawn_id: String = ""
var _traveling: bool = false


func set_location(location_name: String) -> void:
	# De-duplicated on purpose: re-entering the same location (e.g. a scene
	# reload) should not spam location_changed or cause the HUD to flicker.
	if current_location_name == location_name:
		return
	current_location_name = location_name
	location_changed.emit(location_name)


## Deferred scene change. Inventory, time, flags, and soil stay in autoloads.
## City maps must not use the farm_tilemap group.
func travel(scene_path: String, spawn_id: String) -> void:
	if _traveling or scene_path.is_empty():
		return
	if GameTime.paused:
		return
	_traveling = true
	pending_spawn_id = spawn_id
	get_tree().change_scene_to_file.call_deferred(scene_path)


func consume_spawn_id() -> String:
	var spawn_id := pending_spawn_id
	pending_spawn_id = ""
	_traveling = false
	return spawn_id
