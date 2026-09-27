shader_type canvas_item;
// Dark outline around character sprites, plus an optional rim glow (gold for the selected
// member, red for a targeted enemy). LPC art is drawn at 2x, so its 1-texel outline is 2 screen
// pixels; the hero is drawn 1:1 and asks for width 2 to match.

uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.04, 0.85);
uniform vec4 rim : source_color = vec4(0.0);
uniform float width = 1.0;   // texels: 1 or 2

varying vec4 tint;   // vertex colour (modulate); fragment COLOR already includes the texture

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	if (width > 1.5) {
		n += texture(TEXTURE, UV + vec2(2.0 * px.x, 0.0)).a + texture(TEXTURE, UV - vec2(2.0 * px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, 2.0 * px.y)).a + texture(TEXTURE, UV - vec2(0.0, 2.0 * px.y)).a
			+ texture(TEXTURE, UV + px).a + texture(TEXTURE, UV - px).a
			+ texture(TEXTURE, UV + vec2(px.x, -px.y)).a + texture(TEXTURE, UV + vec2(-px.x, px.y)).a;
	}
	if (c.a < 0.1 && n > 0.0) {
		// outline pixel; a rim colour replaces the dark line when set
		c = rim.a > 0.0 ? vec4(rim.rgb, rim.a) : outline_color;
	}
	COLOR = c * tint;
}
