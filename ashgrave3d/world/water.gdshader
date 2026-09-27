shader_type spatial;
render_mode cull_disabled;
// Dark, slightly moving water with a fresnel sheen.

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.05, 0.09, 0.11);
uniform vec3 shallow : source_color = vec3(0.12, 0.2, 0.22);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / 14.0;
	float a = texture(noise, uv + vec2(TIME * 0.01, 0.0)).r;
	float b = texture(noise, uv * 1.7 - vec2(0.0, TIME * 0.013)).r;
	float w = (a + b) * 0.5;
	ALBEDO = mix(deep, shallow, w);
	NORMAL_MAP = normalize(vec3((a - 0.5) * 0.6, (b - 0.5) * 0.6, 1.0)) * 0.5 + 0.5;
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = 0.88;
}
