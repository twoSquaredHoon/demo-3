extends CanvasLayer


@onready var location_label: Label = %LocationLabel


func _ready() -> void:
	GameState.location_changed.connect(_on_location_changed)
	if not GameState.current_location_name.is_empty():
		_on_location_changed(GameState.current_location_name)


func _on_location_changed(location_name: String) -> void:
	location_label.text = location_name
