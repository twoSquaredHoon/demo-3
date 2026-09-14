extends CanvasLayer

## AUTOLOAD (singleton) — load order #5, see project.godot [autoload].
## Root script of ui/location_hud.tscn, a persistent top-right CanvasLayer
## (layer 10, one below InventoryHud's layer 11) showing the current
## location name, in-game date, and 24-hour clock — plus a camera-zoom
## control (see the "CAMERA ZOOM" section below).
##
## This HUD is pure display: it never mutates GameState/GameTime/Wallet, it
## only subscribes to their signals and re-renders text. Data flow in:
##   - `GameState.location_changed` -> location_label.
##   - `GameTime.date_changed` -> date_label (via GameTime.format_date()).
##   - `GameTime.time_changed` -> time_label (via GameTime.format_clock()).
##   - `Wallet.balance_changed` -> gold_label.
##   - `Wallet.pending_changed` -> pending_label (hidden while pending is 0 —
##     see autoload/wallet.gd for why a sale doesn't reach balance same-day).
##
## KNOWN ISSUE (see GAME_SYSTEMS_SUMMARY.md section 7): this Control's
## labels/buttons use default mouse filtering, so this top-right rectangle
## can consume clicks that would otherwise reach the world underneath it
## (e.g. a farm tile visually behind the HUD).
##
## --- CAMERA ZOOM --------------------------------------------------------
## This section (ZoomRow / ZoomOutButton / ZoomLabel / ZoomInButton in
## ui/location_hud.tscn, and everything below _resolve_camera()) is NOT yet
## described in GAME_SYSTEMS_SUMMARY.md as of its last audit (2026-08-14) —
## it was added after that audit. Documenting it here so the gap is visible
## next to the code itself:
##   - Lets the player zoom the world view out/in in 10% steps between 60%
##     and 120% of the player Camera2D's original zoom (player.tscn sets
##     that base zoom to 3x — so the effective range is roughly 1.8x-3.6x).
##   - This is the one place in the project where a HUD script reaches
##     directly into a WORLD node (`get_viewport().get_camera_2d()`) rather
##     than only listening to autoload signals — a deliberate but notable
##     exception to the "HUD only renders autoload state" pattern used
##     everywhere else in this file and in ui/inventory_hud.gd.
##   - Zoom state (`zoom_percent`) lives only on this HUD node, not in any
##     autoload, so it is not shared with any other system and does not
##     persist across a scene reload.

@onready var location_label: Label = %LocationLabel
@onready var date_label: Label = %DateLabel
@onready var time_label: Label = %TimeLabel
@onready var gold_label: Label = %GoldLabel
@onready var pending_label: Label = %PendingLabel
@onready var zoom_label: Label = %ZoomLabel
@onready var zoom_out_button: Button = %ZoomOutButton
@onready var zoom_in_button: Button = %ZoomInButton

const ZOOM_MIN := 60
const ZOOM_MAX := 120
const ZOOM_STEP := 10

var zoom_percent: int = 100
var _camera: Camera2D
## The Camera2D's zoom at the moment it was first found (player.tscn's
## Camera2D starts at Vector2(3, 3)). Zoom percent is applied as a
## multiplier of THIS value, not of a hardcoded absolute, so this script
## doesn't need to know the base zoom in advance.
var _base_camera_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	GameState.location_changed.connect(_on_location_changed)
	GameTime.time_changed.connect(_on_time_changed)
	GameTime.date_changed.connect(_on_date_changed)
	Wallet.balance_changed.connect(_on_balance_changed)
	Wallet.pending_changed.connect(_on_pending_changed)
	# Seed the labels immediately from whatever GameState/GameTime/Wallet
	# already hold, so the HUD is correct even before the next signal fires
	# (this HUD autoload can load/ready after those emit their initial state).
	if not GameState.current_location_name.is_empty():
		_on_location_changed(GameState.current_location_name)
	_on_date_changed(GameTime.day, GameTime.season, GameTime.year)
	_on_time_changed(GameTime.hour, GameTime.minute)
	_on_balance_changed(Wallet.balance)
	_on_pending_changed(Wallet.pending)

	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	_update_zoom_label()
	_update_zoom_buttons()


func _on_location_changed(location_name: String) -> void:
	location_label.text = location_name


func _on_date_changed(_day: int, _season: int, _year: int) -> void:
	date_label.text = GameTime.format_date()


func _on_time_changed(_hour: int, _minute: int) -> void:
	time_label.text = GameTime.format_clock()


func _on_balance_changed(new_balance: int) -> void:
	gold_label.text = "%dg" % new_balance


func _on_pending_changed(new_pending: int) -> void:
	pending_label.visible = new_pending > 0
	pending_label.text = "+%dg today" % new_pending


func _on_zoom_out_pressed() -> void:
	_set_zoom_percent(zoom_percent - ZOOM_STEP)


func _on_zoom_in_pressed() -> void:
	_set_zoom_percent(zoom_percent + ZOOM_STEP)


func _set_zoom_percent(value: int) -> void:
	zoom_percent = clampi(value, ZOOM_MIN, ZOOM_MAX)
	_update_zoom_label()
	_update_zoom_buttons()
	_apply_camera_zoom()


func _update_zoom_label() -> void:
	zoom_label.text = "%d%%" % zoom_percent


func _update_zoom_buttons() -> void:
	zoom_out_button.disabled = zoom_percent <= ZOOM_MIN
	zoom_in_button.disabled = zoom_percent >= ZOOM_MAX


func _apply_camera_zoom() -> void:
	_resolve_camera()
	if _camera == null:
		return
	_camera.zoom = _base_camera_zoom * (float(zoom_percent) / 100.0)


## Finds the viewport's active Camera2D (in practice, the Player's Camera2D
## from player.tscn — there is only one camera in the project) and caches
## its starting zoom the first time it's found, so later zoom_percent
## changes are always relative to that original value rather than
## compounding on top of a previous adjustment.
func _resolve_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	_camera = cam
	_base_camera_zoom = cam.zoom
