class_name Portraits
extends RefCounted
## Pixel busts cut from each character's own LPC sprite (head and shoulders, facing the
## viewer), so a portrait always matches the figure on the field, gear included.

const BUST := Rect2(18, 5, 28, 28)   # inside a 64x64 south-facing idle frame
const BACK := Color("1c1814")
const RIM := Color("2c241b")

## The LPC character id an actor is currently drawn with ("" if it has no LPC sprite).
static func character_of(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor):
		return ""
	var s = actor.get("sprite")
	if s is LpcSprite:
		return s.character
	return ""

## Draws the bust of LPC character `char_id` into r (best at 28 px multiples: 56, 84, 112).
static func draw(ci: CanvasItem, char_id: String, r: Rect2) -> void:
	ci.draw_rect(r, BACK)
	ci.draw_rect(Rect2(r.position + r.size * Vector2(0.1, 0.35), r.size * Vector2(0.8, 0.65)), RIM)
	var tex := LpcSprite.tex("res://art/lpc/chars/%s.png" % char_id) if char_id != "" else null
	if tex == null:
		return
	var idle: Dictionary = LpcSprite.meta().layout.idle
	var src := Rect2(BUST.position + Vector2(0, float(idle.y) + 2 * float(idle.size)), BUST.size)
	ci.draw_texture_rect_region(tex, r, src)

static func draw_actor(ci: CanvasItem, actor: Node, r: Rect2) -> void:
	draw(ci, character_of(actor), r)
