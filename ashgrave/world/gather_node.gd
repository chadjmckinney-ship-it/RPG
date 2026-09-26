class_name GatherNode
extends Node2D
## A harvestable spot (bitterroot, iron seam, deadwood). Right-click to send someone to gather.

var data: Dictionary = {}   # {id, kind, cell}

func display_name() -> String:
	return Gathering.KINDS[data.kind].name

func ready_to_harvest() -> bool:
	return Gathering.available(data.id, TimeOfDay.day)

func on_interact(who) -> void:
	var got := Gathering.harvest(data, TimeOfDay.day)
	if got.is_empty():
		Events.combat_message.emit("%s is picked clean. It will recover in a day or two." % display_name())
	else:
		Audio.play("gather")
		Events.combat_message.emit("%s gathers %d %s." % [who.display_name, got.count, Items.item_name(got.item)])
	queue_redraw()

const ART := {"herb": "leafy_b", "ore": "rock_small", "ash": "charred_stump", "wood": "log"}

var _sprite: Sprite2D

func _ready() -> void:
	var name: String = ART.get(data.kind, "rock_small")
	_sprite = Sprite2D.new()
	_sprite.texture = TileArt.prop_texture(name)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	_sprite.scale = Vector2(TileArt.SCALE, TileArt.SCALE)
	_sprite.offset = -TileArt.prop_foot(name)
	_sprite.show_behind_parent = true
	add_child(_sprite)

func _process(_d: float) -> void:
	queue_redraw()

## The sprite is the body; _draw adds what shows it is ready to harvest.
func _draw() -> void:
	var ok := ready_to_harvest()
	_sprite.modulate = Color(1, 1, 1, 1) if ok else Color(0.55, 0.55, 0.55, 0.7)
	if not ok:
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2(WorldGen.PX, WorldGen.PX))
	match data.kind:
		"herb":
			draw_rect(Rect2(-5, -14, 2, 2), Color(0.9, 0.8, 0.4))
			draw_rect(Rect2(3, -11, 2, 2), Color(0.9, 0.8, 0.4))
			draw_rect(Rect2(-1, -17, 2, 2), Color(0.95, 0.85, 0.45))
		"ore":
			draw_line(Vector2(-6, -8), Vector2(0, -11), Color(0.85, 0.55, 0.3), 1.0)
			draw_line(Vector2(1, -5), Vector2(6, -7), Color(0.85, 0.55, 0.3), 1.0)
		"ash":
			var t := Time.get_ticks_msec() / 400.0
			draw_rect(Rect2(-3, -12, 2, 2), Color(1.0, 0.45, 0.15, 0.6 + 0.4 * sin(t)))
			draw_rect(Rect2(3, -9, 2, 2), Color(1.0, 0.55, 0.2, 0.6 + 0.4 * cos(t)))
		"wood":
			pass
