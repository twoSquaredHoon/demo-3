extends "res://interactables/interactable.gd"

## World object for a single planted crop (interactables/crop/crop_plant.tscn),
## dynamically instanced by `autoload/soil.gd` (_ensure_crop_plant()) — there
## is no hand-placed crop_plant instance anywhere in a scene file; every one
## that exists at runtime was spawned by Soil.plant().
##
## This script owns NO gameplay state. `cell` is just a reference back into
## Soil's dictionaries — every visual detail (color, scale, stage number,
## prompt text) is recomputed in refresh_visual() by asking Soil what is
## actually true. That keeps this object disposable: Soil can free and
## re-spawn it (see _rebuild_overlay_root() in soil.gd) without losing any
## real progress, because none of the real progress ever lived here.
##
## Interaction: extends the shared interactable base (right-click contract)
## but overrides can_interact() to also require Soil.is_harvestable(cell) —
## an immature crop is simply invisible to `player/interactor.gd`'s nearest-
## interactable search, so right-clicking near it does nothing (harvest is
## the ONLY thing right-click does here; left-click/tools never touch crops
## directly, see player/tool_use.gd).
##
## No solid collision (see crop_plant.tscn: no StaticBody2D) — the player
## can walk straight through planted crops.

var cell: Vector2i = Vector2i.ZERO

@onready var sprout: Polygon2D = $Sprout
@onready var stage_label: Label = $StageLabel


func _ready() -> void:
	super._ready()
	prompt = "Harvest"
	refresh_visual()


## Called once by Soil right after instancing this scene, to tell this
## object which farm cell it represents. Everything else derives from here.
func setup(plant_cell: Vector2i) -> void:
	cell = plant_cell
	refresh_visual()


## Overrides the base's simple `enabled` check: a crop is only interactable
## once Soil considers it mature. This is what makes right-click harvesting
## impossible before stage 3 (see crop_data.gd's mature_stage).
func can_interact(_actor: Node) -> bool:
	return enabled and Soil.is_harvestable(cell)


## Delegates entirely to Soil.harvest(cell) — this object never mutates its
## own stage/crop state; Soil is the only thing that does, and this script
## just re-reads the result via refresh_visual() the next time it's called
## (see Soil._refresh_crop_plant(), which calls this after every stage
## change and after harvest()).
func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	Soil.harvest(cell)


## Re-derives every visual detail from Soil's authoritative state for this
## cell: placeholder diamond size (grows 25% per stage) and color (from the
## crop's data), the numeric stage label (0-3), and the interact prompt
## (crop's display name while immature, "Harvest" once mature — matching
## the base class's get_interact_prompt() contract).
func refresh_visual() -> void:
	if sprout == null or stage_label == null:
		return
	var stage := Soil.get_stage(cell)
	var crop = Soil.get_crop(cell)
	if stage < 0 or crop == null:
		return
	sprout.scale = Vector2.ONE * (1.0 + stage * 0.25)
	sprout.color = crop.color
	stage_label.text = str(stage)
	prompt = "Harvest" if stage >= crop.mature_stage else crop.display_name
