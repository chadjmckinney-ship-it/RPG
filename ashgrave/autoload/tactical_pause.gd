extends Node
## Tactical pause: the world freezes but the player can still select and give orders.

var paused := false

func toggle() -> void:
	set_paused(not paused)

func set_paused(value: bool) -> void:
	if value == paused:
		return
	paused = value
	Events.paused_changed.emit(paused)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_toggle"):
		toggle()
		get_viewport().set_input_as_handled()
