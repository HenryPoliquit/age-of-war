shader_type canvas_item;
// Painted sky per age: gradient, sun glare and haze, fbm clouds lit from the sun, stars at night.
#include "res://shaders/common.gdshaderinc"

uniform vec4 top_color : source_color;
uniform vec4 horizon_color : source_color;
uniform vec4 sun_color : source_color;
uniform vec2 sun_uv = vec2(0.7, 0.5);
uniform float sun_size = 0.05;
uniform float moon = 0.0;
uniform vec4 cloud_light : source_color = vec4(1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.6, 0.6, 0.7, 1.0);
uniform float cloud_cover = 0.4;
uniform float cloud_band = 0.5;
uniform float stars = 0.0;
uniform float drift = 0.0;
uniform float time_s = 0.0;
// Seam.
uniform float seam = 0.5;
uniform float side = 0.0;
uniform bool opaque_left = true;
uniform float dissolve = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = mix(top_color.rgb, horizon_color.rgb, pow(uv.y, 1.4));
	// Sun / moon with glare and a wide warm haze.
	vec2 d = (uv - sun_uv) * vec2(aspect, 1.0);
	float r = length(d);
	col += sun_color.rgb * (0.35 * exp(-r * 6.0) + 0.25 * exp(-r * 18.0)) * (1.0 - moon * 0.7);
	float disc = smoothstep(sun_size, sun_size * 0.92, r);
	vec3 disc_col = sun_color.rgb * (1.0 - moon * 0.12 * vnoise(d * 60.0));
	col = mix(col, disc_col, disc);
	// Stars.
	if (stars > 0.0) {
		vec2 cells = uv * vec2(260.0, 150.0);
		float h = hash21(floor(cells));
		float point = smoothstep(0.22, 0.05, length(fract(cells) - 0.5 + (vec2(hash21(floor(cells) + 3.1), hash21(floor(cells) + 7.7)) - 0.5) * 0.5));
		float tw = 0.6 + 0.4 * sin(time_s * 2.0 + h * 60.0);
		col += vec3(step(0.994, h) * point * stars * tw * (1.0 - uv.y));
	}
	// Clouds: domain-warped fbm in a band, lit on the sun-facing side.
	vec2 p = vec2(uv.x * aspect * 2.2 + drift, uv.y * 5.0);
	vec2 w = vec2(fbm(p * 0.7 + time_s * 0.01), fbm(p * 0.7 + 5.2));
	float dens = fbm(p + w * 1.4);
	float band = exp(-pow((uv.y - cloud_band) / 0.28, 2.0));
	float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, dens * (0.55 + 0.6 * band));
	vec2 to_sun = normalize(sun_uv - uv + vec2(0.0001));
	float lit = fbm(p + w * 1.4 - to_sun * 0.08 * vec2(aspect, 1.0)) - dens;
	vec3 cloud = mix(cloud_shadow.rgb, cloud_light.rgb, clamp(0.55 - lit * 6.0, 0.0, 1.0));
	cloud += sun_color.rgb * 0.25 * exp(-r * 4.0) * (1.0 - moon);
	col = mix(col, cloud, c * 0.92);
	COLOR = vec4(col, seam_keep(SCREEN_UV, seam, side, opaque_left, 0.035, dissolve));
}
