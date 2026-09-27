extends TestCase
## Every character and creature resolves to real art with complete animations.

func test_lpc_characters_resolve() -> void:
	var meta := LpcSprite.meta()
	check(not meta.is_empty(), "layout.json missing")
	var needed := {}
	for id in ["maren", "oswin", "ketta"]:
		for armor in ["", "hide-jerkin", "iron-mail", "penitent-robes"]:
			needed[ArtMap.member_look(id, {"armor": armor, "weapon": ""})[0]] = true
	for t in ArtMap.CREATURES:
		if ArtMap.CREATURES[t].has("lpc"):
			needed[ArtMap.CREATURES[t].lpc] = true
	for id in ["maud", "nessa", "harl", "smith", "keeper", "villager_f1", "villager_f2", "villager_m1", "villager_m2"]:
		needed[id] = true
	for id in needed:
		check(meta.characters.has(id), "no baked LPC character %s" % id)
		var tex := LpcSprite.tex("res://art/lpc/chars/%s.png" % id)
		check(tex != null, "missing atlas for %s" % id)
		if tex:
			check(tex.get_width() == int(meta.width) and tex.get_height() == int(meta.height), "%s atlas has the wrong size" % id)
	for w in meta.weapons:
		for body in ["female", "male"]:
			for side in ["front", "behind"]:
				check(LpcSprite.tex("res://art/lpc/weapons/%s_%s_%s.png" % [w, body, side]) != null, "missing weapon art %s %s %s" % [w, body, side])
	for a in meta.layout.values():
		check(int(a.y) + int(a.size) * int(a.rows) <= int(meta.height), "animation rows run past the atlas")
		check(int(a.size) * int(a.frames) <= int(meta.width), "animation frames run past the atlas")

func test_gear_changes_the_sprite() -> void:
	check(ArtMap.member_look("maren", {"armor": "iron-mail", "weapon": ""})[0] == "maren_mail", "mail doesn't show on Maren")
	check(ArtMap.member_look("ketta", {"armor": "", "weapon": "militia-spear"})[1] == "spear", "spear doesn't show")
	check(ArtMap.member_look("oswin", {"armor": "", "weapon": ""})[1] == "mace", "Oswin lost his mace")

func test_every_creature_has_lpc_art() -> void:
	var meta := LpcSprite.meta()
	for t in CreatureDefs.DEFS:
		check(ArtMap.CREATURES.has(t), "creature %s has no art mapping" % t)
		if ArtMap.CREATURES.has(t):
			var a: Dictionary = ArtMap.CREATURES[t]
			check(meta.characters.has(a.lpc), "creature %s maps to missing art %s" % [t, a.lpc])
			if a.weapon != "":
				check(meta.weapons.has(a.weapon), "creature %s uses missing weapon %s" % [t, a.weapon])

func test_credits_cover_the_art() -> void:
	check(FileAccess.file_exists("res://art/CREDITS.md"), "no CREDITS.md")
	var csv := FileAccess.get_file_as_string("res://art/lpc/CREDITS_LPC.csv")
	check(csv.count("\n") > 50, "LPC credits look empty")
	check(not DirAccess.dir_exists_absolute("res://art/flare"), "Flare art should be gone")
	for f in ["OFL_Jersey10.txt", "OFL_UnifrakturCook.txt"]:
		check(FileAccess.file_exists("res://art/ui/fonts/" + f), "font licence %s missing" % f)

func test_every_item_has_an_icon() -> void:
	var tex: Texture2D = load("res://art/ui/icons.png")
	check(tex != null, "icons.png missing")
	for id in Items.DEFS:
		check(Icons.has(id), "item %s has no icon" % id)
		if Icons.has(id) and tex:
			var r := Icons.texture(id).region
			check(r.end.x <= tex.get_width() and r.end.y <= tex.get_height(), "icon %s runs past the atlas" % id)

func test_portraits_follow_the_sprite() -> void:
	check(Portraits.character_of(null) == "", "null actor should have no portrait")
	for armor in ["", "iron-mail"]:
		var look: Array = ArtMap.member_look("maren", {"armor": armor, "weapon": ""})
		check(LpcSprite.tex("res://art/lpc/chars/%s.png" % look[0]) != null, "no atlas behind the %s portrait" % look[0])
	var idle: Dictionary = LpcSprite.meta().layout.idle
	check(Portraits.BUST.end.x <= float(idle.size) and Portraits.BUST.end.y <= float(idle.size), "bust crop leaves the frame")

func test_ui_theme_uses_the_pixel_art() -> void:
	var t := UiTheme.get_theme()
	check(t.default_font != null and t.default_font.resource_path.ends_with("Jersey10.ttf"), "body font isn't Jersey 10")
	check(t.get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "panels aren't using the pixel frame")
	check(UiTheme.title_font() != null, "title font missing")

func test_new_animations_and_weapon_atlases() -> void:
	var meta := LpcSprite.meta()
	for a in ["run", "combat_idle"]:
		check(meta.layout.has(a), "layout lacks %s" % a)
	for a in ["slash_big", "slash_rev_big", "thrust_big"]:
		check(meta.weapon_layout.has(a) and meta.big_body.has(a), "weapon layout lacks %s" % a)
	for w in meta.weapons:
		var tex := LpcSprite.tex("res://art/lpc/weapons/%s_female_front.png" % w)
		check(tex != null and tex.get_width() == int(meta.weapon_width) and tex.get_height() == int(meta.weapon_height), "%s weapon atlas has the wrong size" % w)
		for move in meta.weapons[w].attacks:
			check(meta.weapon_layout.has(move), "%s attack %s has no rows" % [w, move])
	var s := LpcSprite.new()
	s.setup("maren", "longsword")
	var seen := {}
	for i in 3:
		s.play("attack", true)
		seen[s.source("attack")] = true
	check(seen.size() == 3, "longsword attacks should rotate through three moves, got %s" % [seen.keys()])
	s.play("walk")
	check(s.source("run") == "run" and s.source("ready") == "combat_idle", "run / stance not mapped")
	s.free()

func test_villagers_vary_by_faction() -> void:
	var meta := LpcSprite.meta()
	for f in ["church", "companies", "hollow"]:
		var n: int = meta.characters.keys().filter(func(k): return k.begins_with("villager_%s_" % f)).size()
		check(n >= 4, "only %d villager looks for %s" % [n, f])
	var v := Villager.new()
	v.village = {"faction": "church", "id": "v0_0"}
	v.npc_id = "v0_0:villager1"
	check(ArtMap.villager_look(v)[0].begins_with("villager_church_"), "church villager not dressed for the church")
	v.free()
