extends "res://interactables/interactable.gd"

## Bed world object (interactables/bed/bed.tscn), instanced once in
## MainFarmSpring.tscn next to the Player. Extends the shared interactable
## base (interactables/interactable.gd) and adds exactly one behavior:
## right-click → sleep to the next morning.
##
## Scene structure (see bed.tscn): the root Area2D (this script) is the
## RIGHT-CLICK interaction target on physics layer 2, while a separate
## child StaticBody2D ("Body") on layer 1 is what actually blocks the
## player from walking through the bed. Those are two different physics
## bodies on two different layers doing two different jobs — see
## GAME_SYSTEMS_SUMMARY.md section 20 for the full layer table.
##
## Reached via: `player/interactor.gd`'s right-click handler finds this as
## the nearest overlapping "interactable" and calls interact(player) on it,
## which calls straight into the `GameTime` autoload — bed.gd itself holds
## no state of its own.


func _ready() -> void:
	super._ready()
	prompt = "Sleep"


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	# This is the ONLY other path (besides natural midnight in
	# GameTime._advance_minute()) that can advance the calendar. Soil's
	# daily crop growth / water reset (via GameTime.date_changed) fires
	# exactly the same way from here as it does at midnight.
	GameTime.sleep_to_next_morning()
