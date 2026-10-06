// Ghost rider (GDD 10.8): the palette in a cool white tint at 40% opacity.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;
uniform sampler2D palette : source_color, filter_nearest;
uniform vec3 team_color : source_color = vec3(1.0);
uniform float ghost_alpha = 0.4;
void fragment() {
	vec3 c = texture(palette, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(0.86, 0.94, 1.0), vec3(1.0), l) * (0.75 + 0.25 * l);
	ALPHA = ghost_alpha;
}
