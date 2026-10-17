// Snow on everything that faces the sky: the model's own colour (or its colour map) on the
// sides, fresh snow on the tops. Used on the low-poly props so CC0 summer models read as a
// frozen frontier without repainting them.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform bool use_texture = false;
uniform vec4 snow_color : source_color = vec4(0.93, 0.96, 1.0, 1.0);
// Faces whose world normal points up more than this get snow.
uniform float snow_from = 0.55;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
