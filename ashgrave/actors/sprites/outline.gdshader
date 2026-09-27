shader_type canvas_item;
// 1 px (art pixel) dark outline around LPC sprites, plus an optional rim glow
// (gold for the selected member, red for a targeted enemy).

uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.04, 0.85);
uniform vec4 rim : source_color = vec4(0.0);

varying vec4 tint;   // vertex colour (modulate); fragment COLOR already includes the texture

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	if (c.a < 0.1 && n > 0.0) {
		// outline pixel; a rim colour replaces the dark line when set
		c = rim.a > 0.0 ? vec4(rim.rgb, rim.a) : outline_color;
	}
	COLOR = c * tint;
}
