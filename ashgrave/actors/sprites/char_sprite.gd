class_name CharSprite
extends Node2D
## Base for animated character art. Actors call play(); time freezes during tactical pause.
## Logical animations: idle, walk, attack, cast, hit, die. Subclasses map them to their art.

signal finished(anim: String)

var anim := "idle"
var dir := Vector2.DOWN      # screen-space facing
var t := 0.0
var one_shot := false
var hold_last := false

func play(name: String, restart := false) -> void:
	if name == anim and not restart:
		return
	anim = name
	t = 0.0
	one_shot = name in ["attack", "cast", "hit", "die"]
	hold_last = name == "die"
	_apply()

func face(v: Vector2) -> void:
	if v.length_squared() > 0.01:
		dir = v.normalized()

func _process(delta: float) -> void:
	if TacticalPause.paused:
		return
	t += delta
	var dur := duration(anim)
	if one_shot and t >= dur:
		if hold_last:
			t = dur - 0.001
		else:
			var done := anim
			anim = "idle"
			t = 0.0
			finished.emit(done)
	_apply()

## Seconds for one pass of an animation (overridden).
func duration(_name: String) -> float:
	return 0.5

func _apply() -> void:
	pass
