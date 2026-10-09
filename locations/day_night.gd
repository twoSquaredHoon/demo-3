extends CanvasModulate

## Day/night tint for the world. Tints everything in the scene's world layer
## (ground, crops, buildings, characters) by the time of day. UI on a
## CanvasLayer (HUD, inventory, dialogue) is NOT affected.
## Added to every location automatically by location_info.gd.
##
## Edit KEYS to change the look: [hour, Color]. Colors between keys blend
## smoothly; the list wraps around midnight.

const KEYS := [
	[0.0, Color(0.32, 0.36, 0.58)],   # night
	[4.5, Color(0.36, 0.40, 0.62)],   # late night
	[6.0, Color(0.95, 0.76, 0.62)],   # dawn
	[8.0, Color(1.0, 1.0, 1.0)],      # day
	[16.5, Color(1.0, 1.0, 1.0)],     # day
	[18.5, Color(1.0, 0.74, 0.52)],   # sunset
	[20.5, Color(0.42, 0.42, 0.66)],  # dusk
	[24.0, Color(0.32, 0.36, 0.58)],  # night (same as 0)
]


func _ready() -> void:
	GameTime.time_changed.connect(_on_time_changed)
	_on_time_changed(GameTime.hour, GameTime.minute)


func _on_time_changed(hour: int, minute: int) -> void:
	color = color_at(float(hour) + float(minute) / 60.0)


static func color_at(t: float) -> Color:
	for i in range(KEYS.size() - 1):
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if t >= a[0] and t <= b[0]:
			var w := (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return (a[1] as Color).lerp(b[1], w)
	return KEYS[0][1]
