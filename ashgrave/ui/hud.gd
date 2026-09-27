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
var tracker: Label
var arrow: Control

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
	info.text = "Right: move / attack / talk   Shift+Right: queue   Q/E/R: abilities   Space: pause   I: pack   J: quests   M: map   Esc: menu"
	info.add_theme_font_size_override("font_size", UiTheme.fs(12))
	log_label = _label(15, INK)
	log_label.anchor_top = 1.0
	log_label.anchor_bottom = 1.0
	log_label.offset_left = 16
	log_label.offset_top = -170
	log_label.offset_right = 600
	log_label.offset_bottom = -34
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	banner = _label(24, GOLD)
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
	tracker = _label(15, Color("d8c8a0"))
	tracker.anchor_left = 1.0
	tracker.anchor_right = 1.0
	tracker.offset_left = -420
	tracker.offset_right = -16
	tracker.offset_top = 96
	tracker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arrow = Control.new()
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.draw.connect(_draw_arrow)
	add_child(arrow)

func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", UiTheme.fs(size))
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
	banner.text = "PAUSED — give orders, Space to resume" if TacticalPause.paused and not main.panels.is_open() else ""
	cards.queue_redraw()
	arrow.queue_redraw()
	var q: Dictionary = GameState.quests.get(GameState.tracked, {})
	tracker.text = "" if q.is_empty() or q.status != "active" else "%s\n%s\n(J: quests)" % [q.title, QuestLog.current(q).text]

func _draw_cards() -> void:
	var font := UiTheme.font()
	var y := 0.0
	for i in main.party.members.size():
		var m: PartyMember = main.party.members[i]
		var sel: bool = main.party.selection.has(m)
		var h := 64.0
		cards.draw_rect(Rect2(0, y, 346, h), PANEL)
		Portraits.draw_actor(cards, m, Rect2(4, y + 4, 56, 56))
		if sel:
			cards.draw_rect(Rect2(0, y, 346, h), GOLD, false, 2.0)
		cards.draw_set_transform(Vector2(62, 0))
		cards.draw_string(font, Vector2(10, y + 17), "%d  %s" % [i + 1, m.display_name], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.fs(15), GOLD if sel else INK)
		var talent_ready := Talents.pending_tier(m.companion_id, Progression.level()) >= 0
		var tag: String = "DOWN" if m.downed else ("▲ talent ready" if talent_ready else m.role)
		cards.draw_string(font, Vector2(90, y + 17), tag, HORIZONTAL_ALIGNMENT_RIGHT, 180, UiTheme.fs(12), Color(0.9, 0.4, 0.35) if m.downed else (GOLD if talent_ready else MUTED))
		_bar(Vector2(10, y + 23), 260, m.hp / m.max_hp, Color(0.75, 0.22, 0.2), "%d/%d" % [int(m.hp), int(m.max_hp)], 11.0)
		_bar(Vector2(10, y + 37), 260, m.stamina / m.max_stamina, Color(0.75, 0.62, 0.25), "")
		var x := 10.0
		var step := 132.0 if m.abilities.size() <= 2 else 92.0
		for s in m.abilities.size():
			var id: String = m.abilities[s]
			var a := Abilities.effective(m, id)
			var cd: float = m.ability_cd.get(id, 0.0)
			var ready := m.can_use(id)
			var label := "%s %s" % ["QER"[s], a.name]
			if cd > 0.0:
				label += " %.0fs" % ceilf(cd)
			cards.draw_string(font, Vector2(x, y + 57), label, HORIZONTAL_ALIGNMENT_LEFT, step - 2.0, UiTheme.fs(12), INK if ready else Color(0.5, 0.5, 0.5))
			x += step
		cards.draw_set_transform(Vector2.ZERO)
		y += h + 6.0
	# company level and XP
	var lv := Progression.level()
	var need := Progression.xp_for_next()
	cards.draw_rect(Rect2(0, y, 346, 20), PANEL)
	cards.draw_string(font, Vector2(8, y + 15), "Lv %d" % lv, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.fs(13), GOLD)
	cards.draw_rect(Rect2(56, y + 7, 280, 6), Color(0, 0, 0, 0.6))
	cards.draw_rect(Rect2(56, y + 7, 280.0 * (1.0 if need == 0 else float(Progression.xp_into_level()) / need), 6), GOLD.darkened(0.15))

func _bar(p: Vector2, w: float, frac: float, col: Color, text: String, h := 7.0) -> void:
	cards.draw_rect(Rect2(p, Vector2(w, h)), Color(0, 0, 0, 0.6))
	cards.draw_rect(Rect2(p, Vector2(w * clampf(frac, 0.0, 1.0), h)), col)
	if text != "":
		cards.draw_string(UiTheme.font(), p + Vector2(w - 64, h - 1), text, HORIZONTAL_ALIGNMENT_RIGHT, 60, UiTheme.fs(9), INK)

## Objective marker: a diamond on the target if visible, else an arrow at the screen edge.
func _draw_arrow() -> void:
	var q: Dictionary = GameState.quests.get(GameState.tracked, {})
	if q.is_empty() or q.status != "active":
		return
	var cell = QuestLog.target_cell(q)
	if cell == null:
		return
	var world_pos: Vector2 = main.ground.map_to_local(cell)
	var screen: Vector2 = main.get_viewport().get_canvas_transform() * world_pos
	var size := arrow.get_viewport_rect().size
	var col := Color(0.95, 0.75, 0.35, 0.9)
	var margin := 40.0
	var dist := int(main.party.leader().cell_distance(cell))
	if Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2).has_point(screen):
		arrow.draw_colored_polygon(PackedVector2Array([screen + Vector2(0, -60), screen + Vector2(8, -50), screen + Vector2(0, -40), screen + Vector2(-8, -50)]), col)
		return
	var center := size / 2.0
	var dir := (screen - center).normalized()
	var t := minf((size.x / 2.0 - margin) / maxf(absf(dir.x), 0.001), (size.y / 2.0 - margin) / maxf(absf(dir.y), 0.001))
	var p := center + dir * t
	var side := dir.orthogonal() * 10.0
	arrow.draw_colored_polygon(PackedVector2Array([p + dir * 16.0, p - dir * 8.0 + side, p - dir * 8.0 - side]), col)
	arrow.draw_string(UiTheme.font(), p - dir * 34.0 - Vector2(20, -5), "%d" % dist, HORIZONTAL_ALIGNMENT_CENTER, 40, UiTheme.fs(13), col)
