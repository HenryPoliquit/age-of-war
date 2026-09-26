shader_type canvas_item;
// Ground material per age with a worn lane road (ruts, pebbles), darkening with depth.
// kind: 0 dirt, 1 sand, 2 grass, 3 wet rock, 4 mud, 5 metal deck.
#include "res://shaders/common.gdshaderinc"

uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform vec4 road_color : source_color;
uniform vec4 accent : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform int kind = 0;
uniform float ground_y = 752.0;
uniform float time_s = 0.0;
uniform float seam = 0.5;
uniform float side = 0.0;
uniform bool opaque_left = true;
uniform float dissolve = 1.0;

varying vec2 wp;

void vertex() {
	wp = VERTEX;
}

void fragment() {
	float depth = clamp((wp.y - ground_y) / 380.0, 0.0, 1.0);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, depth);
	float big = fbm(wp * vec2(0.004, 0.012)) - 0.5;
	float mid = fbm(wp * vec2(0.02, 0.05)) - 0.5;
	float fine = vnoise(wp * 0.45) - 0.5;
	col *= 1.0 + big * 0.35 + mid * 0.22 + fine * 0.08;
	if (kind == 0) {
		// Packed dirt with scattered pebbles and dry cracks.
		float peb = step(0.93, vnoise(wp * vec2(0.18, 0.3)));
		col = mix(col, col * 0.62, peb * 0.8);
		col = mix(col, col * 1.25, step(0.95, vnoise(wp * vec2(0.23, 0.37) + 7.0)) * 0.6);
		float crack = smoothstep(0.02, 0.0, abs(fbm(wp * 0.02) - 0.5));
		col *= 1.0 - crack * 0.14;
	} else if (kind == 1) {
		// Wind ripples in sand.
		float rip = sin(wp.x * 0.09 + fbm(wp * 0.01) * 18.0 + wp.y * 0.05);
		col *= 1.0 + rip * 0.05;
		col = mix(col, col * 0.75, step(0.96, vnoise(wp * vec2(0.2, 0.35))) * 0.7);
	} else if (kind == 2) {
		// Grass: vertical blade streaks, darker clumps, occasional flowers.
		float blades = vnoise(wp * vec2(0.9, 0.08));
		col *= 0.85 + blades * 0.3;
		col = mix(col, col * 0.7, smoothstep(0.55, 0.7, fbm(wp * 0.015)) * 0.6);
		float fl = step(0.992, vnoise(wp * vec2(0.3, 0.45)));
		col = mix(col, vec3(0.9, 0.85, 0.5), fl * (1.0 - depth));
	} else if (kind == 3) {
		// Wet rock slabs with a cold sheen.
		float slab = fbm(wp * vec2(0.012, 0.03));
		float edge = smoothstep(0.015, 0.0, abs(fract(slab * 6.0) - 0.5) - 0.47);
		col *= 1.0 - edge * 0.35;
		col += vec3(0.08, 0.1, 0.14) * smoothstep(0.6, 0.75, fbm(wp * 0.03 + 3.0));
	} else if (kind == 4) {
		// Churned mud with puddles reflecting the sky.
		float pud = smoothstep(0.6, 0.64, fbm(wp * vec2(0.006, 0.02)));
		col = mix(col, vec3(0.55, 0.36, 0.22) * (0.8 + 0.2 * sin(wp.x * 0.05 + time_s)), pud * 0.7);
		col *= 1.0 - step(0.9, vnoise(wp * vec2(0.05, 0.6))) * 0.25;
	} else {
		// Metal deck plates with glowing seams.
		vec2 cell = wp / vec2(160.0, 60.0);
		vec2 f = abs(fract(cell) - 0.5);
		float seamline = smoothstep(0.49, 0.5, max(f.x, f.y));
		col *= 0.9 + 0.2 * hash21(floor(cell));
		col = mix(col, accent.rgb, seamline * (0.35 + 0.15 * sin(time_s * 2.0 + floor(cell.x))) * (1.0 - depth));
	}
	// Lane road: worn band with two wheel ruts.
	float ry = wp.y - ground_y;
	float wob = (fbm(vec2(wp.x * 0.01, 0.0)) - 0.5) * 8.0;
	float road = smoothstep(-2.0, 4.0, ry) * (1.0 - smoothstep(26.0 + wob, 36.0 + wob, ry));
	vec3 rc = road_color.rgb * (1.0 + mid * 0.4 + fine * 0.15);
	float rut = smoothstep(2.2, 0.0, abs(ry - 11.0 - wob * 0.3)) + smoothstep(2.2, 0.0, abs(ry - 22.0 - wob * 0.3));
	rc *= 1.0 - rut * 0.28;
	col = mix(col, rc, road * (kind == 5 ? 0.5 : 0.85));
	// Contact shadow right under the horizon line.
	col *= 1.0 - smoothstep(8.0, 0.0, ry) * 0.2;
	COLOR = vec4(col, seam_keep(SCREEN_UV, seam, side, opaque_left, 0.035, dissolve));
}
