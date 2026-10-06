// Track kit with LEDs (DESIGN 2d, 7): boost pads (MultiMesh, the pad hit
// flare 1.5 -> 3.0 in INSTANCE_CUSTOM.r) and swap gates (dormant = energy 0,
// live = 1.5, the 0.3 s light run moves down the strips along UV.y).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D alb : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D emi : source_color, filter_linear_mipmap, repeat_enable;
uniform float energy = 1.5;
uniform float run = -1.0;
uniform bool use_normals = true;
uniform bool instanced = false;

varying float flare;

void vertex() {
	flare = instanced ? INSTANCE_CUSTOM.r : 0.0;
}

void fragment() {
	vec3 o = texture(orm, UV).rgb;
	ALBEDO = texture(alb, UV).rgb;
	AO = o.r;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = o.g;
	METALLIC = o.b;
	if (use_normals) {
		NORMAL_MAP = texture(nrm, UV).rgb;
	}
	float band = run >= 0.0 ? exp(-pow((UV.y - run) / 0.07, 2.0)) * 2.0 : 0.0;
	EMISSION = texture(emi, UV).rgb * (energy * (1.0 + flare) + band);
}
