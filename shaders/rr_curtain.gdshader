// A live swap gate: a soft additive shimmer inside the arch (slow, 0.5 Hz,
// far under the flash limit). Dormant gates do not show it.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
uniform vec3 tint : source_color = vec3(0.561, 0.937, 1.0);
uniform float strength = 0.22;
uniform float burst = 0.0;
void fragment() {
	float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	float wave = 0.75 + 0.25 * sin(TIME * 3.1416 + UV.y * 6.0);
	float ring = burst * (1.0 - smoothstep(0.0, 0.12, abs(UV.y - (1.0 - burst))));
	ALBEDO = tint;
	ALPHA = clamp((strength * wave + ring * 0.8) * edge * (1.0 - UV.y * 0.4), 0.0, 1.0);
}
