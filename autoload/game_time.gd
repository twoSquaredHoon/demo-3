extends Node

## Advances one in-game minute per real second.
## Calendar: 28 days × 4 seasons (Spring → Summer → Fall → Winter) per year.

signal time_changed(hour: int, minute: int)
signal date_changed(day: int, season: int, year: int)
signal season_changed(season: int, year: int)
signal year_changed(year: int)

enum Season { SPRING, SUMMER, FALL, WINTER }

const REAL_SECONDS_PER_GAME_MINUTE := 1.0
const DAYS_PER_SEASON := 28
const SEASON_NAMES := ["Spring", "Summer", "Fall", "Winter"]

var year: int = 1
var season: int = Season.SPRING
var day: int = 1
var hour: int = 6
var minute: int = 0
var paused: bool = false

var _accumulator: float = 0.0


func _ready() -> void:
	time_changed.emit(hour, minute)
	date_changed.emit(day, season, year)


func _process(delta: float) -> void:
	if paused:
		return
	_accumulator += delta
	while _accumulator >= REAL_SECONDS_PER_GAME_MINUTE:
		_accumulator -= REAL_SECONDS_PER_GAME_MINUTE
		_advance_minute()


func season_name() -> String:
	return SEASON_NAMES[season]


func format_clock() -> String:
	return "%02d:%02d" % [hour, minute]


func format_date() -> String:
	return "%s %d, Year %d" % [season_name(), day, year]


func sleep_to_next_morning(wake_hour: int = 6) -> void:
	_accumulator = 0.0
	_advance_day()
	hour = clampi(wake_hour, 0, 23)
	minute = 0
	time_changed.emit(hour, minute)


func _advance_minute() -> void:
	minute += 1
	if minute >= 60:
		minute = 0
		hour += 1
		if hour >= 24:
			hour = 0
			_advance_day()
	time_changed.emit(hour, minute)


func _advance_day() -> void:
	day += 1
	if day > DAYS_PER_SEASON:
		day = 1
		season += 1
		if season > Season.WINTER:
			season = Season.SPRING
			year += 1
			year_changed.emit(year)
		season_changed.emit(season, year)
	date_changed.emit(day, season, year)
