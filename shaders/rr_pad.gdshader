// Boost pads (MultiMesh): the palette shader plus a per-pad flare in
// INSTANCE_CUSTOM.r (0..1) that brightens the glowing arrows on a hit.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
uniform sampler2D palette : source_color, filter_nearest;
uniform float glow_energy = 1.6;
varying float flare;
void vertex() {
	flare = INSTANCE_CUSTOM.r;
}
void fragment() {
	vec3 c = texture(palette, UV).rgb;
	vec2 cell = floor(UV * 8.0);
	float glow = step(5.5, cell.y) * step(cell.y, 6.5);
	ALBEDO = c;
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
	EMISSION = c * glow * glow_energy * (1.0 + flare * 0.6);
}
