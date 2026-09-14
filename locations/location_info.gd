extends Node

## Tiny "identity tag" attached to the root node of a farm scene (see
## MainFarmSpring.tscn: the root Node2D uses this script with
## display_name = "Spring Farm"). Its only job is to push that name into
## `autoload/game_state.gd` on startup, which `ui/location_hud.gd` then
## displays.
##
## Note the location name here is about the SCENE identity ("Spring Farm"),
## not the current visual season — `locations/seasonal_farm_tiles.gd`
## swaps the seasonal ground art independently, so the HUD keeps reading
## "Spring Farm" all year even after the tiles visually become Summer/Fall/
## Winter (see GAME_SYSTEMS_SUMMARY.md section 5).

@export var display_name: String = "Unknown"


func _ready() -> void:
	GameState.set_location(display_name)
