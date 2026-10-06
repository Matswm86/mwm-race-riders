// Smooth sections (DESIGN 9 river road gravel, DESIGN 10 old rim highway):
// a ribbon on top of the ground, mapped along the track (UV = lateral m,
// s m). The outer 0.1 of its width fades out with hashed alpha (no sorting).
// edge_line > 0 paints the faded white edge lines of the old highway.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tile = 2.5;
uniform float edge_line = 0.0;
uniform bool use_normals = true;

void fragment() {
	vec2 uv = UV / tile;
	vec3 c = texture(alb, uv).rgb;
	vec3 a = texture(arm, uv).rgb;
	if (edge_line > 0.0) {
		float edge = smoothstep(0.86, 0.875, abs(UV.x) / 5.85) - smoothstep(0.895, 0.91, abs(UV.x) / 5.85);
		float wear = texture(arm, UV * vec2(0.6, 0.05)).g;
		c = mix(c, vec3(0.86, 0.85, 0.80), edge * edge_line * smoothstep(0.35, 0.75, wear));
		a.g = mix(a.g, 0.7, edge * edge_line);
	}
	ALBEDO = c;
	ROUGHNESS = a.g;
	AO = a.r;
	AO_LIGHT_AFFECT = 0.5;
	SPECULAR = 0.4;
	if (use_normals) {
		NORMAL_MAP = texture(nrm, uv).rgb;
	}
	ALPHA = COLOR.a;
	ALPHA_HASH_SCALE = 1.0;
}
