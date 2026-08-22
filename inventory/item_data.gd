class_name ItemData
extends Resource

## Intended-future data Resource for item presentation (display name, icon
## color, and eventually a real icon Texture2D). NOT USED ANYWHERE at
## runtime today — `autoload/inventory.gd`'s item_display_name()/item_color()
## still hardcode this same information via item-ID `match` statements
## directly inside the gameplay autoload.
##
## See GAME_SYSTEMS_SUMMARY.md sections 18 and 23 for the intended cleanup:
## once real art exists, Inventory should hold an ItemData per item ID (or a
## small table of them) and simply look presentation up from these
## Resources instead of duplicating it in `match` statements. That would
## also make it trivial to give items differing stack limits, which
## Inventory's hardcoded MAX_STACK = 99 currently applies to everything
## (including tools, which arguably shouldn't stack at all).

@export var id: String = ""
@export var display_name: String = ""
@export var icon_color: Color = Color.WHITE


static func make(item_id: String, item_name: String, color: Color) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = item_name
	item.icon_color = color
	return item
