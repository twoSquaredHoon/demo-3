extends Resource

## Data definition for one crop type (Rice, Beans, …). This is a Resource,
## not an autoload — `autoload/soil.gd` and `interactables/crop/crop_plant.gd`
## both preload this script and call its static factories (rice()/beans()/
## from_seed()/from_id()) to get a filled-in CropData instance on demand.
##
## LOOKUP IMPLEMENTATION NOTE: from_seed()/from_id() are hardcoded `match`
## statements, and EVERY call allocates a brand-new Resource (see make()).
## There are no `.tres` crop asset files yet — see GAME_SYSTEMS_SUMMARY.md
## section 12. That's fine at the current scale (two crops, called a
## handful of times per interaction), but adding a crop means adding a case
## to both from_seed() and from_id(), plus a new static factory function
## below, following the rice()/beans() pattern.
##
## Who reads this data:
##   - `autoload/soil.gd`: plant() looks up from_seed() to validate a seed
##     ID and to seed _planted/_stages; harvest() reads harvest_item_id and
##     harvest_type to decide what to grant and whether to remove or regrow
##     the plant.
##   - `interactables/crop/crop_plant.gd`: refresh_visual() reads color,
##     mature_stage, and display_name to draw itself and choose its prompt.

enum HarvestType { SINGLE_HARVEST, REGROWABLE }

@export var id: String = ""
@export var seed_item_id: String = ""
@export var harvest_item_id: String = ""
@export var display_name: String = ""
@export var harvest_type: HarvestType = HarvestType.SINGLE_HARVEST
## Stage at which the crop is mature/harvestable (see Soil.is_harvestable()).
@export var mature_stage: int = 3
## For REGROWABLE crops, the stage harvest() resets to (see Soil.harvest());
## unused for SINGLE_HARVEST crops, which are removed entirely instead.
@export var regrow_stage: int = 2
## Placeholder-art color; stands in for a real sprite/icon until final art
## lands (see GAME_SYSTEMS_SUMMARY.md sections 18/23).
@export var color: Color = Color(0.35, 0.85, 0.3, 1.0)
## Gold earned per unit when sold at the Selling Box (see
## interactables/furniture/selling_box/selling_box.gd and autoload/wallet.gd).
## Placeholder value like the rest of this file's numbers — not balanced
## against anything yet.
@export var sell_price: int = 0


## Generic constructor used by the per-crop static factories below. Loading
## the script by path (rather than referencing a preloaded const) keeps this
## file self-contained if it's ever duplicated as a template.
static func make(
	crop_id: String,
	seed_id: String,
	harvest_id: String,
	crop_name: String,
	type: HarvestType,
	crop_color: Color,
	mature: int = 3,
	regrow: int = 2,
	price: int = 0
):
	var crop = load("res://farming/crop_data.gd").new()
	crop.id = crop_id
	crop.seed_item_id = seed_id
	crop.harvest_item_id = harvest_id
	crop.display_name = crop_name
	crop.harvest_type = type
	crop.color = crop_color
	crop.mature_stage = mature
	crop.regrow_stage = regrow
	crop.sell_price = price
	return crop


## Rice: SINGLE_HARVEST — matures at stage 3, harvest removes the plant and
## requires a fresh rice_seed to replant (see Soil.harvest()).
static func rice():
	return make(
		"rice",
		"rice_seed",
		"rice",
		"Rice",
		HarvestType.SINGLE_HARVEST,
		Color(0.85, 0.8, 0.35, 1.0),
		3,
		2,
		20
	)


## Beans: REGROWABLE — matures at stage 3, harvest resets it to stage 2
## (regrow_stage) instead of removing it, so one more watered day brings it
## back to maturity indefinitely.
static func beans():
	return make(
		"beans",
		"beans_seed",
		"beans",
		"Beans",
		HarvestType.REGROWABLE,
		Color(0.35, 0.7, 0.25, 1.0),
		3,
		2,
		15
	)


## Maps a seed item ID (from Inventory, e.g. "rice_seed") to its CropData.
## Called by Soil.plant() to validate the seed being used and to know what
## to actually plant. Returns null for anything not recognized here.
static func from_seed(seed_id: String):
	match seed_id:
		"rice_seed":
			return rice()
		"beans_seed":
			return beans()
		_:
			return null


## Maps a crop ID (as stored in Soil._planted) back to its CropData. Called
## by Soil.get_crop() any time growth/harvest/visual logic needs the full
## crop definition for an already-planted cell.
static func from_id(crop_id: String):
	match crop_id:
		"rice":
			return rice()
		"beans":
			return beans()
		_:
			return null
