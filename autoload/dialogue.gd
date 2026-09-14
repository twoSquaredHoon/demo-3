extends Node

## Autoload. Owns conversation flags and the live talk session.
## JSON catalog: dialogue/dialogue_catalog.gd.

const CatalogScript := preload("res://dialogue/dialogue_catalog.gd")
const PAUSE_SOURCE := "dialogue"

signal conversation_started(npc_id: String)
signal line_changed(speaker: String, text: String)
signal choices_changed(choices: Array)
signal conversation_ended

var is_open: bool = false
var current_npc_id: String = ""
var waiting_for_choice: bool = false

var _catalog = CatalogScript.new()
var _flags: Dictionary = {}
var _node_id: String = ""
var _line_index: int = 0
var _lines: Array[Dictionary] = []
var _choices: Array[Dictionary] = []


func _ready() -> void:
	_catalog.load_all()


func has_npc(npc_id: String) -> bool:
	return _catalog.has_npc(npc_id)


func npc_display_name(npc_id: String) -> String:
	return _catalog.display_name(npc_id)


func npc_color(npc_id: String) -> Color:
	return _catalog.npc_color(npc_id)


func has_flag(flag: String) -> bool:
	return bool(_flags.get(flag, false))


func can_start(npc_id: String) -> bool:
	if is_open or GameTime.paused:
		return false
	if not _catalog.has_npc(npc_id):
		return false
	var entry_id := _catalog.pick_entry(npc_id, _flags)
	if entry_id.is_empty():
		return false
	return not _catalog.get_node(npc_id, entry_id).is_empty()


func start(npc_id: String) -> bool:
	if not can_start(npc_id):
		return false
	var entry_id := _catalog.pick_entry(npc_id, _flags)
	is_open = true
	current_npc_id = npc_id
	waiting_for_choice = false
	GameTime.request_pause(PAUSE_SOURCE)
	conversation_started.emit(npc_id)
	_enter_node(entry_id)
	return true


func advance() -> void:
	if not is_open or waiting_for_choice:
		return
	if _line_index + 1 < _lines.size():
		_line_index += 1
		_emit_current_line()
		return
	_finish_current_node()


func choose(index: int) -> void:
	if not is_open or not waiting_for_choice:
		return
	if index < 0 or index >= _choices.size():
		return
	var goto_id := str(_choices[index].get("goto", ""))
	_apply_node_flags()
	waiting_for_choice = false
	choices_changed.emit([])
	_enter_node(goto_id)


func _enter_node(node_id: String) -> void:
	var node := _catalog.get_node(current_npc_id, node_id)
	if node.is_empty():
		push_error("Dialogue: missing node '%s' on '%s'" % [node_id, current_npc_id])
		_end_conversation()
		return
	_node_id = node_id
	_lines = _normalize_lines(node.get("lines", []))
	_choices = _normalize_choices(node.get("choices", []))
	_line_index = 0
	waiting_for_choice = false
	if _lines.is_empty():
		_finish_current_node()
		return
	_emit_current_line()


func _finish_current_node() -> void:
	if not _choices.is_empty():
		waiting_for_choice = true
		choices_changed.emit(_choices.duplicate(true))
		return
	_apply_node_flags()
	_end_conversation()


func _emit_current_line() -> void:
	var line: Dictionary = _lines[_line_index]
	line_changed.emit(str(line.get("speaker", "")), str(line.get("text", "")))
	if _line_index >= _lines.size() - 1 and not _choices.is_empty():
		waiting_for_choice = true
		choices_changed.emit(_choices.duplicate(true))
	else:
		choices_changed.emit([])


func _apply_node_flags() -> void:
	var node := _catalog.get_node(current_npc_id, _node_id)
	var flags = node.get("set_flags", [])
	if typeof(flags) != TYPE_ARRAY:
		return
	for flag in flags:
		var key := str(flag)
		if key.is_empty():
			continue
		_flags[key] = true


func _end_conversation() -> void:
	is_open = false
	waiting_for_choice = false
	current_npc_id = ""
	_node_id = ""
	_line_index = 0
	_lines.clear()
	_choices.clear()
	GameTime.release_pause(PAUSE_SOURCE)
	choices_changed.emit([])
	conversation_ended.emit()


func _normalize_lines(raw) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	var default_speaker := npc_display_name(current_npc_id)
	for item in raw:
		if item is String:
			result.append({"speaker": default_speaker, "text": str(item)})
		elif item is Dictionary:
			var speaker := str(item.get("speaker", default_speaker))
			if speaker.is_empty():
				speaker = default_speaker
			result.append({"speaker": speaker, "text": str(item.get("text", ""))})
	return result


func _normalize_choices(raw) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		result.append({
			"text": str(item.get("text", "")),
			"goto": str(item.get("goto", "")),
		})
	return result
