// Shared helpers: value noise, fbm, and the split-battlefield seam mask (GDD §13.6).

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

// How much of this pixel a side keeps. side 0 = left of the seam, 1 = right. opaque_left draws the
// left side everywhere (it sits underneath), so the seam never composites two part-transparent layers.
float seam_keep(vec2 screen_uv, float seam, float side, bool opaque_left, float softness, float dissolve) {
	float n = vnoise(screen_uv * vec2(18.0, 42.0)) * 0.6 + vnoise(screen_uv * vec2(60.0, 140.0)) * 0.4;
	float d = screen_uv.x - seam + (n - 0.5) * 0.05;
	float m = smoothstep(-softness, softness, d);
	float keep = side < 0.5 ? (opaque_left ? 1.0 : 1.0 - m) : m;
	if (dissolve < 1.0) {
		keep *= 1.0 - smoothstep(dissolve - 0.08, dissolve, n);
	}
	return keep;
}
