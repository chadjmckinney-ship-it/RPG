extends Node
## Persistent game state. Save/load arrives in Milestone 3; for now it owns the world seed.

var world_seed: int = 1337
var world: WorldGen

func new_world(seed_value: int = -1) -> void:
	world_seed = seed_value if seed_value >= 0 else randi() % 1_000_000
	world = WorldGen.new(world_seed)
