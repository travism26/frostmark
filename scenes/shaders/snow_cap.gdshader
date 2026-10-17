// Snow on everything that faces the sky: the model's own colour (or its colour map) on the
// sides, fresh snow on the tops. Used on the low-poly props so CC0 summer models read as a
// frozen frontier without repainting them. Materials with `sway` above zero (the pines) bend
// slowly downwind: the wind is one global uniform the atmosphere node sets from the ring
// look, so no tree carries a script.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform bool use_texture = false;
uniform vec4 snow_color : source_color = vec4(0.93, 0.96, 1.0, 1.0);
// Faces whose world normal points up more than this get snow.
uniform float snow_from = 0.55;
// How far this material bends in the wind, 0 for not at all.
uniform float sway = 0.0;
// xy: where the wind blows to on the ground (x east, y south); z: its strength, 0 to 1;
// w: how much of the sway to show (lower with reduced motion).
global uniform vec4 wind;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (sway > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float h = max((MODEL_MATRIX * vec4(VERTEX, 1.0)).y - root.y, 0.0);
		// Each tree sways on its own phase, a little faster in a stronger wind.
		float phase = TIME * (0.5 + 0.6 * wind.z) + dot(root.xz, vec2(0.37, 0.21));
		float gust = 0.6 + 0.4 * sin(phase) * sin(phase * 0.43 + 1.7);
		vec2 push = wind.xy * (wind.z * wind.w * sway * gust * 0.012 * h * h);
		// Back into the model's space: its basis is a rotation times a uniform scale.
		mat3 basis = mat3(MODEL_MATRIX);
		VERTEX += transpose(basis) * vec3(push.x, 0.0, push.y) / dot(basis[0], basis[0]);
	}
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_texture) {
		base *= texture(albedo_texture, UV).rgb;
	}
	float snow = smoothstep(snow_from, snow_from + 0.2, world_normal.y);
	ALBEDO = mix(base, snow_color.rgb, snow);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
