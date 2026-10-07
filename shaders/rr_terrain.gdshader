// Ground of one world (DESIGN 9-10): scanned PBR layers blended by the
// splat weights the world generator stores per vertex in COLOR
// (R trail, G rock face, B grass patch, A verge), mapped in world space.
// Ground layers project from above; rock faces project from the side (one
// sample, the axis facing the wall). UV2.x = metres from the centre line,
// for the darker, smoother riding line on the trail.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D trail_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trail_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D trail_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_alb : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D verge_alb : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D patch_alb : source_color, filter_linear_mipmap, repeat_enable;
uniform float trail_tile = 3.2;
uniform float base_tile = 4.0;
uniform float rock_tile = 4.0;
uniform float verge_tile = 3.0;
uniform float patch_tile = 3.0;
uniform vec3 rock_tint = vec3(1.0);
uniform vec3 base_tint = vec3(1.0);
uniform vec3 verge_tint = vec3(1.0);
uniform float line_dark = 0.14;
uniform bool use_normals = true;
// Far grid: skip the grass patches (normal maps go off via use_normals).
uniform bool cheap = false;
// DESIGN 10a: rock faces sampled world-aligned triplanar (strata stay level
// on every wall angle) with the base layer collecting on the ledges. Høy only.
uniform bool rock_triplanar = false;
// DESIGN 11.1: snow-cat corduroy runs along the track (trail UV turned 90 deg).
uniform bool trail_rot = false;
// DESIGN 11.1: blue course-dye lines just inside both trail edges.
uniform bool dye = false;
uniform vec3 dye_color = vec3(0.12, 0.30, 0.85);
// DESIGN 11.3 / 11.4: wet trail (roughness multiplier on the trail layer).
uniform float rough_mult = 1.0;

varying vec3 wpos;
varying vec4 splat;
varying vec2 lat;

// Normal maps are imported as two-channel (RG) textures: rebuild Z.
vec3 unpack(vec3 n) {
	vec2 xy = n.rg * 2.0 - 1.0;
	return vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	splat = COLOR;
	lat = UV2;
}

void fragment() {
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 uv = wpos.xz;
	vec3 alb = texture(base_alb, uv / base_tile).rgb * base_tint;
	// Large-scale variation so the tiling does not read at distance.
	float macro = texture(base_alb, uv / (base_tile * 11.0)).g;
	vec3 arm = texture(base_arm, uv / base_tile).rgb;
	vec3 tn = vec3(0.0, 0.0, 1.0);
	if (use_normals) {
		tn = unpack(texture(base_nrm, uv / base_tile).rgb);
	}
	if (!cheap && splat.b > 0.01) {
		alb = mix(alb, texture(patch_alb, uv / patch_tile).rgb, splat.b);
	}
	if (splat.a > 0.01) {
		alb = mix(alb, texture(verge_alb, uv / verge_tile).rgb * verge_tint, splat.a);
		arm.g = mix(arm.g, 0.92, splat.a);
	}
	if (splat.r > 0.01) {
		vec2 tuv = trail_rot ? vec2(uv.y, -uv.x) : uv;
		vec3 ta = texture(trail_alb, tuv / trail_tile).rgb;
		vec3 tr = texture(trail_arm, tuv / trail_tile).rgb;
		tr.g *= rough_mult;
		if (dye) {
			float e = lat.y - abs(lat.x);
			float band = smoothstep(0.05, 0.12, e) * (1.0 - smoothstep(0.55, 0.62, e));
			ta = mix(ta, dye_color, 0.6 * band * step(lat.x, 90.0));
		}
		float d = abs(lat.x);
		float line = 0.55 * exp(-pow((d - 1.3) / 0.55, 2.0)) + 0.35 * exp(-pow(d / 0.6, 2.0));
		line *= step(lat.x, 90.0);
		ta *= 1.0 - line_dark * line;
		tr.g *= 1.0 - 0.25 * line;
		alb = mix(alb, ta, splat.r);
		arm = mix(arm, tr, splat.r);
		if (use_normals) {
			tn = mix(tn, unpack(texture(trail_nrm, tuv / trail_tile).rgb), splat.r);
		}
	}
	alb *= 0.86 + 0.28 * macro;
	// Top-down tangent frame (Godot binormal = -V).
	vec3 t_w = normalize(vec3(1.0, 0.0, 0.0) - nw * nw.x);
	vec3 b_w = normalize(cross(nw, t_w));
	vec3 n_out = normalize(t_w * tn.x + b_w * tn.y + nw * tn.z);
	if (splat.g > 0.01 && rock_triplanar) {
		vec3 bw = pow(abs(nw), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec3 rx = texture(rock_alb, vec2(wpos.z, -wpos.y) / rock_tile).rgb;
		vec3 rz = texture(rock_alb, vec2(wpos.x, -wpos.y) / rock_tile).rgb;
		vec3 ry = texture(base_alb, wpos.xz / base_tile).rgb * base_tint;
		vec3 ra = (rx * bw.x + rz * bw.z) * rock_tint + ry * bw.y;
		alb = mix(alb, ra, splat.g);
		arm.g = mix(arm.g, 0.86, splat.g);
	} else if (splat.g > 0.01) {
		bool xside = abs(nw.x) > abs(nw.z);
		vec2 ruv = xside ? vec2(wpos.z * sign(nw.x), -wpos.y) : vec2(-wpos.x * sign(nw.z), -wpos.y);
		vec3 ra = texture(rock_alb, ruv / rock_tile).rgb * rock_tint;
		alb = mix(alb, ra, splat.g);
		arm.g = mix(arm.g, 0.86, splat.g);
		if (use_normals) {
			vec3 rn = unpack(texture(rock_nrm, ruv / rock_tile).rgb);
			vec3 rt = xside ? vec3(0.0, 0.0, sign(nw.x)) : vec3(-sign(nw.z), 0.0, 0.0);
			vec3 rb = vec3(0.0, 1.0, 0.0);
			vec3 rnw = normalize(rt * rn.x + rb * rn.y + nw * rn.z);
			n_out = normalize(mix(n_out, rnw, splat.g));
		}
	}
	ALBEDO = alb;
	ROUGHNESS = clamp(arm.g, 0.3, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.35;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.5;
	NORMAL = normalize((VIEW_MATRIX * vec4(n_out, 0.0)).xyz);
}
