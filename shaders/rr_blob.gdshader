// Contact shadow (DESIGN 7d): one soft radial quad per racer, #2A4A22 at 45%
// in the centre; it fades when the racer is in the air.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, fog_disabled;
instance uniform float fade = 1.0;
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float a = (1.0 - smoothstep(0.35, 1.0, r)) * 0.45 * fade;
	ALBEDO = vec3(0.165, 0.290, 0.133);
	ALPHA = a;
}
