extends RefCounted

## Loads res://cards/row_cards.json. CardGame owns the live match.

const PATH := "res://cards/row_cards.json"
const ROW_IDS := ["field", "alley", "hill"]
const ABILITIES := ["none", "hero", "spy", "weather", "horn", "bond"]

var rows: Dictionary = {}
var cards: Dictionary = {}
var decks: Dictionary = {}


func load_all() -> void:
	rows.clear()
	cards.clear()
	decks.clear()
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		push_error("Card catalog: failed to read %s" % PATH)
		return
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Card catalog: %s is not a JSON object" % PATH)
		return
	var data: Dictionary = parsed
	var row_map = data.get("rows", {})
	if typeof(row_map) == TYPE_DICTIONARY:
		rows = row_map
	var list = data.get("cards", [])
	if typeof(list) == TYPE_ARRAY:
		for item in list:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var card: Dictionary = item
			var card_id := str(card.get("id", ""))
			if card_id.is_empty():
				push_error("Card catalog: a card is missing id")
				continue
			if not ROW_IDS.has(str(card.get("row", ""))):
				push_error("Card catalog: '%s' has invalid row" % card_id)
				continue
			if not ABILITIES.has(str(card.get("ability", "none"))):
				push_error("Card catalog: '%s' has invalid ability" % card_id)
				continue
			cards[card_id] = card
	var deck_map = data.get("decks", {})
	if typeof(deck_map) == TYPE_DICTIONARY:
		for deck_id in deck_map.keys():
			var raw = deck_map[deck_id]
			if typeof(raw) != TYPE_ARRAY:
				continue
			var ids: Array[String] = []
			for entry in raw:
				var card_id := str(entry)
				if not cards.has(card_id):
					push_error("Card catalog: deck '%s' unknown card '%s'" % [deck_id, card_id])
					continue
				ids.append(card_id)
			decks[str(deck_id)] = ids


func row_name(row_id: String) -> String:
	var info = rows.get(row_id, {})
	if typeof(info) == TYPE_DICTIONARY:
		return str(info.get("name", row_id))
	return row_id


func row_color(row_id: String) -> Color:
	var info = rows.get(row_id, {})
	if typeof(info) == TYPE_DICTIONARY:
		return Color.html(str(info.get("color", "#888888")))
	return Color(0.5, 0.5, 0.5)


func card_template(card_id: String) -> Dictionary:
	return cards.get(card_id, {})


func deck_ids(deck_id: String) -> Array:
	return decks.get(deck_id, [])
