extends Area2D

## Walk-into path between locations. Not an interactable — body_entered on
## the player layer triggers GameState.travel(). Keep the shape inward of
## the destination spawn so arriving does not immediately bounce back.

@export var destination_path: String = ""
@export var spawn_id: String = ""
@export var label_text: String = ""
@export var exit_size: Vector2 = Vector2(32, 96)
## No gold strip or arrow. Looks like a dark gap so shortcuts can be tested now.
@export var unmarked: bool = false

@onready var _label: Label = $Label
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	var box := RectangleShape2D.new()
	box.size = exit_size
	_shape.shape = box
	var half := exit_size * 0.5
	_visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	if unmarked:
		_visual.color = Color(0.06, 0.06, 0.08, 0.9)
		if _label:
			_label.visible = false
	elif _label:
		_label.text = label_text
		_label.offset_left = -40.0
		_label.offset_right = 40.0
		_label.offset_top = -half.y - 16.0
		_label.offset_bottom = -half.y


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	GameState.travel(destination_path, spawn_id)
