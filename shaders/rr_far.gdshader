// Far mountains and clouds that ride with the camera: no depth fog (they
// sit past the fog end), a fixed haze toward the horizon colour instead.
shader_type spatial;
render_mode cull_back, diffuse_lambert, fog_disabled;
uniform sampler2D palette : source_color, filter_nearest;
uniform vec3 haze_color : source_color = vec3(0.839, 0.933, 0.984);
uniform float haze = 0.5;
void fragment() {
	vec3 c = texture(palette, UV).rgb;
	ALBEDO = mix(c, haze_color, haze);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
