shader_type canvas_item;
// Makes props and buildings see-through around party members standing behind them.
// Positions are world-space feet; `front_y` < 0 disables the "only if in front" test (tile layers).

uniform vec2 members[4];
uniform int member_count = 0;
uniform float front_y = -1.0;

varying vec2 world;
varying float origin_y;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	origin_y = MODEL_MATRIX[3].y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	for (int i = 0; i < member_count; i++) {
		if (front_y >= 0.0 && origin_y < members[i].y) {
			continue;   // this sprite is behind the member; the member is drawn over it anyway
		}
		vec2 d = (world - (members[i] + vec2(0.0, -64.0))) / vec2(56.0, 84.0);
		float r = dot(d, d);
		if (r < 1.0 && world.y < members[i].y + 8.0) {
			c.a *= r < 0.6 ? 0.35 : 0.6;
		}
	}
	COLOR = c;
}
