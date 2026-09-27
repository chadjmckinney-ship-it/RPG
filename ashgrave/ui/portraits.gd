class_name Portraits
extends RefCounted
## Pixel busts cut from each character's own LPC sprite (head and shoulders, facing the
## viewer), so a portrait always matches the figure on the field, gear included.

const BUST := Rect2(18, 9, 28, 28)   # inside a 64x64 south-facing idle frame
const BACK := Color("1c1814")
const RIM := Color("2c241b")
## Backdrop tint per allegiance: [top, bottom].
const BACKDROPS := {
	"party": [Color("3a2c1c"), Color("16110c")],
	"church": [Color("3a3a40"), Color("141418")],
	"companies": [Color("40201c"), Color("170c0a")],
	"hollow": [Color("26341e"), Color("0e140b")],
}

## The LPC character id an actor is currently drawn with ("" if it has no LPC sprite).
static func character_of(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor):
		return ""
	var s = actor.get("sprite")
	if s is LpcSprite:
		return s.character
	return ""

## Draws the bust of LPC character `char_id` into r (best at 28 px multiples: 56, 84, 112).
static func draw(ci: CanvasItem, char_id: String, r: Rect2, backdrop := "party") -> void:
	# stepped vertical gradient in 8 bands, then a warm halo behind the head
	var cols: Array = BACKDROPS.get(backdrop, BACKDROPS.party)
	for i in 8:
		ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / 8.0, r.size.x, r.size.y / 8.0 + 1.0), cols[0].lerp(cols[1], i / 7.0))
	ci.draw_rect(Rect2(r.position + r.size * Vector2(0.18, 0.12), r.size * Vector2(0.64, 0.5)), Color(1, 0.9, 0.7, 0.05))
	var tex := LpcSprite.tex("res://art/lpc/chars/%s.png" % char_id) if char_id != "" else null
	if tex == null:
		return
	var idle: Dictionary = LpcSprite.meta().layout.idle
	var src := Rect2(BUST.position + Vector2(0, float(idle.y) + 2 * float(idle.size)), BUST.size)
	ci.draw_texture_rect_region(tex, r, src)
	_frame(ci, r)

## Pixel frame: dark outer line, brass inner line, darker corners.
static func _frame(ci: CanvasItem, r: Rect2) -> void:
	var k := maxf(1.0, roundf(r.size.x / 56.0))
	ci.draw_rect(r, Color("0a0806"), false, 2.0 * k)
	ci.draw_rect(r.grow(-2.0 * k), Color("8a6c3c"), false, k)
	for c in [r.position, r.position + Vector2(r.size.x - 3 * k, 0), r.position + Vector2(0, r.size.y - 3 * k), r.end - Vector2(3 * k, 3 * k)]:
		ci.draw_rect(Rect2(c, Vector2(3 * k, 3 * k)), Color("0a0806"))

static func draw_actor(ci: CanvasItem, actor: Node, r: Rect2) -> void:
	var backdrop := "party"
	if actor and is_instance_valid(actor) and actor.get("faction") != "party":
		var v = actor.get("village")
		if v is Dictionary:
			backdrop = v.get("faction", "hollow")
	draw(ci, character_of(actor), r, backdrop)
