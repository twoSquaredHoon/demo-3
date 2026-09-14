extends "res://interactables/interactable.gd"

## Bed world object (interactables/bed/bed.tscn). Extends the shared
## interactable base and adds sleep + pickup (when placed via Furniture).
##
## Input (when this bed is the nearest interactable):
##   - Left-click (`interact`) → ConfirmHud Yes/No, then sleep.
##   - Right-click (`use_item` / interact_pickup) → Furniture.pickup(self),
##     but ONLY when the selected hotslot is empty. Otherwise right-click
##     is left for ToolUse (tools / seeds / place).
##
## Scene structure (see bed.tscn): the root Area2D (this script) is the
## interaction target on physics layer 2, while a separate child
## StaticBody2D ("Body") on layer 1 blocks movement.


func _ready() -> void:
	super._ready()
	prompt = "Sleep"


func can_interact(_actor: Node) -> bool:
	return enabled


func get_interact_prompt() -> String:
	return prompt


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	_confirm_sleep()


## True only with an empty selected hotslot — Interactor checks this before
## calling interact_pickup so a right-click with a tool selected still
## reaches ToolUse instead of stealing the bed.
func can_interact_pickup(_actor: Node) -> bool:
	return can_interact(_actor) and Inventory.get_selected_item() == Inventory.ITEM_NONE


## Called by player/interactor.gd on right-click when this bed is nearest
## and can_interact_pickup() passed.
func interact_pickup(_actor: Node) -> void:
	if not can_interact_pickup(_actor):
		return
	Furniture.pickup(self)


func _confirm_sleep() -> void:
	var accepted := await ConfirmHud.ask(
		"Do you want to sleep until morning?",
		"Sleep"
	)
	if not accepted:
		return
	# This is the ONLY other path (besides natural midnight in
	# GameTime._advance_minute()) that can advance the calendar. Soil's
	# daily crop growth / water reset (via GameTime.date_changed) fires
	# exactly the same way from here as it does at midnight.
	GameTime.sleep_to_next_morning()
