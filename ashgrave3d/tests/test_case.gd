class_name TestCase
extends RefCounted

var tree: SceneTree
var _fail := ""

func check(cond: bool, msg: String) -> void:
	if not cond and _fail == "":
		_fail = msg
