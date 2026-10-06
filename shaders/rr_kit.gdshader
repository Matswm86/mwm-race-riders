// MWM Race Riders: the one palette shader (DESIGN 7a). Static props share one
// instance; each racer has its own copy with its team_color.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
uniform sampler2D palette : source_color, filter_nearest;
uniform vec3 team_color : source_color = vec3(1.0);
uniform float glow_energy = 1.6;
// Høy tier: soft rim light on the racers (0 = off, Lav and props).
uniform float rim = 0.0;
void fragment() {
	vec3 c = texture(palette, UV).rgb;
	vec2 cell = floor(UV * 8.0);
	float team = step(6.5, cell.y) * step(cell.x, 0.5);      // row 7, col 0
	float glow = step(5.5, cell.y) * step(cell.y, 6.5);      // row 6
	c = mix(c, c * team_color, team);
	ALBEDO = c;
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
	EMISSION = c * glow * glow_energy;
	RIM = rim;
	RIM_TINT = 0.35;
}
