extends Node
## World clock. One in-game day lasts DAY_SECONDS real seconds; frozen during tactical pause.

const DAY_SECONDS := 480.0
var time := 8.0 / 24.0  # fraction of a day, starts 08:00
var day := 1
var _last_hour := -1

func _process(delta: float) -> void:
	if TacticalPause.paused:
		return
	time += delta / DAY_SECONDS
	if time >= 1.0:
		time -= 1.0
		day += 1
	var h := hour()
	if h != _last_hour:
		_last_hour = h
		Events.hour_changed.emit(h)

func hour() -> int:
	return int(time * 24.0)

func clock_text() -> String:
	var mins := int(time * 24.0 * 60.0)
	return "%02d:%02d" % [mins / 60, mins % 60]

## Light level 0 (midnight) .. 1 (noon).
func daylight() -> float:
	return clampf(0.5 - 0.5 * cos(time * TAU) * 1.25, 0.0, 1.0)

func tint() -> Color:
	var night := Color(0.36, 0.4, 0.62)
	var dusk := Color(0.95, 0.62, 0.5)
	var day := Color(1, 1, 1)
	var d := daylight()
	if d < 0.5:
		return night.lerp(dusk, d * 2.0)
	return dusk.lerp(day, (d - 0.5) * 2.0)
