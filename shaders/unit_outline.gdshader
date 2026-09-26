shader_type canvas_item;
render_mode unshaded;
// Applied to a CanvasGroup holding one side's units: a dark ink outline with a faint team-coloured
// rim, so units stay readable over busy backdrops and in crowds (PRD §11 "Clarity").

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.07, 0.92);
uniform vec4 rim : source_color = vec4(0.3, 0.55, 1.0, 1.0);
uniform float width = 2.0;
uniform float rim_mix = 0.3;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec2 px = SCREEN_PIXEL_SIZE * width;
	float a = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		a = max(a, textureLod(screen_texture, SCREEN_UV + vec2(cos(ang), sin(ang)) * px, 0.0).a);
	}
	vec3 line = mix(ink.rgb, rim.rgb, rim_mix);
	float oa = a * ink.a;
	COLOR = vec4(mix(line, c.rgb, c.a), max(c.a, oa));
}
