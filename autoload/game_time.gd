extends Node

## AUTOLOAD (singleton) — load order #2, see project.godot [autoload].
##
## The game's clock and calendar. This is the single source of truth for
## "what time/day/season/year is it" — nothing else in the project stores a
## copy of the date. Everything downstream (HUD text, crop growth, daily
## water reset) reacts to the signals this script emits rather than polling.
##
## Advances one in-game minute per real second (see REAL_SECONDS_PER_GAME_MINUTE),
## so one full in-game day takes 24 real minutes, one season (28 days) takes
## 11.2 real hours, and one year (4 seasons) takes 44.8 real hours.
##
## Who talks to this script:
##   - `ui/location_hud.gd` listens to time_changed/date_changed to draw the
##     clock/date text, and also reads GameTime.season / GameTime.day /
##     GameTime.year directly at startup to seed its labels.
##   - `autoload/soil.gd` listens to date_changed and re-runs crop growth /
##     clears watering exactly once whenever the date advances, whether that
##     advance came from natural midnight or from sleeping in the bed.
##   - `locations/seasonal_farm_tiles.gd` listens to season_changed to swap
##     which seasonal tileset is painted onto the live TileMap.
##   - `interactables/bed/bed.gd` calls sleep_to_next_morning() on interact,
##     which is the *other* path (besides natural midnight) that can advance
##     the calendar.
##   - `autoload/inventory.gd` writes to GameTime.paused (does not use a
##     signal) whenever the inventory menu opens/closes, freezing time
##     without touching the SceneTree's own pause state.
##
## year_changed is emitted but currently has no listener anywhere in the
## project (see GAME_SYSTEMS_SUMMARY.md, section 25, "Emitted but unused").

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
## Custom pause flag for this autoload only. Setting this does NOT pause the
## SceneTree (so movement/animation elsewhere keeps working); it only stops
## _process() below from ticking the clock forward. Currently the only
## writer is Inventory, while its menu is open.
var paused: bool = false

## Fractional real-time accumulator (in seconds). Frames rarely land exactly
## on a 1-second boundary, so leftover time is kept here instead of being
## discarded, and the while loop in _process() can "catch up" several game
## minutes at once after a slow/hitching frame instead of losing time.
var _accumulator: float = 0.0


func _ready() -> void:
	# Push the initial clock/date once so the HUD (and anything else built
	# after this autoload) has correct values even before the first tick.
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
	# Sleeping is deliberately routed through the SAME _advance_day() path
	# that natural midnight uses, so Soil's daily growth/water-reset logic
	# (which listens to date_changed) runs identically either way — there is
	# no separate "sleep" code path for gameplay state, only for the clock.
	_accumulator = 0.0
	_advance_day()
	hour = clampi(wake_hour, 0, 23)
	minute = 0
	# Only time_changed fires here; _advance_day() already fired date_changed
	# once. Emitting date_changed a second time would make Soil grow crops
	# / reset watering twice for a single night's sleep.
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
		# season_changed is what triggers SeasonalFarmTiles to repaint the
		# TileMap with the new season's ground/foliage layout.
		season_changed.emit(season, year)
	# Always fires exactly once per day advance, regardless of whether the
	# season also rolled over. This is what Soil listens to for crop growth.
	date_changed.emit(day, season, year)
