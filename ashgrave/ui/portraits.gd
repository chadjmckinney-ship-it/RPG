class_name Portraits
extends RefCounted
## Character busts. Drop a painted image at res://art/portraits/<id>.png to replace any of them.

const LOOKS := {
	"maren": {"skin": Color("e0b894"), "hair": Color("8a3224"), "hair_hi": Color("b0503a"), "long": true, "coat": Color("3b2e2a"), "collar": Color("5c3a2c"), "trim": Color("b08a4a"), "eyes": Color("4a6a5a")},
	"oswin": {"skin": Color("c89e7c"), "hair": Color("5a5048"), "hood": Color("4a4a52"), "coat": Color("5a5a62"), "collar": Color("6a6a70"), "trim": Color("9a8a60"), "eyes": Color("3a3a4a"), "stubble": true},
	"ketta": {"skin": Color("b98a66"), "hair": Color("241a12"), "hair_hi": Color("3a2a1c"), "braid": true, "coat": Color("3a4630"), "collar": Color("4f5a3a"), "trim": Color("7a6a42"), "eyes": Color("5a3a1a")},
	"maud": {"skin": Color("d8b08e"), "hair": Color("9a9894"), "hair_hi": Color("c8c6c0"), "bun": true, "coat": Color("6a6258"), "collar": Color("d8d0c0"), "trim": Color("8a7a50"), "eyes": Color("4a4a4a")},
	"nessa": {"skin": Color("c8a080"), "hair": Color("e0dcd4"), "hair_hi": Color("f4f2ee"), "long": true, "coat": Color("4a5a3a"), "collar": Color("6a5a3a"), "trim": Color("a08a50"), "eyes": Color("5a6a4a"), "old": true},
	"harl": {"skin": Color("c09070"), "hair": Color("2a2420"), "coat": Color("5a2e24"), "collar": Color("8a8a90"), "trim": Color("c0a060"), "eyes": Color("3a2a1a"), "scar": true, "stubble": true},
}
const FACTION_LOOK := {
	"church": {"skin": Color("d0a888"), "hair": Color("4a3a2a"), "coat": Color("7a7060"), "collar": Color("c8c0a8"), "trim": Color("8a7a50"), "eyes": Color("3a3a3a")},
	"companies": {"skin": Color("c8a080"), "hair": Color("3a2a1e"), "coat": Color("6a3a2a"), "collar": Color("8a8a90"), "trim": Color("a08040"), "eyes": Color("3a2a1a"), "stubble": true},
	"hollow": {"skin": Color("c09878"), "hair": Color("5a4028"), "coat": Color("4a5a3a"), "collar": Color("6a5a3a"), "trim": Color("8a7a4a"), "eyes": Color("4a4a2a")},
}

static var _textures := {}

static func look_for(id: String, faction := "") -> Dictionary:
	return LOOKS.get(id, FACTION_LOOK.get(faction, FACTION_LOOK.hollow))

static func draw(ci: CanvasItem, id: String, r: Rect2, faction := "") -> void:
	var path := "res://art/portraits/%s.png" % id
	if not _textures.has(id):
		_textures[id] = load(path) if ResourceLoader.exists(path) else null
	if _textures[id]:
		ci.draw_texture_rect(_textures[id], r, false)
		return
	var L := look_for(id, faction)
	var s := r.size.x / 100.0
	var o := r.position
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	# backdrop: dusk vignette
	ci.draw_rect(r, Color("1a1612"))
	ci.draw_circle(P.call(50, 45), 44 * s, Color("2a221a"))
	ci.draw_circle(P.call(50, 40), 30 * s, Color("33291e"))
	var hair: Color = L.hair
	var hair_hi: Color = L.get("hair_hi", hair.lightened(0.15))
	# hair behind the shoulders
	if L.get("long", false):
		ci.draw_colored_polygon(PackedVector2Array([P.call(28, 30), P.call(72, 30), P.call(78, 88), P.call(22, 88)]), hair)
		ci.draw_line(P.call(30, 40), P.call(26, 84), hair_hi, 2.0 * s)
		ci.draw_line(P.call(70, 40), P.call(75, 82), hair_hi, 2.0 * s)
	# shoulders and coat
	ci.draw_colored_polygon(PackedVector2Array([P.call(8, 100), P.call(18, 76), P.call(38, 68), P.call(62, 68), P.call(82, 76), P.call(92, 100)]), L.coat)
	ci.draw_colored_polygon(PackedVector2Array([P.call(38, 68), P.call(50, 86), P.call(62, 68), P.call(58, 66), P.call(42, 66)]), L.collar)
	ci.draw_line(P.call(38, 68), P.call(50, 86), L.trim, 1.5 * s)
	ci.draw_line(P.call(62, 68), P.call(50, 86), L.trim, 1.5 * s)
	# neck and face
	ci.draw_rect(Rect2(P.call(44, 56), Vector2(12, 14) * s), L.skin.darkened(0.12))
	var face := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var w := 15.0 if i > 6 and i < 18 else 16.5
		face.append(P.call(50 + cos(a) * w, 40 + sin(a) * 20 + (2.0 if sin(a) > 0.6 else 0.0)))
	ci.draw_colored_polygon(face, L.skin)
	ci.draw_colored_polygon(PackedVector2Array([P.call(36, 44), P.call(40, 56), P.call(50, 62), P.call(44, 50)]), L.skin.darkened(0.08))  # cheek shade
	# eyes, brows, nose, mouth
	for ex in [43.0, 57.0]:
		ci.draw_circle(P.call(ex, 39), 2.6 * s, Color("f0e8dc"))
		ci.draw_circle(P.call(ex, 39), 1.5 * s, L.eyes)
		ci.draw_line(P.call(ex - 4, 34.5 if not L.get("old", false) else 35.5), P.call(ex + 4, 34), hair.darkened(0.2), 1.6 * s)
	ci.draw_line(P.call(50, 40), P.call(48.5, 48), L.skin.darkened(0.25), 1.2 * s)
	ci.draw_line(P.call(45, 53), P.call(55, 53), L.skin.darkened(0.35), 1.4 * s)
	if L.get("old", false):
		ci.draw_line(P.call(38, 44), P.call(41, 47), L.skin.darkened(0.2), 1.0 * s)
		ci.draw_line(P.call(62, 44), P.call(59, 47), L.skin.darkened(0.2), 1.0 * s)
	if L.get("stubble", false):
		for i in 14:
			ci.draw_circle(P.call(40 + (i % 7) * 3.3, 52 + (i / 7) * 3.5), 0.6 * s, hair.darkened(0.3))
	if L.get("scar", false):
		ci.draw_line(P.call(58, 32), P.call(63, 48), Color("8a5040"), 1.4 * s)
	# hair on top / hood
	if L.has("hood"):
		ci.draw_colored_polygon(PackedVector2Array([P.call(28, 50), P.call(30, 24), P.call(50, 12), P.call(70, 24), P.call(72, 50), P.call(66, 30), P.call(50, 22), P.call(34, 30)]), L.hood)
	else:
		ci.draw_colored_polygon(PackedVector2Array([P.call(33, 40), P.call(34, 26), P.call(50, 17), P.call(66, 26), P.call(67, 40), P.call(62, 28), P.call(50, 25), P.call(40, 30)]), hair)
		ci.draw_line(P.call(40, 24), P.call(52, 20), hair_hi, 1.5 * s)
		if L.get("bun", false):
			ci.draw_circle(P.call(50, 16), 7 * s, hair)
		if L.get("braid", false):
			for i in 5:
				ci.draw_circle(P.call(68 + i * 0.6, 48 + i * 7), 3.2 * s, hair if i % 2 == 0 else hair_hi)
	ci.draw_rect(r, Color("6a5a3a"), false, 1.5)
