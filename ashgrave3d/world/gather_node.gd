class_name GatherNode
extends Node3D
## A harvestable spot (bitterroot, iron seam, deadwood, ashbloom). Right-click to send someone
## to gather. Picked-clean nodes turn grey until they regrow.

var data: Dictionary = {}   # {id, kind, cell}
var cell := Vector2i.ZERO
var _bright: Array[MeshInstance3D] = []   # the bits that show it's ready (flowers, ore, embers)
var _was_ready := true

func display_name() -> String:
	return Gathering.KINDS[data.kind].name

func ready_to_harvest() -> bool:
	return Gathering.available(data.id, TimeOfDay.day)

func on_interact(who) -> void:
	var got := Gathering.harvest(data, TimeOfDay.day)
	if got.is_empty():
		Events.combat_message.emit("%s is picked clean. It will recover in a day or two." % display_name())
	else:
		Audio.play("gather")
		Events.combat_message.emit("%s gathers %d %s." % [who.display_name, got.count, Items.item_name(got.item)])
	_refresh()

func _ready() -> void:
	cell = data.cell
	var h := float(absi(hash(data.id)) % 1000) / 1000.0
	rotation.y = h * TAU
	match data.kind:
		"herb":
			for i in 5:
				var a := TAU * i / 5.0 + h
				Shapes.add(self, Shapes.sphere(0.16, 6), Vector3(cos(a) * 0.22, 0.1, sin(a) * 0.22), Color("3e5a2a"), Vector3(1, 0.7, 1))
				_bright.append(Shapes.add(self, Shapes.sphere(0.05, 6), Vector3(cos(a) * 0.22, 0.24, sin(a) * 0.22), Color("e0c860"), Vector3.ONE, Vector3.ZERO, 0.4))
		"ore":
			Shapes.add(self, Shapes.sphere(0.45, 7), Vector3(0, 0.15, 0), Color("5a5550"), Vector3(1.2, 0.8, 1.0))
			Shapes.add(self, Shapes.sphere(0.25, 6), Vector3(0.4, 0.08, 0.2), Color("4e4a46"))
			for p in [Vector3(0.15, 0.45, 0.25), Vector3(-0.25, 0.35, 0.3), Vector3(0.3, 0.3, -0.25)]:
				_bright.append(Shapes.add(self, Shapes.box(Vector3(0.12, 0.08, 0.12)), p, Color("c07a3a"), Vector3.ONE, Vector3(0.5, 0.3, 0.2), 0.25))
		"wood":
			Shapes.add(self, Shapes.cyl(0.14, 0.16, 1.4, 7), Vector3(0, 0.15, 0), Color("4a3a2a"), Vector3.ONE, Vector3(0, 0, PI / 2))
			Shapes.add(self, Shapes.cyl(0.1, 0.12, 0.9, 7), Vector3(0.1, 0.12, 0.3), Color("54422e"), Vector3.ONE, Vector3(0, 0.6, PI / 2))
			_bright.append(Shapes.add(self, Shapes.sphere(0.08, 6), Vector3(-0.3, 0.3, 0.0), Color("7a8a4a")))
		"ash":
			Shapes.add(self, Shapes.cyl(0.18, 0.26, 0.5, 7), Vector3(0, 0.25, 0), Color("222020"))
			for i in 3:
				var a := TAU * i / 3.0
				_bright.append(Shapes.add(self, Shapes.sphere(0.07, 6), Vector3(cos(a) * 0.28, 0.08, sin(a) * 0.28), Color("ff6a2a"), Vector3.ONE, Vector3.ZERO, 2.5))
	_refresh()

func _process(_d: float) -> void:
	if ready_to_harvest() != _was_ready:
		_refresh()
	if data.kind == "ash" and _was_ready:
		var t := Time.get_ticks_msec() / 400.0
		for i in _bright.size():
			_bright[i].scale = Vector3.ONE * (0.8 + 0.3 * sin(t + i * 2.0))

func _refresh() -> void:
	_was_ready = ready_to_harvest()
	for b in _bright:
		b.visible = _was_ready
