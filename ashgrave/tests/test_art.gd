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
	check(FileAccess.file_exists("res://art/flare/LICENSE_CC-BY-SA-3.0.txt"), "Flare license missing")
