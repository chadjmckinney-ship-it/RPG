class_name Inventory
extends RefCounted
## The party's shared pack: item id -> count.

signal changed

var counts := {}

func count(id: String) -> int:
	return counts.get(id, 0)

func has(id: String, n := 1) -> bool:
	return count(id) >= n

func add(id: String, n := 1) -> void:
	if n <= 0:
		return
	counts[id] = count(id) + n
	changed.emit()

func remove(id: String, n := 1) -> bool:
	if not has(id, n):
		return false
	counts[id] -= n
	if counts[id] == 0:
		counts.erase(id)
	changed.emit()
	return true

func ids_of_type(t: String) -> Array:
	var out := counts.keys().filter(func(id): return Items.get_def(id).get("type") == t)
	out.sort()
	return out
