// Ground that reads as snow (or trodden earth) at every zoom: two scales of one seamless
// noise tile, sampled in world metres so the plane's size and UVs never matter, a thin
// cellular sparkle for sun on fresh snow, and optional drifts of snow over the base colour.
shader_type spatial;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D sparkle_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.88, 0.92, 0.98, 1.0);
uniform vec4 shade_color : source_color = vec4(0.70, 0.79, 0.92, 1.0);
uniform vec4 drift_color : source_color = vec4(0.93, 0.96, 1.0, 1.0);
// Metres per repeat of the broad mottling and of the fine grain.
uniform float broad_metres = 11.0;
uniform float fine_metres = 2.6;
uniform float sparkle_metres = 6.5;
uniform float sparkle_strength = 0.35;
// How much of the surface the drift colour covers (0 = none; the yard uses it for snow
// blown into the corners).
uniform float drift_cover = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = texture(noise_tex, p / broad_metres).r;
	float fine = texture(noise_tex, p / fine_metres + vec2(0.37, 0.61)).r;
	float m = broad * 0.6 + fine * 0.4;
	vec3 col = mix(shade_color.rgb, base_color.rgb, smoothstep(0.28, 0.78, m));
	if (drift_cover > 0.0) {
		float drift = smoothstep(1.0 - drift_cover, 1.0 - drift_cover + 0.3, broad * 0.8 + fine * 0.2);
		col = mix(col, drift_color.rgb, drift);
	}
	float sparkle = smoothstep(0.94, 0.995, texture(sparkle_tex, p / sparkle_metres).r);
	ALBEDO = col + sparkle * sparkle_strength;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
