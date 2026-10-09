extends Node

## AUTOLOAD. Three-row passing card match (세줄패). Original cards; HUD renders.
## Start from dialogue via node key start_minigame: "row_cards".

const CatalogScript := preload("res://cards/card_catalog.gd")
const PAUSE_SOURCE := "card_game"
const HAND_SIZE := 10
const GEMS_START := 2
const ROW_IDS := ["field", "alley", "hill"]

signal match_started
signal board_changed
signal match_ended(result: String)

var is_open: bool = false
var opponent_id: String = ""
var whose_turn: String = "player"
var is_thinking: bool = false
var result: String = ""
var log_line: String = ""
var player_gems: int = GEMS_START
var opponent_gems: int = GEMS_START
var player_passed: bool = false
var opponent_passed: bool = false

var _catalog = CatalogScript.new()
var _next_uid: int = 1
var _player_hand: Array[Dictionary] = []
var _opponent_hand: Array[Dictionary] = []
var _player_board: Dictionary = {}
var _opponent_board: Dictionary = {}
var _weather: Dictionary = {}
var _busy: bool = false


func _ready() -> void:
	_catalog.load_all()


func start_match(npc_id: String) -> void:
	if is_open:
		return
	is_open = true
	opponent_id = npc_id
	result = ""
	log_line = "세 줄에 패를 내. 두 번 이기면 끝이야."
	whose_turn = "player"
	is_thinking = false
	_busy = false
	player_gems = GEMS_START
	opponent_gems = GEMS_START
	_reset_round_board()
	_player_hand = _draw_hand("player")
	_opponent_hand = _draw_hand(npc_id if _catalog.decks.has(npc_id) else "minseo")
	GameTime.request_pause(PAUSE_SOURCE)
	match_started.emit()
	board_changed.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	is_thinking = false
	_busy = false
	opponent_id = ""
	whose_turn = "player"
	_player_hand.clear()
	_opponent_hand.clear()
	_reset_round_board()
	GameTime.release_pause(PAUSE_SOURCE)
	board_changed.emit()


func opponent_name() -> String:
	if opponent_id.is_empty():
		return "상대"
	return Dialogue.npc_display_name(opponent_id)


func row_ids() -> Array:
	return ROW_IDS.duplicate()


func row_label(row_id: String) -> String:
	return _catalog.row_name(row_id)


func row_color(row_id: String) -> Color:
	return _catalog.row_color(row_id)


func weather_on(row_id: String) -> bool:
	return bool(_weather.get(row_id, false))


func player_hand() -> Array[Dictionary]:
	return _player_hand


func opponent_hand_count() -> int:
	return _opponent_hand.size()


func board_cards(side: String, row_id: String) -> Array:
	var board := _board_of(side)
	return board.get(row_id, [])


func row_score(side: String, row_id: String) -> int:
	return _row_score(_board_of(side), row_id)


func total_score(side: String) -> int:
	var total := 0
	for row_id in ROW_IDS:
		total += row_score(side, row_id)
	return total


func can_act() -> bool:
	return is_open and result.is_empty() and whose_turn == "player" and not is_thinking and not player_passed


func play_card(uid: int) -> bool:
	if not can_act() or _busy:
		return false
	var card := _take_from_hand(_player_hand, uid)
	if card.is_empty():
		return false
	_place(card, "player")
	log_line = "나: %s" % _describe(card)
	player_passed = false
	board_changed.emit()
	_after_play("player")
	return true


func pass_turn() -> bool:
	if not can_act() or _busy:
		return false
	player_passed = true
	log_line = "나: 패스"
	board_changed.emit()
	_after_play("player")
	return true


func forfeit() -> void:
	if not is_open or not result.is_empty():
		return
	result = "lose"
	log_line = "기권했다."
	_finish_match()


func _after_play(side: String) -> void:
	if _round_should_end():
		_finish_round()
		return
	if side == "player" and not opponent_passed:
		_start_opponent_turn()
	elif side == "opponent" and not player_passed:
		whose_turn = "player"
		is_thinking = false
		board_changed.emit()
	elif player_passed and not opponent_passed:
		_start_opponent_turn()
	elif opponent_passed and not player_passed:
		whose_turn = "player"
		is_thinking = false
		board_changed.emit()
	else:
		_finish_round()


func _start_opponent_turn() -> void:
	whose_turn = "opponent"
	is_thinking = true
	board_changed.emit()
	_run_opponent()


func _run_opponent() -> void:
	_busy = true
	await get_tree().create_timer(0.45).timeout
	if not is_open or not result.is_empty():
		_busy = false
		return
	if opponent_passed or _opponent_hand.is_empty():
		opponent_passed = true
		log_line = "%s: 패스" % opponent_name()
		is_thinking = false
		_busy = false
		board_changed.emit()
		_after_play("opponent")
		return
	var pick := _ai_pick()
	if pick < 0:
		opponent_passed = true
		log_line = "%s: 패스" % opponent_name()
	else:
		var card: Dictionary = _opponent_hand[pick]
		_opponent_hand.remove_at(pick)
		_place(card, "opponent")
		log_line = "%s: %s" % [opponent_name(), _describe(card)]
		opponent_passed = false
	is_thinking = false
	_busy = false
	board_changed.emit()
	_after_play("opponent")


func _ai_pick() -> int:
	var my_score := total_score("opponent")
	var their_score := total_score("player")
	if player_passed and my_score > their_score:
		return -1
	var spy_i := _find_ability(_opponent_hand, "spy")
	if spy_i >= 0 and _opponent_hand.size() >= 6:
		return spy_i
	var weather_i := _ai_weather_index(their_score)
	if weather_i >= 0:
		return weather_i
	if player_passed and my_score <= their_score:
		var win_i := _cheapest_lead_index(their_score - my_score + 1)
		if win_i >= 0:
			return win_i
	var unit_i := _highest_unit_index()
	if unit_i >= 0:
		return unit_i
	var horn_i := _find_ability(_opponent_hand, "horn")
	if horn_i >= 0 and my_score >= 6:
		return horn_i
	if player_passed:
		return 0
	if my_score > their_score and _opponent_hand.size() <= 3:
		return -1
	return 0 if not _opponent_hand.is_empty() else -1


func _ai_weather_index(their_score: int) -> int:
	if their_score < 8:
		return -1
	var best_row := ""
	var best := 0
	for row_id in ROW_IDS:
		if weather_on(row_id):
			continue
		var s := row_score("player", row_id)
		if s > best:
			best = s
			best_row = row_id
	if best < 8 or best_row.is_empty():
		return -1
	for i in _opponent_hand.size():
		var card: Dictionary = _opponent_hand[i]
		if str(card.get("ability", "")) == "weather" and str(card.get("row", "")) == best_row:
			return i
	return -1


func _cheapest_lead_index(need: int) -> int:
	var best_i := -1
	var best_power := 999
	for i in _opponent_hand.size():
		var card: Dictionary = _opponent_hand[i]
		var ability := str(card.get("ability", "none"))
		if ability == "weather" or ability == "horn" or ability == "spy":
			continue
		var power := int(card.get("power", 0))
		if power >= need and power < best_power:
			best_power = power
			best_i = i
	return best_i


func _highest_unit_index() -> int:
	var best_i := -1
	var best_power := -1
	for i in _opponent_hand.size():
		var card: Dictionary = _opponent_hand[i]
		var ability := str(card.get("ability", "none"))
		if ability == "weather" or ability == "horn" or ability == "spy":
			continue
		var power := int(card.get("power", 0))
		if power > best_power:
			best_power = power
			best_i = i
	return best_i


func _find_ability(hand: Array[Dictionary], ability: String) -> int:
	for i in hand.size():
		if str(hand[i].get("ability", "")) == ability:
			return i
	return -1


func _round_should_end() -> bool:
	if player_passed and opponent_passed:
		return true
	if _player_hand.is_empty() and _opponent_hand.is_empty():
		return true
	if _player_hand.is_empty() and opponent_passed:
		return true
	if _opponent_hand.is_empty() and player_passed:
		return true
	return false


func _finish_round() -> void:
	var p := total_score("player")
	var o := total_score("opponent")
	if p > o:
		opponent_gems -= 1
		log_line = "이 판은 네가 이겼어. %d 대 %d." % [p, o]
	elif o > p:
		player_gems -= 1
		log_line = "이 판은 내가 이겼지. %d 대 %d." % [o, p]
	else:
		player_gems -= 1
		opponent_gems -= 1
		log_line = "비겼어. %d 대 %d." % [p, o]
	if player_gems <= 0 and opponent_gems <= 0:
		result = "draw"
		_finish_match()
		return
	if player_gems <= 0:
		result = "lose"
		_finish_match()
		return
	if opponent_gems <= 0:
		result = "win"
		_finish_match()
		return
	_reset_round_board()
	whose_turn = "player" if p <= o else "opponent"
	is_thinking = false
	board_changed.emit()
	if whose_turn == "opponent":
		_start_opponent_turn()


func _finish_match() -> void:
	is_thinking = false
	_busy = false
	whose_turn = ""
	Dialogue.set_flag("minseo_cards_played")
	if result == "win":
		Dialogue.set_flag("minseo_cards_won")
	board_changed.emit()
	match_ended.emit(result)


func _place(card: Dictionary, side: String) -> void:
	var ability := str(card.get("ability", "none"))
	var row_id := str(card.get("row", "field"))
	if ability == "weather":
		_weather[row_id] = true
		return
	var target_side := side
	if ability == "spy":
		target_side = "opponent" if side == "player" else "player"
		_draw_one(side)
		_draw_one(side)
	var board := _board_of(target_side)
	var row: Array = board[row_id]
	row.append(card)
	board[row_id] = row


func _draw_one(side: String) -> void:
	# Prototype decks are the opening hand only; spies add a spare from the
	# same deck list so a spy still feels like it draws.
	var deck_id := "player" if side == "player" else (opponent_id if _catalog.decks.has(opponent_id) else "minseo")
	var ids: Array = _catalog.deck_ids(deck_id)
	if ids.is_empty():
		return
	var extra := _make_card(str(ids[randi() % ids.size()]))
	if side == "player":
		_player_hand.append(extra)
	else:
		_opponent_hand.append(extra)


func _take_from_hand(hand: Array[Dictionary], uid: int) -> Dictionary:
	for i in hand.size():
		if int(hand[i].get("uid", -1)) == uid:
			var card: Dictionary = hand[i]
			hand.remove_at(i)
			return card
	return {}


func _row_score(board: Dictionary, row_id: String) -> int:
	var row: Array = board.get(row_id, [])
	var frost := weather_on(row_id)
	var total := 0
	var has_horn := false
	var counts: Dictionary = {}
	for card in row:
		var cid := str(card.get("id", ""))
		counts[cid] = int(counts.get(cid, 0)) + 1
		if str(card.get("ability", "")) == "horn":
			has_horn = true
	for card in row:
		var ability := str(card.get("ability", "none"))
		if ability == "horn":
			continue
		var power := int(card.get("power", 0))
		if frost and ability != "hero":
			power = 1
		elif ability == "bond":
			power *= int(counts.get(str(card.get("id", "")), 1))
		total += power
	if has_horn:
		total *= 2
	return total


func _describe(card: Dictionary) -> String:
	var ability := str(card.get("ability", "none"))
	var name := str(card.get("name", "?"))
	if ability == "weather" or ability == "horn":
		return name
	if ability == "spy":
		return "%s 첩보" % name
	return "%s %d" % [name, int(card.get("power", 0))]


func _draw_hand(deck_id: String) -> Array[Dictionary]:
	var ids: Array = _catalog.deck_ids(deck_id).duplicate()
	ids.shuffle()
	var hand: Array[Dictionary] = []
	var n: int = mini(HAND_SIZE, ids.size())
	for i in n:
		hand.append(_make_card(str(ids[i])))
	return hand


func _make_card(card_id: String) -> Dictionary:
	var template := _catalog.card_template(card_id)
	var card := template.duplicate(true)
	card["uid"] = _next_uid
	_next_uid += 1
	if not card.has("ability"):
		card["ability"] = "none"
	return card


func _reset_round_board() -> void:
	player_passed = false
	opponent_passed = false
	_weather = { "field": false, "alley": false, "hill": false }
	_player_board = _empty_board()
	_opponent_board = _empty_board()


func _empty_board() -> Dictionary:
	return {
		"field": [],
		"alley": [],
		"hill": [],
	}


func _board_of(side: String) -> Dictionary:
	if side == "opponent":
		return _opponent_board
	return _player_board
