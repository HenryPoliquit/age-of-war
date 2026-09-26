shader_type canvas_item;
// Keeps one side's half of the split battlefield (GDD §13.6) and adds painterly surface texture:
// multi-scale fbm mottling and horizontal brush strokes over the flat scenery shapes.
#include "res://shaders/common.gdshaderinc"

uniform float seam = 0.5;
uniform float side = 0.0;
uniform float softness = 0.035;
uniform float dissolve = 1.0;
uniform bool opaque_left = true;
uniform float grain = 0.16;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float mottling = fbm(local_pos * vec2(0.008, 0.016)) - 0.5;
	float strokes = vnoise(local_pos * vec2(0.02, 0.22)) - 0.5;
	float speck = vnoise(local_pos * 0.35) - 0.5;
	COLOR.rgb *= 1.0 + grain * (mottling * 1.1 + strokes * 0.6 + speck * 0.35);
	COLOR.a *= seam_keep(SCREEN_UV, seam, side, opaque_left, softness, dissolve);
}
