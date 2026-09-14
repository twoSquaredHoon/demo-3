extends CanvasLayer

## Autoload HUD (layer 12). Renders the current Dialogue line/choices.

@onready var root: Control = %DialogueRoot
@onready var speaker_label: Label = %SpeakerLabel
@onready var line_label: Label = %LineLabel
@onready var choices_box: VBoxContainer = %Choices
@onready var continue_hint: Label = %ContinueHint
@onready var panel: PanelContainer = %Panel


func _ready() -> void:
	layer = 12
	root.visible = false
	_style_panel()
	root.gui_input.connect(_on_root_gui_input)
	Dialogue.conversation_started.connect(_on_started)
	Dialogue.line_changed.connect(_on_line_changed)
	Dialogue.choices_changed.connect(_on_choices_changed)
	Dialogue.conversation_ended.connect(_on_ended)


func _input(event: InputEvent) -> void:
	if not Dialogue.is_open:
		return
	if Dialogue.waiting_for_choice:
		return
	if event.is_action_pressed("ui_accept"):
		Dialogue.advance()
		get_viewport().set_input_as_handled()


func _on_root_gui_input(event: InputEvent) -> void:
	if not Dialogue.is_open or Dialogue.waiting_for_choice:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Dialogue.advance()
		get_viewport().set_input_as_handled()


func _on_started(_npc_id: String) -> void:
	root.visible = true


func _on_ended() -> void:
	root.visible = false
	_clear_choices()
	speaker_label.text = ""
	line_label.text = ""


func _on_line_changed(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	line_label.text = text


func _on_choices_changed(choices: Array) -> void:
	_clear_choices()
	var has_choices := not choices.is_empty()
	continue_hint.visible = not has_choices
	if not has_choices:
		return
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = str(choice.get("text", ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_choice_pressed.bind(i))
		choices_box.add_child(button)


func _on_choice_pressed(index: int) -> void:
	Dialogue.choose(index)


func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()


func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.96)
	style.border_color = Color(0.65, 0.65, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
