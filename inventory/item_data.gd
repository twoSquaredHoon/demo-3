class_name ItemData
extends Resource

## Presentation for one inventory item. Stack state stays on Inventory.
## IDs must match Inventory.ITEM_* constants.

@export var id: String = ""
@export var display_name: String = ""
@export var icon_color: Color = Color.WHITE


static func make(item_id: String, item_name: String, color: Color) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = item_name
	item.icon_color = color
	return item


static func from_id(item_id: String) -> ItemData:
	match item_id:
		Inventory.ITEM_HOE:
			return make(Inventory.ITEM_HOE, "Hoe", Color(0.55, 0.35, 0.18, 1.0))
		Inventory.ITEM_WATERING_CAN:
			return make(Inventory.ITEM_WATERING_CAN, "Water", Color(0.25, 0.55, 0.95, 1.0))
		Inventory.ITEM_RICE_SEED:
			return make(Inventory.ITEM_RICE_SEED, "Rice Seed", Color(0.85, 0.8, 0.35, 1.0))
		Inventory.ITEM_BEANS_SEED:
			return make(Inventory.ITEM_BEANS_SEED, "Beans Seed", Color(0.35, 0.55, 0.2, 1.0))
		Inventory.ITEM_RICE:
			return make(Inventory.ITEM_RICE, "Rice", Color(0.95, 0.9, 0.55, 1.0))
		Inventory.ITEM_BEANS:
			return make(Inventory.ITEM_BEANS, "Beans", Color(0.45, 0.7, 0.25, 1.0))
		Inventory.ITEM_BED:
			return make(Inventory.ITEM_BED, "Bed", Color(0.45, 0.55, 0.85, 1.0))
		Inventory.ITEM_SELLING_BOX:
			return make(Inventory.ITEM_SELLING_BOX, "Selling Box", Color(0.75, 0.55, 0.25, 1.0))
		_:
			return null


static func display_name_of(item_id: String) -> String:
	var data := from_id(item_id)
	return data.display_name if data != null else ""


static func icon_color_of(item_id: String) -> Color:
	var data := from_id(item_id)
	if data != null:
		return data.icon_color
	return Color(0.2, 0.2, 0.2, 0.5)
