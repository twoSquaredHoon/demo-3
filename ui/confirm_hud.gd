extends CanvasLayer

## AUTOLOAD — ui/confirm_hud.tscn, CanvasLayer 13 (above DialogueHud).
## Generic Yes/No confirmation prompt. Callers await ask() for the result.
## Currently used by the bed for sleep confirmation; selling-box flow is
## intentionally separate and not wired here yet.
##
## While open: pauses GameTime via request_pause("confirm") and other
## systems should check ConfirmHud.is_open before world/UI actions.

const PAUSE_SOURCE := "confirm"

signal answered(accepted: bool)

@onready var root: Control = %ConfirmRoot
@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton
@onready var panel: PanelContainer = %Panel

var is_open: bool = false


func _ready() -> void:
	layer = 13
	root.visible = false
	_style_panel()
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("close_inventory"):
		_finish(false)
		get_viewport().set_input_as_handled()


## Shows a modal Yes/No prompt and returns true only if Yes was chosen.
## Safe to call from interact() without the caller awaiting the result
## themselves — bed uses an async helper for that.
func ask(message: String, title: String = "Confirm") -> bool:
	if is_open:
		return false
	is_open = true
	title_label.text = title
	message_label.text = message
	root.visible = true
	GameTime.request_pause(PAUSE_SOURCE)
	var accepted: bool = await answered
	return accepted


func _on_yes_pressed() -> void:
	_finish(true)


func _on_no_pressed() -> void:
	_finish(false)


func _finish(accepted: bool) -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	GameTime.release_pause(PAUSE_SOURCE)
	answered.emit(accepted)


func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.55, 0.6, 1.0)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_top = 14
	style.content_margin_right = 16
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
