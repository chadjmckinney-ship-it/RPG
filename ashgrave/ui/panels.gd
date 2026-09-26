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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.065, 0.06, 0.95)
	sb.border_color = Color("6a5a3a")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	root.add_theme_stylebox_override("panel", sb)
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
	if mode != "" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_all()
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
		for t in [["pack", "Items"], ["gear", "Gear"], ["craft", "Crafting"], ["factions", "Factions"]]:
			var b := Button.new()
			b.text = t[1]
			b.toggle_mode = true
			b.button_pressed = tab == t[0]
			b.pressed.connect(func(): tab = t[0]; refresh())
			tabs.add_child(b)
		call("_tab_" + tab)
	elif mode == "trade":
		_trade()

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
