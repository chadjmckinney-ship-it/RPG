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

func test_flare_creatures_resolve() -> void:
	for t in CreatureDefs.DEFS:
		check(ArtMap.CREATURES.has(t), "creature %s has no art mapping" % t)
	var keys := {"cursed_grave": true}
	for t in ArtMap.CREATURES:
		if ArtMap.CREATURES[t].has("flare"):
			keys[ArtMap.CREATURES[t].flare] = true
	for k in keys:
		var s := FlareSprite.new()
		s.setup(k)
		check(s._sprite.texture != null, "no atlas for %s" % k)
		var anims: Dictionary = s.data.get("anims", {})
		check(anims.has("idle"), "%s has no idle" % k)
		for name in anims:
			var dirs: Array = anims[name].dirs
			check(dirs.size() == 8, "%s %s has %d directions" % [k, name, dirs.size()])
			for d in dirs:
				check(not d.is_empty(), "%s %s has an empty direction" % [k, name])
				for f in d:
					check(f[0] + f[2] <= s._sprite.texture.get_width() and f[1] + f[3] <= s._sprite.texture.get_height(), "%s %s frame outside atlas" % [k, name])
		if k != "cursed_grave":
			for name in ["walk", "attack", "die"]:
				check(anims.has(name), "%s lacks %s" % [k, name])
		s.free()

func test_direction_mapping() -> void:
	check(FlareSprite.dir_index(Vector2.LEFT) == 0 and FlareSprite.dir_index(Vector2.UP) == 2, "flare W/N wrong")
	check(FlareSprite.dir_index(Vector2.RIGHT) == 4 and FlareSprite.dir_index(Vector2.DOWN) == 6, "flare E/S wrong")
	check(FlareSprite.dir_index(Vector2(-1, 1)) == 7, "flare SW wrong")

func test_credits_cover_the_art() -> void:
	check(FileAccess.file_exists("res://art/CREDITS.md"), "no CREDITS.md")
	var csv := FileAccess.get_file_as_string("res://art/lpc/CREDITS_LPC.csv")
	check(csv.count("\n") > 50, "LPC credits look empty")
	check(FileAccess.file_exists("res://art/flare/LICENSE_CC-BY-SA-3.0.txt"), "Flare license missing")
