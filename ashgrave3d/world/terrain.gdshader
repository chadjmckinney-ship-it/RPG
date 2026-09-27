shader_type spatial;
// Ground: per-vertex biome colour (blended between cell centres) with world-space noise detail,
// darker on steep slopes. Stand-in until real ground textures arrive.

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n1 = texture(noise, wpos.xz / 9.0).r;
	float n2 = texture(noise, wpos.xz / 1.7).r;
	vec3 c = COLOR.rgb * (0.78 + 0.28 * n1 + 0.14 * (n2 - 0.5));
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	c = mix(c, vec3(0.30, 0.28, 0.26) * (0.8 + 0.3 * n2), smoothstep(0.25, 0.6, slope));
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
