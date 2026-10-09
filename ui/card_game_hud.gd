extends CanvasLayer

## Autoload HUD (layer 14). Renders CardGame state and sends play/pass.

const CARD_SIZE := Vector2(56, 72)

@onready var root: Control = %Root
@onready var title_label: Label = %TitleLabel
@onready var gem_label: Label = %GemLabel
@onready var log_label: Label = %LogLabel
@onready var opp_score: Label = %OppScore
@onready var player_score: Label = %PlayerScore
@onready var opp_hill: HBoxContainer = %OppHill
@onready var opp_alley: HBoxContainer = %OppAlley
@onready var opp_field: HBoxContainer = %OppField
@onready var player_field: HBoxContainer = %PlayerField
@onready var player_alley: HBoxContainer = %PlayerAlley
@onready var player_hill: HBoxContainer = %PlayerHill
@onready var hand_row: HBoxContainer = %HandRow
@onready var pass_button: Button = %PassButton
@onready var forfeit_button: Button = %ForfeitButton
@onready var result_root: Control = %ResultRoot
@onready var result_label: Label = %ResultLabel
@onready var result_button: Button = %ResultButton
@onready var weather_label: Label = %WeatherLabel
@onready var opp_hand_label: Label = %OppHandLabel


func _ready() -> void:
	layer = 14
	root.visible = false
	result_root.visible = false
	pass_button.pressed.connect(_on_pass)
	forfeit_button.pressed.connect(_on_forfeit)
	result_button.pressed.connect(_on_result_close)
	CardGame.match_started.connect(_on_started)
	CardGame.board_changed.connect(_refresh)
	CardGame.match_ended.connect(_on_ended)


func _unhandled_input(event: InputEvent) -> void:
	if not CardGame.is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("close_inventory"):
		if CardGame.result.is_empty():
			CardGame.forfeit()
		else:
			CardGame.close()
		get_viewport().set_input_as_handled()


func _on_started() -> void:
	root.visible = true
	result_root.visible = false
	_refresh()


func _on_ended(_result: String) -> void:
	_refresh()
	result_root.visible = true
	match _result:
		"win":
			result_label.text = "세줄패, 네가 이겼어."
		"lose":
			result_label.text = "이번엔 내가 이겼지."
		_:
			result_label.text = "비겼네. 다음엔 끝을 보자."


func _on_pass() -> void:
	CardGame.pass_turn()


func _on_forfeit() -> void:
	if CardGame.result.is_empty():
		CardGame.forfeit()
	else:
		CardGame.close()


func _on_result_close() -> void:
	CardGame.close()
	root.visible = false
	result_root.visible = false


func _refresh() -> void:
	if not CardGame.is_open:
		root.visible = false
		result_root.visible = false
		return
	root.visible = true
	title_label.text = "세줄패  ·  %s" % CardGame.opponent_name()
	gem_label.text = "나 %s    상대 %s" % [_gems(CardGame.player_gems), _gems(CardGame.opponent_gems)]
	log_label.text = CardGame.log_line
	opp_score.text = "%s  %d" % [CardGame.opponent_name(), CardGame.total_score("opponent")]
	player_score.text = "나  %d" % CardGame.total_score("player")
	opp_hand_label.text = "상대 손패 %d장" % CardGame.opponent_hand_count()
	weather_label.text = _weather_text()
	_fill_row(opp_hill, "opponent", "hill")
	_fill_row(opp_alley, "opponent", "alley")
	_fill_row(opp_field, "opponent", "field")
	_fill_row(player_field, "player", "field")
	_fill_row(player_alley, "player", "alley")
	_fill_row(player_hill, "player", "hill")
	_fill_hand()
	pass_button.disabled = not CardGame.can_act()
	forfeit_button.disabled = false


func _weather_text() -> String:
	var parts: Array[String] = []
	for row_id in CardGame.row_ids():
		if CardGame.weather_on(row_id):
			parts.append("%s 날씨" % CardGame.row_label(row_id))
	if parts.is_empty():
		return "날씨 없음"
	return " · ".join(parts)


func _gems(count: int) -> String:
	var filled := mini(2, max(count, 0))
	if filled == 2:
		return "●●"
	if filled == 1:
		return "●○"
	return "○○"


func _fill_row(box: HBoxContainer, side: String, row_id: String) -> void:
	_clear(box)
	var score := CardGame.row_score(side, row_id)
	var tag := Label.new()
	tag.custom_minimum_size = Vector2(52, CARD_SIZE.y)
	tag.text = "%s\n%d" % [CardGame.row_label(row_id), score]
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 11)
	if CardGame.weather_on(row_id):
		tag.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	box.add_child(tag)
	for card in CardGame.board_cards(side, row_id):
		box.add_child(_make_card_panel(card, false))


func _fill_hand() -> void:
	_clear(hand_row)
	for card in CardGame.player_hand():
		hand_row.add_child(_make_card_panel(card, true))


func _make_card_panel(card: Dictionary, in_hand: bool) -> Control:
	var wrap := Button.new()
	wrap.custom_minimum_size = CARD_SIZE
	wrap.flat = true
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	var row_id := str(card.get("row", "field"))
	var color := CardGame.row_color(row_id)
	var ability := str(card.get("ability", "none"))
	style.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.95)
	style.border_color = Color(0.95, 0.82, 0.4) if ability == "hero" else color
	if ability == "spy":
		style.border_color = Color(0.75, 0.45, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	wrap.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	var power := Label.new()
	power.text = str(int(card.get("power", 0)))
	if ability == "weather":
		power.text = "날"
	elif ability == "horn":
		power.text = "북"
	elif ability == "spy":
		power.text = "첩"
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power.add_theme_font_size_override("font_size", 16)
	power.add_theme_color_override("font_color", Color(1, 1, 0.85))
	vbox.add_child(power)
	var name := Label.new()
	name.text = str(card.get("name", "?"))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name)
	if in_hand and CardGame.can_act():
		var uid := int(card.get("uid", -1))
		wrap.pressed.connect(_on_hand_pressed.bind(uid))
	else:
		wrap.disabled = true
	return wrap


func _on_hand_pressed(uid: int) -> void:
	CardGame.play_card(uid)


func _clear(box: Node) -> void:
	for child in box.get_children():
		child.queue_free()
