extends RefCounted

## Loads and validates res://dialogue/content/*.json.
## Dialogue autoload owns the live session and flags.

const CONTENT_DIR := "res://dialogue/content"
const KNOWN_WHEN_KEYS := ["flag", "flag_not", "season", "hour_from", "hour_to"]
const SEASON_NAMES := ["spring", "summer", "fall", "winter"]

var npcs: Dictionary = {} # npc_id -> Dictionary (parsed file)


func load_all() -> void:
	npcs.clear()
	var dir := DirAccess.open(CONTENT_DIR)
	if dir == null:
		push_error("Dialogue catalog: cannot open %s" % CONTENT_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_file("%s/%s" % [CONTENT_DIR, file_name], file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func has_npc(npc_id: String) -> bool:
	return npcs.has(npc_id)


func npc_data(npc_id: String) -> Dictionary:
	return npcs.get(npc_id, {})


func display_name(npc_id: String) -> String:
	return str(npc_data(npc_id).get("display_name", npc_id))


func npc_color(npc_id: String) -> Color:
	var raw := str(npc_data(npc_id).get("color", "#888888"))
	if raw.begins_with("#"):
		return Color.html(raw)
	return Color(raw)


## Highest-priority matching entry node, else the file's `"start"` id.
func pick_entry(npc_id: String, flags: Dictionary) -> String:
	var data := npc_data(npc_id)
	if data.is_empty():
		return ""
	var nodes: Dictionary = data.get("nodes", {})
	var best_id := ""
	var best_priority := -2147483648
	for node_id in nodes.keys():
		var node: Dictionary = nodes[node_id]
		if not bool(node.get("entry", false)):
			continue
		if not when_matches(node.get("when", {}), flags):
			continue
		var priority := int(node.get("priority", 0))
		if priority > best_priority:
			best_priority = priority
			best_id = str(node_id)
	if best_id.is_empty():
		return str(data.get("start", ""))
	return best_id


func get_node(npc_id: String, node_id: String) -> Dictionary:
	var nodes: Dictionary = npc_data(npc_id).get("nodes", {})
	return nodes.get(node_id, {})


func when_matches(when, flags: Dictionary) -> bool:
	if when == null or not (when is Dictionary):
		return true
	var clause: Dictionary = when
	if clause.is_empty():
		return true

	if clause.has("flag"):
		if not bool(flags.get(str(clause["flag"]), false)):
			return false
	if clause.has("flag_not"):
		if bool(flags.get(str(clause["flag_not"]), false)):
			return false
	if clause.has("season"):
		var wanted := str(clause["season"]).to_lower()
		if GameTime.season_name().to_lower() != wanted:
			return false
	if clause.has("hour_from") or clause.has("hour_to"):
		if not clause.has("hour_from") or not clause.has("hour_to"):
			return false
		if not _hour_in_range(GameTime.hour, int(clause["hour_from"]), int(clause["hour_to"])):
			return false
	return true


func _hour_in_range(hour: int, from_h: int, to_h: int) -> bool:
	if from_h <= to_h:
		return hour >= from_h and hour <= to_h
	return hour >= from_h or hour <= to_h


func _load_file(path: String, file_name: String) -> void:
	var stem := file_name.get_basename()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		push_error("Dialogue catalog: failed to read %s" % path)
		return
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Dialogue catalog: %s is not a JSON object" % path)
		return
	var data: Dictionary = parsed
	var npc_id := str(data.get("id", ""))
	if npc_id.is_empty():
		push_error("Dialogue catalog: %s is missing 'id'" % path)
		return
	if npc_id != stem:
		push_error("Dialogue catalog: %s id '%s' does not match filename" % [path, npc_id])
		return
	if not _validate_npc(path, data):
		return
	npcs[npc_id] = data


func _validate_npc(path: String, data: Dictionary) -> bool:
	var ok := true
	var nodes = data.get("nodes", null)
	if typeof(nodes) != TYPE_DICTIONARY or (nodes as Dictionary).is_empty():
		push_error("Dialogue catalog: %s has no 'nodes' object" % path)
		return false
	var node_map: Dictionary = nodes
	var start_id := str(data.get("start", ""))
	if start_id.is_empty() or not node_map.has(start_id):
		push_error("Dialogue catalog: %s 'start' '%s' is missing from nodes" % [path, start_id])
		ok = false

	for node_id in node_map.keys():
		var node = node_map[node_id]
		if typeof(node) != TYPE_DICTIONARY:
			push_error("Dialogue catalog: %s node '%s' is not an object" % [path, node_id])
			ok = false
			continue
		var node_dict: Dictionary = node
		ok = _validate_when(path, str(node_id), node_dict.get("when", {})) and ok
		ok = _validate_lines(path, str(node_id), node_dict.get("lines", [])) and ok
		ok = _validate_choices(path, str(node_id), node_dict.get("choices", []), node_map) and ok
		var flags = node_dict.get("set_flags", [])
		if flags != null and typeof(flags) != TYPE_ARRAY:
			push_error("Dialogue catalog: %s node '%s' set_flags must be an array" % [path, node_id])
			ok = false
	return ok


func _validate_when(path: String, node_id: String, when) -> bool:
	if when == null or when is Dictionary and (when as Dictionary).is_empty():
		return true
	if typeof(when) != TYPE_DICTIONARY:
		push_error("Dialogue catalog: %s node '%s' when must be an object" % [path, node_id])
		return false
	var ok := true
	for key in (when as Dictionary).keys():
		if not KNOWN_WHEN_KEYS.has(str(key)):
			push_error("Dialogue catalog: %s node '%s' unknown when key '%s'" % [path, node_id, key])
			ok = false
	var clause: Dictionary = when
	if clause.has("season") and not SEASON_NAMES.has(str(clause["season"]).to_lower()):
		push_error("Dialogue catalog: %s node '%s' season must be spring/summer/fall/winter" % [path, node_id])
		ok = false
	if clause.has("hour_from") != clause.has("hour_to"):
		push_error("Dialogue catalog: %s node '%s' hour_from and hour_to must be used together" % [path, node_id])
		ok = false
	return ok


func _validate_lines(path: String, node_id: String, lines) -> bool:
	if lines == null:
		return true
	if typeof(lines) != TYPE_ARRAY:
		push_error("Dialogue catalog: %s node '%s' lines must be an array" % [path, node_id])
		return false
	var ok := true
	for i in (lines as Array).size():
		var line = lines[i]
		if line is String:
			if str(line).is_empty():
				push_error("Dialogue catalog: %s node '%s' line %d is empty" % [path, node_id, i])
				ok = false
		elif line is Dictionary:
			if str(line.get("text", "")).is_empty():
				push_error("Dialogue catalog: %s node '%s' line %d is missing text" % [path, node_id, i])
				ok = false
		else:
			push_error("Dialogue catalog: %s node '%s' line %d must be a string or object" % [path, node_id, i])
			ok = false
	return ok


func _validate_choices(path: String, node_id: String, choices, node_map: Dictionary) -> bool:
	if choices == null:
		return true
	if typeof(choices) != TYPE_ARRAY:
		push_error("Dialogue catalog: %s node '%s' choices must be an array" % [path, node_id])
		return false
	var ok := true
	for i in (choices as Array).size():
		var choice = choices[i]
		if typeof(choice) != TYPE_DICTIONARY:
			push_error("Dialogue catalog: %s node '%s' choice %d must be an object" % [path, node_id, i])
			ok = false
			continue
		var text := str(choice.get("text", ""))
		var goto_id := str(choice.get("goto", ""))
		if text.is_empty() or goto_id.is_empty():
			push_error("Dialogue catalog: %s node '%s' choice %d needs text and goto" % [path, node_id, i])
			ok = false
		elif not node_map.has(goto_id):
			push_error("Dialogue catalog: %s node '%s' choice %d goto '%s' is missing" % [path, node_id, i, goto_id])
			ok = false
	return ok
