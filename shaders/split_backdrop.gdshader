shader_type canvas_item;
// Keeps one side's half of the split battlefield (GDD §13.6): side 0 keeps left of the seam,
// side 1 keeps right. The seam is ragged with blocky "brush" noise; `dissolve` < 1 fades a newly
// evolved age in through the same noise (GDD §13.5 painterly dissolve).

uniform float seam = 0.5;
uniform float side = 0.0;
uniform float softness = 0.035;
uniform float dissolve = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float n = noise(uv * vec2(18.0, 42.0)) * 0.6 + noise(uv * vec2(60.0, 140.0)) * 0.4;
	float d = uv.x - seam + (n - 0.5) * 0.05;
	float m = smoothstep(-softness, softness, d);
	// The left half is drawn opaque underneath; only the right half is masked on top of it, so the
	// seam never composites two part-transparent layers over the clear colour.
	float keep = side < 0.5 ? 1.0 : m;
	if (dissolve < 1.0) {
		keep *= 1.0 - smoothstep(dissolve - 0.08, dissolve, n);
	}
	COLOR.a *= keep;
}
