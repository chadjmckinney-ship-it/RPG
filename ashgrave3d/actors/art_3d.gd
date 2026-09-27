class_name Art3D
extends RefCounted
## Which model each creature uses, and how its stand-in mannequin looks until your .glb exists
## (characters/<model>/<model>.glb). size scales the whole body.

const CREATURES := {
	"risen": {"model": "risen", "tint": Color("d8d2c0"), "size": 1.0},
	"revenant": {"model": "revenant", "tint": Color("c8d8e0"), "size": 1.0},
	"barrow_lord": {"model": "barrow_lord", "tint": Color("9aa8a8"), "size": 1.35},
	"ghoul": {"model": "ghoul", "tint": Color("7a8070"), "size": 0.95},
	"wight": {"model": "wight", "tint": Color("4a6048"), "size": 1.05},
	"hound": {"model": "hound", "tint": Color("2a2a30"), "size": 0.7},
	"lurker": {"model": "lurker", "tint": Color("3e5a34"), "size": 1.0},
	"boar": {"model": "boar", "tint": Color("5a4030"), "size": 1.0},   # the .glb is already 1.87 m
	"crows": {"model": "crows", "tint": Color("50504c"), "size": 0.6},
	"bandit": {"model": "bandit", "tint": Color("6a4a34"), "size": 1.0},
	"crossbow": {"model": "crossbow", "tint": Color("5a4a3a"), "size": 1.0},
	"cultist": {"model": "cultist", "tint": Color("4a1a1c"), "size": 1.0},
	"ash_knight": {"model": "ash_knight", "tint": Color("2a2624"), "size": 1.25},
}

static func creature(type: String) -> Dictionary:
	return CREATURES.get(type, {"model": type, "tint": Color.GRAY, "size": 1.0})
