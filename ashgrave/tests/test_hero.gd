extends TestCase
## Maren's rendered model (HeroSprite, art from tools/render_hero.py).

func test_facing_from_screen_direction() -> void:
	check(HeroSprite.facing(Vector2.RIGHT) == 0, "east should be facing 0")
	check(HeroSprite.facing(Vector2.UP) == 2, "up the screen should be facing 2 (away)")
	check(HeroSprite.facing(Vector2.LEFT) == 4, "west should be facing 4")
	check(HeroSprite.facing(Vector2.DOWN) == 6, "down the screen should be facing 6 (towards the viewer)")
	# a step along a map axis is a 2:1 diagonal on screen and uses the diagonal renders
	check(HeroSprite.facing(Vector2(2, 1).normalized()) == 7, "map +x should face south-east")
	check(HeroSprite.facing(Vector2(-2, -1).normalized()) == 3, "map -x should face north-west")
	check(HeroSprite.facing(Vector2(-2, 1).normalized()) == 5, "map +y should face south-west")

func test_only_maren_has_a_model() -> void:
	for id in ["oswin", "ketta"]:
		check(ArtMap.hero_variant(id, {"weapon": "", "armor": ""}) == "", "%s should keep LPC art" % id)
	# whatever art is present, Maren's look is either her model or her LPC sprite, never nothing
	var m := PartyMember.new()
	m.companion_id = "maren"
	m.refresh_look()
	check(m.sprite is HeroSprite or m.sprite is LpcSprite, "Maren has no sprite")
	check(Portraits.character_of(m) != "", "Maren has no portrait")
	m.free()
