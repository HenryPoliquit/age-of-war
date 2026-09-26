shader_type canvas_item;
// Unit gallery review modes: 0 colour, 1 greyscale (luma), 2 flat silhouette (PRD §11 silhouette check).
uniform int mode = 0;

void fragment() {
	vec4 c = COLOR;
	if (mode == 1) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(vec3(l), c.a);
	} else if (mode == 2) {
		COLOR = vec4(vec3(0.05), c.a > 0.05 ? 1.0 : 0.0);
	}
}
