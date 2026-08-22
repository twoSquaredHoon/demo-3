extends Area2D

## Base class for every right-click-able world object (bed, crop, and any
## future furniture/machine). Nothing in this project instances this script
## directly — `interactables/bed/bed.gd` and
## `interactables/crop/crop_plant.gd` both `extends "res://interactables/interactable.gd"`
## and override interact() (and, for crops, can_interact()) to add their own
## behavior on top of this shared contract.
##
## The shared contract every subclass gets for free:
##   - Added to the "interactable" group in _ready(), which is exactly what
##     `player/interactor.gd` scans for on overlap.
##   - Physics layer 2, mask 0 — see GAME_SYSTEMS_SUMMARY.md section 20 for
##     the full collision-layer table. Layer 2 is reserved project-wide for
##     "interaction Area2D", separate from layer 1 ("solid body").
##   - monitoring = false / monitorable = true: this Area2D does not scan
##     for overlaps itself, it only lets OTHER Area2Ds (the player's
##     Interactor) detect that it exists. Detection direction is therefore
##     one-way: the player finds the object, not the other way around.
##
## Subclasses are expected to override:
##   - can_interact(actor): return whether interact() is currently allowed
##     (e.g. crop_plant.gd additionally requires the crop to be mature).
##   - get_interact_prompt(): text shown for this object ("Sleep",
##     "Harvest", a crop's display_name while immature, etc.).
##   - interact(actor): the actual effect (bed sleeps the player via
##     GameTime; crop harvests via Soil).

const GROUP_NAME := "interactable"
## Physics layer bit used only for interact Area2D overlap (layer 2).
const INTERACT_LAYER := 2

@export var enabled: bool = true
@export var prompt: String = "Interact"


func _ready() -> void:
	add_to_group(GROUP_NAME)
	monitoring = false
	monitorable = true
	collision_layer = INTERACT_LAYER
	collision_mask = 0


## Default implementation just checks the `enabled` export. Override to add
## extra conditions (crop_plant.gd adds "must be mature").
func can_interact(_actor: Node) -> bool:
	return enabled


func get_interact_prompt() -> String:
	return prompt


## No-op by default — subclasses override this with their actual effect.
func interact(_actor: Node) -> void:
	pass
