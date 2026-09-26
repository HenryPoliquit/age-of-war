shader_type canvas_item;
render_mode unshaded;
// Applied to the CanvasGroup holding one side's units. Gives flat figures volume and readability:
//  - pseudo-normals from the silhouette's alpha gradient → sun-side rim light and far-side shading,
//  - a soft inner edge (occlusion) and a slight top-to-bottom value falloff,
//  - a dark ink outline with a faint team-coloured rim (PRD §11 "Clarity").

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.07, 0.92);
uniform vec4 rim : source_color = vec4(0.3, 0.55, 1.0, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform vec2 light_dir = vec2(0.6, -0.8);
uniform float width = 2.0;
uniform float rim_mix = 0.3;
uniform float shade_strength = 0.55;

float a_at(vec2 uv) {
	return textureLod(screen_texture, uv, 0.0).a;
}

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec2 px = SCREEN_PIXEL_SIZE;
	// Outline.
	float o = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		o = max(o, a_at(SCREEN_UV + vec2(cos(ang), sin(ang)) * px * width));
	}
	// Volume from the silhouette: gradient of blurred alpha points out of the shape.
	vec2 g = vec2(0.0);
	float inner = 0.0;
	for (int r = 1; r <= 3; r++) {
		float d = float(r) * 2.0;
		g.x += a_at(SCREEN_UV + vec2(d, 0.0) * px) - a_at(SCREEN_UV - vec2(d, 0.0) * px);
		g.y += a_at(SCREEN_UV + vec2(0.0, d) * px) - a_at(SCREEN_UV - vec2(0.0, d) * px);
		inner += a_at(SCREEN_UV + vec2(d, d) * px) + a_at(SCREEN_UV - vec2(d, d) * px)
			+ a_at(SCREEN_UV + vec2(d, -d) * px) + a_at(SCREEN_UV + vec2(-d, d) * px);
	}
	inner /= 12.0;
	vec2 n = -g;
	float edge = clamp(length(n) * 0.6, 0.0, 1.0);
	vec2 nn = length(n) > 0.001 ? normalize(n) : vec2(0.0);
	float lambert = dot(nn, normalize(vec2(light_dir.x, -light_dir.y)));
	vec3 lit = c.rgb;
	lit += light_color.rgb * max(lambert, 0.0) * edge * 0.45 * shade_strength;
	lit *= 1.0 - max(-lambert, 0.0) * edge * 0.5 * shade_strength;
	lit *= mix(0.78, 1.0, smoothstep(0.35, 0.95, inner));
	vec3 line = mix(ink.rgb, rim.rgb, rim_mix);
	COLOR = vec4(mix(line, lit, c.a), max(c.a, o * ink.a));
}
