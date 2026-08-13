extends CanvasLayer


@onready var location_label: Label = %LocationLabel
@onready var date_label: Label = %DateLabel
@onready var time_label: Label = %TimeLabel


func _ready() -> void:
	GameState.location_changed.connect(_on_location_changed)
	GameTime.time_changed.connect(_on_time_changed)
	GameTime.date_changed.connect(_on_date_changed)
	if not GameState.current_location_name.is_empty():
		_on_location_changed(GameState.current_location_name)
	_on_date_changed(GameTime.day, GameTime.season, GameTime.year)
	_on_time_changed(GameTime.hour, GameTime.minute)


func _on_location_changed(location_name: String) -> void:
	location_label.text = location_name


func _on_date_changed(_day: int, _season: int, _year: int) -> void:
	date_label.text = GameTime.format_date()


func _on_time_changed(_hour: int, _minute: int) -> void:
	time_label.text = GameTime.format_clock()
