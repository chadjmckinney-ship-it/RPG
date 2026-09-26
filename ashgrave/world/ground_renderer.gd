class_name GroundRenderer
extends Node2D
## Draws the ground with ground.gdshader from a terrain-id map of the whole world.
## Chunks write their cells into the map as they stream in.

var world: WorldGen
var map_image: Image
var map_texture: ImageTexture
var _dirty := false

func setup(w: WorldGen) -> void:
	world = w
	map_image = Image.create(WorldGen.SIZE, WorldGen.SIZE, false, Image.FORMAT_R8)
	map_texture = ImageTexture.create_from_image(map_image)
	var noise := FastNoiseLite.new()
	noise.seed = w.seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var noise_tex := ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/ground.gdshader")
	mat.set_shader_parameter("terrain_map", map_texture)
	mat.set_shader_parameter("fills", load("res://art/world/ground.png"))
	mat.set_shader_parameter("noise", noise_tex)
	mat.set_shader_parameter("terrain_count", float(WorldGen.Terrain.size()))
	mat.set_shader_parameter("map_size", WorldGen.SIZE)
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func set_terrain(c: Vector2i, t: int) -> void:
	map_image.set_pixel(c.x, c.y, Color8(t, 0, 0))
	_dirty = true

## Terrain id stored for a cell (what the shader sees).
func stored(c: Vector2i) -> int:
	return map_image.get_pixel(c.x, c.y).r8

func _process(_d: float) -> void:
	if _dirty:
		map_texture.update(map_image)
		_dirty = false

func _draw() -> void:
	# One quad over the world's isometric bounds (plus a margin of sea).
	var half := WorldGen.SIZE * WorldGen.TILE_W / 2.0
	var margin := 2048.0
	draw_rect(Rect2(-half - margin, -margin, half * 2.0 + WorldGen.TILE_W + margin * 2.0, WorldGen.SIZE * WorldGen.TILE_H + margin * 2.0), Color.WHITE)
