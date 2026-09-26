shader_type canvas_item;
// Paints the whole isometric ground from a terrain-id map: world-aligned pixel-art fills,
// ragged (noise-warped) borders between terrains, earth banks and a foam line at water.
// Cell maths mirror TileMapLayer.map_to_local for DIAMOND_DOWN 128x64:
//     local = ((x - y) * 64 + 64, (x + y) * 32 + 32)

uniform sampler2D terrain_map : filter_nearest, repeat_disable;   // R8, id / 255
uniform sampler2D fills : filter_nearest, repeat_disable;         // 128px fill per terrain, in id order
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float terrain_count = 8.0;
uniform int map_size = 512;
uniform float warp = 38.0;

const int WATER = 0;
const int ROCK = 5;
const int ROAD = 6;
const int ASH = 7;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

int terrain(vec2 p) {
	float u = (p.x - 64.0) / 64.0;
	float v = (p.y - 32.0) / 32.0;
	ivec2 c = ivec2(round(vec2((u + v) * 0.5, (v - u) * 0.5)));
	if (c.x < 0 || c.y < 0 || c.x >= map_size || c.y >= map_size) {
		return WATER;
	}
	return int(texelFetch(terrain_map, c, 0).r * 255.0 + 0.5);
}

// Higher wins when borders are warped: grass spills over dirt, not the reverse.
float priority(int t) {
	if (t == WATER) return 0.0;
	if (t == ROAD) return 1.0;
	if (t == ASH) return 2.0;
	if (t == ROCK) return 3.0;
	return 4.0;
}

vec2 warped(vec2 p) {
	vec2 n = vec2(texture(noise, p / 420.0).r, texture(noise, p / 420.0 + vec2(0.37, 0.71)).r) - 0.5;
	vec2 f = vec2(texture(noise, p / 90.0 + vec2(0.13, 0.5)).r, texture(noise, p / 90.0 + vec2(0.61, 0.2)).r) - 0.5;
	return p + n * warp * 2.0 + f * 10.0;
}

vec3 fill(int t, vec2 ap) {
	vec2 uv = vec2(float(t) * 128.0 + mod(ap.x, 128.0) + 0.5, mod(ap.y, 128.0) + 0.5);
	return texture(fills, uv / vec2(128.0 * terrain_count, 128.0)).rgb;
}

void fragment() {
	vec2 ap = floor(world / 2.0);          // art pixel (art is drawn at 2x)
	vec2 p = ap * 2.0 + 1.0;
	int t = terrain(warped(p));
	vec3 col = fill(t, ap);
	// neighbours a few art pixels away decide banks and edge shading
	int n1 = terrain(warped(p + vec2(8.0, 0.0)));
	int n2 = terrain(warped(p - vec2(8.0, 0.0)));
	int n3 = terrain(warped(p + vec2(0.0, 6.0)));
	int n4 = terrain(warped(p - vec2(0.0, 6.0)));
	bool water_near = n1 == WATER || n2 == WATER || n3 == WATER || n4 == WATER;
	if (t == WATER) {
		bool land_near = n1 != WATER || n2 != WATER || n3 != WATER || n4 != WATER;
		if (land_near) {
			col = mix(col, vec3(0.42, 0.47, 0.45), 0.35);      // pale foam line at the shore
		}
		float glint = texture(noise, p / 60.0 + vec2(floor(TIME * 3.0) * 0.013, 0.0)).r;
		if (glint > 0.72) {
			col += vec3(0.05, 0.07, 0.08);
		}
	} else if (water_near) {
		col = vec3(0.19, 0.15, 0.11) + col * 0.25;              // dark earth bank
	} else {
		float pr = priority(t);
		if (priority(n1) > pr || priority(n2) > pr || priority(n3) > pr || priority(n4) > pr) {
			col *= 0.78;                                         // shade under overhanging grass
		}
	}
	// large soft mottling, stepped so it stays pixel-art
	float m = texture(noise, p / 1500.0 + vec2(0.3, 0.9)).r;
	col *= 0.84 + floor(m * 6.0) / 6.0 * 0.3;
	COLOR = vec4(col, 1.0) * COLOR;
}
