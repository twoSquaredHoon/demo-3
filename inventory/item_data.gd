class_name ItemData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var icon_color: Color = Color.WHITE


static func make(item_id: String, item_name: String, color: Color) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = item_name
	item.icon_color = color
	return item
