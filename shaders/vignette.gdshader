shader_type canvas_item;
// Soft vignette and a touch of film grain over the lane; keeps the eye on the battle line.

uniform float strength = 0.55;
uniform float grain = 0.025;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= 1.4;
	float v = smoothstep(0.35, 0.95, length(uv));
	float g = (hash(FRAGCOORD.xy + TIME) - 0.5) * grain;
	COLOR = vec4(vec3(0.0) + g, v * strength);
}
