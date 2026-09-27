shader_type spatial;
// Stand-in props (vertex-coloured). Fragments between the camera and a party member are
// dithered away, so trees and houses never hide the party.

uniform vec3 members[4];
uniform int member_count = 0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float bayer(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[i.y * 4 + i.x]) / 16.0;
}

void fragment() {
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float fade = 0.0;
	for (int i = 0; i < member_count; i++) {
		vec3 target = members[i] + vec3(0.0, 0.9, 0.0);
		vec3 seg = target - cam;
		float t = clamp(dot(wpos - cam, seg) / dot(seg, seg), 0.0, 1.0);
		float d = length(wpos - (cam + seg * t));
		if (t < 0.97) {
			fade = max(fade, 1.0 - smoothstep(1.2, 2.2, d));
		}
	}
	if (fade * 0.8 > bayer(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
}
