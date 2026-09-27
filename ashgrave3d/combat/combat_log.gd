class_name CombatLog
extends RefCounted
## Rolling log of recent combat messages.

const MAX := 6
var lines: Array[String] = []

func add(text: String) -> void:
	lines.append(text)
	while lines.size() > MAX:
		lines.pop_front()
