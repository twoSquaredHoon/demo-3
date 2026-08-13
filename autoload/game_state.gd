extends Node

signal location_changed(location_name: String)

var current_location_name: String = ""


func set_location(location_name: String) -> void:
	if current_location_name == location_name:
		return
	current_location_name = location_name
	location_changed.emit(location_name)
