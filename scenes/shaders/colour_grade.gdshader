// A cheap screen-space colour grade for the frozen frontier, within what GL Compatibility
// allows: one read of the screen, a split tone (shadows toward the sky's blue-violet, lights
// toward the dusk sun), a touch of contrast, and the aurora as a faint band of light across
// the top of the view in the outer rings. The atmosphere node sets every uniform from the
// ring look each frame.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec3 shadow_tint : source_color = vec3(0.45, 0.42, 0.78);
uniform vec3 light_tint : source_color = vec3(1.0, 0.95, 0.88);
// How far the split tone is pushed, 0 for none.
uniform float grade : hint_range(0.0, 1.0) = 0.45;
uniform float contrast = 1.06;
uniform float saturation = 0.96;
// The aurora's strength, 0 for none.
uniform float aurora : hint_range(0.0, 1.0) = 0.0;
uniform vec3 aurora_green : source_color = vec3(0.35, 1.0, 0.62);
uniform vec3 aurora_violet : source_color = vec3(0.62, 0.38, 1.0);

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float lum = dot(c, LUMA);
	vec3 shade = c * shadow_tint / max(dot(shadow_tint, LUMA), 0.001);
	vec3 light = c * light_tint / max(dot(light_tint, LUMA), 0.001);
	vec3 toned = mix(shade, light, smoothstep(0.12, 0.85, lum));
	c = mix(c, toned, grade);
	c = (c - 0.5) * contrast + 0.5;
	c = mix(vec3(dot(c, LUMA)), c, saturation);
	if (aurora > 0.0) {
		float x = SCREEN_UV.x;
		float y = SCREEN_UV.y;
		// Curtains drift slowly; the band fades out a third of the way down the view.
		float band = (1.0 - smoothstep(0.0, 0.5, y)) * smoothstep(-0.02, 0.05, y);
		float curtain = 0.55 + 0.45 * sin(x * 7.0 + TIME * 0.21 + sin(x * 3.0 - TIME * 0.11) * 1.5);
		curtain *= 0.7 + 0.3 * sin(x * 19.0 - TIME * 0.33);
		float ripple = 0.5 + 0.5 * sin(y * 40.0 + x * 6.0 + TIME * 0.4);
		vec3 glow = mix(aurora_green, aurora_violet, smoothstep(0.0, 0.3, y + 0.1 * sin(x * 5.0 + TIME * 0.1)));
		c += glow * band * curtain * (0.55 + 0.45 * ripple) * aurora * 0.5;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
