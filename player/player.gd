extends CharacterBody2D

@export var speed: float = 120.0


func _physics_process(_delta: float) -> void:
	if Inventory.is_menu_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
