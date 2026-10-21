extends "res://interactables/interactable.gd"

## The cat. Sits and breathes; left-click (empty hand / non-farm item) to pet:
## a little squish and a heart floats up.

@onready var _visual: Node2D = $Visual

var _breath: Tween


func _ready() -> void:
	super._ready()
	prompt = "Pet"
	_start_breathing()


func interact(_actor: Node) -> void:
	_squish()
	_pop_heart()


func _start_breathing() -> void:
	_breath = create_tween().set_loops()
	_breath.tween_property(_visual, "scale", Vector2(1.0, 1.04), 1.2).set_trans(Tween.TRANS_SINE)
	_breath.tween_property(_visual, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE)


func _squish() -> void:
	if _breath:
		_breath.kill()
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector2(1.15, 0.85), 0.08)
	t.tween_property(_visual, "scale", Vector2(0.95, 1.08), 0.1)
	t.tween_property(_visual, "scale", Vector2.ONE, 0.12)
	t.finished.connect(_start_breathing)


func _pop_heart() -> void:
	# Tiny pixel heart (7x6), drawn as a polygon so no font is needed.
	var heart := Polygon2D.new()
	heart.color = Color(0.9, 0.3, 0.38)
	heart.polygon = PackedVector2Array([
		Vector2(0, 1), Vector2(1, 0), Vector2(3, 0), Vector2(3.5, 1), Vector2(4, 0),
		Vector2(6, 0), Vector2(7, 1), Vector2(7, 3), Vector2(3.5, 6), Vector2(0, 3),
	])
	heart.position = Vector2(-3.5, -22)
	add_child(heart)
	var t := create_tween().set_parallel()
	t.tween_property(heart, "position:y", heart.position.y - 10.0, 0.8)
	t.tween_property(heart, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(heart.queue_free)
