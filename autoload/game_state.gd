extends Node

## AUTOLOAD (singleton) — load order #1, see project.godot [autoload].
##
## Smallest autoload in the project: it owns exactly one piece of state, the
## human-readable name of whatever farm/location scene is currently active.
## It has no opinion about *what* a location is (indoor/outdoor, farm data,
## etc.) — it is just a shared mailbox so any scene can announce "I am now
## the active location" and any UI can listen for that announcement.
##
## Producer:
##   - `locations/location_info.gd` calls set_location() once from its own
##     _ready(), using its exported display_name (e.g. "Spring Farm").
##     That script is attached to the root node of MainFarmSpring.tscn.
##
## Consumer:
##   - `ui/location_hud.gd` connects to location_changed and shows the name
##     in the top-right HUD label.
##
## This is the simplest example in the codebase of the project's core rule:
## gameplay/world state lives in an autoload, and visual/UI nodes only read
## it and react to its signals — they never own it themselves.

signal location_changed(location_name: String)

var current_location_name: String = ""


func set_location(location_name: String) -> void:
	# De-duplicated on purpose: re-entering the same location (e.g. a scene
	# reload) should not spam location_changed or cause the HUD to flicker.
	if current_location_name == location_name:
		return
	current_location_name = location_name
	location_changed.emit(location_name)
