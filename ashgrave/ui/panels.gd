class_name Panels
extends CanvasLayer
## Modal screens built in code: the party pack (items, gear, crafting, factions) and trading.
## Opening one tactically pauses the game; closing restores the previous pause state.

const INK := Color("e8dfc8")
const MUTED := Color("a8a090")
const GOLD := Color("f0b04a")
const BAD := Color("d9695a")

var main: Node
var root: PanelContainer
var body: VBoxContainer
var title: Label
var tabs: HBoxContainer
var content: VBoxContainer
var mode := ""          # "" | pack | trade
var tab := "pack"
var trader: Villager
var dialogue: Dialogue
var note_text := ""
var _was_paused := false

func setup(m: Node) -> void:
	main = m
	layer = 20
	root = PanelContainer.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.5
	root.anchor_bottom = 0.5
	root.offset_left = -330
	root.offset_right = 330
	root.offset_top = -250
	root.offset_bottom = 250
	root.theme = UiTheme.get_theme()
	add_child(root)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	title = _label("", 20, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Close (Esc)"
	close.pressed.connect(close_all)
	head.add_child(close)
	tabs = HBoxContainer.new()
	body.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)
	root.visible = false
	GameState.inventory.changed.connect(_refresh_if_open)

func is_open() -> bool:
	return mode != ""

func toggle_pack() -> void:
	if mode == "pack":
		close_all()
	else:
		_open("pack")

func open_trade(v: Node) -> void:
	trader = v
	_open("trade")

func open_dialogue(v: Node) -> void:
	dialogue = Dialogue.new(v)
	trader = v
	_open("dialogue")

func open_menu() -> void:
	_open("menu")

func open_map() -> void:
	_open("map")

func open_quests() -> void:
	tab = "quests"
	_open("pack")

func show_note(text: String) -> void:
	note_text = text
	_open("note")

func _open(which: String) -> void:
	if mode == "":
		_was_paused = TacticalPause.paused
		TacticalPause.set_paused(true)
	mode = which
	root.visible = true
	Events.ui_opened.emit(true)
	refresh()

func close_all() -> void:
	if mode == "":
		return
	mode = ""
	root.visible = false
	TacticalPause.set_paused(_was_paused)
	Events.ui_opened.emit(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if mode != "":
			close_all()
			get_viewport().set_input_as_handled()
		elif main.party.targeting.is_empty():
			open_menu()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		if mode == "map":
			close_all()
		elif mode == "":
			open_map()
	elif mode == "dialogue" and event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		_pick(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()

func _refresh_if_open() -> void:
	if mode != "":
		refresh.call_deferred()

func refresh() -> void:
	# Inventory may have been replaced by a load; reconnect.
	if not GameState.inventory.changed.is_connected(_refresh_if_open):
		GameState.inventory.changed.connect(_refresh_if_open)
	for c in tabs.get_children():
		c.queue_free()
	for c in content.get_children():
		c.queue_free()
	if mode == "pack":
		title.text = "The company's pack — %d coin" % GameState.inventory.count("coin")
		for t in [["pack", "Items"], ["gear", "Gear"], ["craft", "Crafting"], ["quests", "Quests"], ["factions", "Factions"]]:
			var b := Button.new()
			b.text = t[1]
			b.toggle_mode = true
			b.button_pressed = tab == t[0]
			b.pressed.connect(func(): tab = t[0]; refresh())
			tabs.add_child(b)
		call("_tab_" + tab)
	elif mode == "trade":
		_trade()
	elif mode == "dialogue":
		_dialogue()
	elif mode == "menu":
		_menu()
	elif mode == "settings":
		_settings()
	elif mode == "map":
		_map()
	elif mode == "note":
		title.text = ""
		content.add_child(_label(note_text, 17, INK))
		var b := Button.new()
		b.text = "Continue"
		b.pressed.connect(close_all)
		content.add_child(b)

# ---------------------------------------------------------------- tabs

func _tab_pack() -> void:
	var inv := GameState.inventory
	var who: PartyMember = main.party.leader()
	_section("Consumables — used by %s" % who.display_name)
	for id in inv.ids_of_type("consumable"):
		var d := Items.get_def(id)
		_row("%s ×%d" % [d.name, inv.count(id)], d.get("desc", ""), "Use", func(): who.use_item(id, inv); refresh())
	_section("Materials")
	for id in inv.ids_of_type("material"):
		_row("%s ×%d" % [Items.item_name(id), inv.count(id)], "worth %d" % Items.get_def(id).value)
	_section("Spare gear")
	for id in inv.ids_of_type("gear"):
		_row("%s ×%d" % [Items.item_name(id), inv.count(id)], _bonus_text(id))
	if inv.counts.size() <= 1:
		content.add_child(_label("Gather herbs, ore and deadwood, or loot what you kill.", 14, MUTED))

func _tab_gear() -> void:
	var inv := GameState.inventory
	for m in main.party.members:
		_section("%s — ATK %d  DEF %d  HP %d" % [m.display_name, m.attack, m.defense, m.max_hp])
		for slot in ["weapon", "armor"]:
			var id: String = m.equipment[slot]
			if id == "":
				_row("%s: —" % slot.capitalize(), "")
			else:
				_row("%s: %s" % [slot.capitalize(), Items.item_name(id)], _bonus_text(id), "Remove", func(): m.unequip(slot, inv); refresh())
		for id in inv.ids_of_type("gear"):
			if Items.can_wield(m, id):
				_row("   %s" % Items.item_name(id), _bonus_text(id), "Equip", func(): m.equip(id, inv); refresh())

func _tab_craft() -> void:
	var st: Array = main.stations()
	_section("Stations here: %s" % (", ".join(st) if not st.is_empty() else "none (enemies nearby)"))
	var ids := Crafting.RECIPES.keys()
	ids.sort_custom(func(a, b): return Crafting.RECIPES[a].station < Crafting.RECIPES[b].station)
	for id in ids:
		var r: Dictionary = Crafting.RECIPES[id]
		var ok := Crafting.can_craft(GameState.inventory, id, st)
		var out := ("%d× " % r.out if r.out > 1 else "") + Items.item_name(id)
		var detail := "%s  [%s]" % [Crafting.describe(id), r.station]
		var do_craft := func():
			if Crafting.craft(GameState.inventory, id, main.stations()):
				Events.combat_message.emit("Crafted %s." % Items.item_name(id))
			refresh()
		_row(out, detail, "Craft", do_craft, not ok)

func _tab_quests() -> void:
	var list := GameState.quests.values()
	if list.is_empty():
		content.add_child(_label("No quests yet. Talk to Warden Maud, and ask traders for work.", 14, MUTED))
	for q in list.filter(func(q): return q.status == "active"):
		var tracked: bool = GameState.tracked == q.id
		var st: Dictionary = QuestLog.current(q)
		var extra := ""
		if st.obj.type == "kill_type":
			extra = " (%d/%d)" % [q.data.count, st.obj.count]
		var track := func(): GameState.tracked = q.id; refresh()
		_row(("▶ " if tracked else "") + q.title, st.text + extra, "Tracked" if tracked else "Track", track, tracked)
	var done := list.filter(func(q): return q.status == "done")
	if not done.is_empty():
		_section("Completed")
		for q in done:
			_row(q.title, "", "")
	_section("Companions")
	for id in ["oswin", "ketta"]:
		var d: Dictionary = Companions.DEFS[id]
		var status := "In the company" if GameState.recruited.has(id) else "Not met"
		_row(d.name, "%s · approval %+d" % [status, GameState.approval.get(id, 0)])

func _dialogue() -> void:
	var n: Dictionary = dialogue.node
	title.text = n.speaker
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var face := Control.new()
	face.custom_minimum_size = Vector2(110, 110)
	var npc = dialogue.npc
	face.draw.connect(func(): Portraits.draw(face, npc.npc_id, Rect2(Vector2.ZERO, Vector2(110, 110)), npc.trader_faction()))
	row.add_child(face)
	var said := _label(n.text, 16, INK)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(said)
	content.add_child(row)
	content.add_child(HSeparator.new())
	for i in n.choices.size():
		var c: Dictionary = n.choices[i]
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, c.label]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not c.get("enabled", true)
		b.pressed.connect(_pick.bind(i))
		content.add_child(b)

func _pick(i: int) -> void:
	if not dialogue.choose(i):
		return
	Audio.play("click", 0.0)
	match dialogue.result:
		"end": close_all()
		"trade": open_trade(dialogue.npc)
		_: refresh()

func _tab_factions() -> void:
	for f in Factions.NAMES:
		var rep: int = GameState.reputation.get(f, 0)
		_row(Factions.NAMES[f], "%+d  %s" % [rep, Factions.standing(rep)])
	content.add_child(_label("Killing cultists pleases the Church and angers the Hollow Folk. Clearing camps near a village earns its faction's thanks.", 13, MUTED))

func _trade() -> void:
	var v := trader
	var f := v.trader_faction()
	var rep: int = GameState.reputation.get(f, 0)
	var inv := GameState.inventory
	title.text = "%s — %s (%s, %s)" % [v.display_name, v.village.name, Factions.NAMES[f], Factions.standing(rep)]
	if not v.is_trader():
		content.add_child(_label(_chatter(v), 15, INK))
		return
	if not Factions.will_trade(rep):
		content.add_child(_label("\"We don't deal with your kind. Move along, deserter.\"", 15, BAD))
		return
	_section("Buy — you have %d coin" % inv.count("coin"))
	for id in v.stock():
		var price := Factions.buy_price(Items.get_def(id).value, rep)
		var buy := func():
			if inv.remove("coin", price):
				Audio.play("coin", 0.0)
				inv.add(id)
				Events.combat_message.emit("Bought %s." % Items.item_name(id))
			refresh()
		var info: String = _bonus_text(id) if Items.get_def(id).type == "gear" else Items.get_def(id).get("desc", "")
		_row("%s — %d coin" % [Items.item_name(id), price], info, "Buy", buy, inv.count("coin") < price)
	_section("Sell")
	for id in inv.counts.keys():
		if id == "coin":
			continue
		var price := Factions.sell_price(Items.get_def(id).get("value", 1), rep)
		var sell := func():
			if inv.remove(id):
				Audio.play("coin", 0.0)
				inv.add("coin", price)
			refresh()
		_row("%s ×%d — %d coin each" % [Items.item_name(id), inv.count(id), price], "", "Sell", sell)

func _chatter(v: Villager) -> String:
	var lines := {
		"church": "\"The Tithe-priests say the dead walk because we stopped paying. Maybe they're right.\"",
		"companies": "\"Free Company coin keeps the walls up. Don't make trouble and it'll keep you alive too.\"",
		"hollow": "\"Leave an offering at the barrow stones and the risen pass you by. Usually.\"",
	}
	return "%s\n\n%s's %s is at the forge; the tavern keeper sells remedies." % [lines.get(v.trader_faction(), "\"...\""), v.village.name, "smith"]

# ---------------------------------------------------------------- widgets

func _bonus_text(id: String) -> String:
	var b: Dictionary = Items.get_def(id).get("bonus", {})
	var parts: Array[String] = []
	for k in b:
		parts.append("%s %+d" % [{"attack": "ATK", "defense": "DEF", "max_hp": "HP", "speed": "SPD", "max_stamina": "STA"}.get(k, k), b[k]])
	var style: String = Items.get_def(id).get("style", "")
	if style != "":
		parts.append(style)
	return ", ".join(parts)

func _section(text: String) -> void:
	var l := _label(text, 15, GOLD)
	content.add_child(l)

func _row(text: String, detail: String, action := "", cb: Callable = Callable(), disabled := false) -> void:
	var h := HBoxContainer.new()
	var l := _label(text, 14, INK)
	l.custom_minimum_size.x = 250
	h.add_child(l)
	var d := _label(detail, 13, MUTED)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(d)
	if action != "":
		var b := Button.new()
		b.text = action
		b.disabled = disabled
		b.pressed.connect(cb)
		h.add_child(b)
	content.add_child(h)

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

# ---------------------------------------------------------------- menu, settings, map

func _menu() -> void:
	title.text = "Ashgrave — day %d, %s" % [TimeOfDay.day, TimeOfDay.clock_text()]
	var items := [
		["Resume", close_all],
		["Save game (F5)", func(): main.save_game(); close_all()],
		["Load last save (F9)", func(): close_all(); main.load_game()],
		["World map (M)", func(): mode = "map"; refresh()],
		["Quest log (J)", func(): tab = "quests"; mode = "pack"; refresh()],
		["Settings", func(): mode = "settings"; refresh()],
		["Quit to title", func(): close_all(); TacticalPause.set_paused(false); get_tree().change_scene_to_file("res://title.tscn")],
	]
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.pressed.connect(it[1])
		content.add_child(b)

func _settings() -> void:
	title.text = "Settings"
	for k in ["master", "music", "sfx"]:
		var h := HBoxContainer.new()
		var l := _label(k.capitalize() + " volume", 14, INK)
		l.custom_minimum_size.x = 200
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Audio.volume[k]
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.value_changed.connect(func(v): Audio.volume[k] = v; Settings.save())
		h.add_child(sl)
		content.add_child(h)
	for k in TacticalPause.settings:
		var cb := CheckBox.new()
		cb.text = {"on_enemy_spotted": "Pause when enemies spot the party", "on_low_health": "Pause when someone is badly hurt"}.get(k, k)
		cb.button_pressed = TacticalPause.settings[k]
		cb.toggled.connect(func(v): TacticalPause.settings[k] = v; Settings.save())
		content.add_child(cb)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): mode = "menu"; refresh())
	content.add_child(back)

func _map() -> void:
	title.text = "The province — M or Esc to close"
	var c := Control.new()
	c.custom_minimum_size = Vector2(630, 400)
	c.draw.connect(_draw_map.bind(c))
	content.add_child(c)

func _draw_map(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	var t := WorldMap.iso_transform(r)
	var w: WorldGen = main.world
	var s := float(WorldMap.SCALE)
	c.draw_set_transform_matrix(t * Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO))
	c.draw_texture(WorldMap.texture(w), Vector2.ZERO)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	var font := ThemeDB.fallback_font
	for v in w.villages():
		var p: Vector2 = t * Vector2(v.center)
		c.draw_string(font, p + Vector2(-40, -6), v.name, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, INK)
	var q: Dictionary = GameState.quests.get(GameState.tracked, {})
	if not q.is_empty() and q.status == "active":
		var cell = QuestLog.target_cell(q)
		if cell != null:
			var tp: Vector2 = t * Vector2(cell)
			c.draw_arc(tp, 7, 0, TAU, 16, GOLD, 2.0)
			c.draw_string(font, tp + Vector2(-60, 18), q.title, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, GOLD)
	var pp: Vector2 = t * Vector2(main.party.leader().cell)
	c.draw_circle(pp, 4, Color(0.95, 0.3, 0.25))
	c.draw_arc(pp, 7, 0, TAU, 16, Color(0.95, 0.3, 0.25), 1.5)
