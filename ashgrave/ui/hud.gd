class_name Hud
extends CanvasLayer
## Party cards (HP, stamina, abilities with cooldowns), clock, pause banner, combat log.

const INK := Color("e8dfc8")
const MUTED := Color("a8a090")
const GOLD := Color("f0b04a")
const PANEL := Color(0.07, 0.07, 0.08, 0.78)

var main: Node
var clock: Label
var info: Label
var banner: Label
var log_label: Label
var cards: Control
var hint: Label

func setup(m: Node) -> void:
	main = m
	cards = Control.new()
	cards.position = Vector2(12, 12)
	cards.size = Vector2(300, 400)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.draw.connect(_draw_cards)
	add_child(cards)
	clock = _label(22, INK)
	clock.anchor_left = 1.0
	clock.anchor_right = 1.0
	clock.offset_left = -240
	clock.offset_right = -16
	clock.offset_top = 12
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info = _label(13, MUTED)
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = 16
	info.offset_top = -26
	info.text = "Left: select   Right: move / attack   Shift+Right: queue   Q/E: abilities   1-3 / Tab: pick   Space: pause   WASD, wheel: camera"
	log_label = _label(15, INK)
	log_label.anchor_top = 1.0
	log_label.anchor_bottom = 1.0
	log_label.offset_left = 16
	log_label.offset_top = -170
	log_label.offset_right = 600
	log_label.offset_bottom = -34
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	banner = _label(30, GOLD)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -300
	banner.offset_right = 300
	banner.offset_top = 60
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.text = "PAUSED"
	banner.visible = false
	hint = _label(16, Color(0.6, 0.85, 1.0))
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.offset_left = -300
	hint.offset_right = 300
	hint.offset_top = 100
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Events.paused_changed.connect(func(p): banner.visible = p)

func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _process(_d: float) -> void:
	clock.text = "%s\n%s" % [TimeOfDay.clock_text(), main.terrain_under_mouse()]
	log_label.text = "\n".join(main.combat_log.lines)
	var t: Dictionary = main.party.targeting
	hint.text = "" if t.is_empty() else "%s — choose a target (right-click or Esc to cancel)" % Abilities.get_def(t.id).name
	banner.text = "PAUSED — give orders, Space to resume" if TacticalPause.paused else ""
	cards.queue_redraw()

func _draw_cards() -> void:
	var font := ThemeDB.fallback_font
	var y := 0.0
	for i in main.party.members.size():
		var m: PartyMember = main.party.members[i]
		var sel: bool = main.party.selection.has(m)
		var h := 64.0
		cards.draw_rect(Rect2(0, y, 280, h), PANEL)
		if sel:
			cards.draw_rect(Rect2(0, y, 280, h), GOLD, false, 2.0)
		cards.draw_string(font, Vector2(10, y + 18), "%d  %s" % [i + 1, m.display_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD if sel else INK)
		cards.draw_string(font, Vector2(150, y + 18), "DOWN" if m.downed else m.role, HORIZONTAL_ALIGNMENT_RIGHT, 120, 12, Color(0.9, 0.4, 0.35) if m.downed else MUTED)
		_bar(Vector2(10, y + 26), 260, m.hp / m.max_hp, Color(0.75, 0.22, 0.2), "%d/%d" % [int(m.hp), int(m.max_hp)])
		_bar(Vector2(10, y + 36), 260, m.stamina / m.max_stamina, Color(0.75, 0.62, 0.25), "")
		var x := 10.0
		for s in m.abilities.size():
			var id: String = m.abilities[s]
			var a := Abilities.get_def(id)
			var cd: float = m.ability_cd.get(id, 0.0)
			var ready := m.can_use(id)
			var label := "%s %s" % ["QE"[s], a.name]
			if cd > 0.0:
				label += " %.0fs" % ceilf(cd)
			cards.draw_string(font, Vector2(x, y + 57), label, HORIZONTAL_ALIGNMENT_LEFT, 130, 12, INK if ready else Color(0.5, 0.5, 0.5))
			x += 132.0
		y += h + 6.0

func _bar(p: Vector2, w: float, frac: float, col: Color, text: String) -> void:
	cards.draw_rect(Rect2(p, Vector2(w, 7)), Color(0, 0, 0, 0.6))
	cards.draw_rect(Rect2(p, Vector2(w * clampf(frac, 0.0, 1.0), 7)), col)
	if text != "":
		cards.draw_string(ThemeDB.fallback_font, p + Vector2(w - 60, -1), text, HORIZONTAL_ALIGNMENT_RIGHT, 60, 10, INK)
