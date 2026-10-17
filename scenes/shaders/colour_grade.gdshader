// A cheap screen-space colour grade for the frozen frontier, within what GL Compatibility
// allows: one read of the screen, a split tone (shadows toward the sky's blue-violet, lights
// toward the dusk sun), a touch of contrast, and the aurora as a faint band of light across
// the top of the view in the outer rings, and frost creeping in from the screen's edges as
// the player's warmth runs down. The atmosphere node sets every uniform from the ring look
// and the warmth.
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
// How far the frost has crept in, 0 for none (warm) to 1 (frozen).
uniform float frost : hint_range(0.0, 1.0) = 0.0;
// How strongly the frost breathes in and out, 0 for not at all.
uniform float frost_pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec3 frost_color : source_color = vec3(0.86, 0.93, 1.0);

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

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
	if (frost > 0.0) {
		// Distance to the nearest edge in view heights; the geometric mean thickens the corners.
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		vec2 e = min(SCREEN_UV, 1.0 - SCREEN_UV) * vec2(aspect, 1.0);
		float edge = sqrt(e.x * e.y);
		vec2 p = SCREEN_UV * vec2(aspect, 1.0);
		// Feathered, crystalline fringe: coarse lobes broken up by fine needles.
		float n = noise(p * 7.0) * 0.6 + noise(p * 29.0) * 0.4;
		float breath = 1.0 + frost_pulse * 0.12 * sin(TIME * 1.7);
		float reach = frost * 0.24 * breath;
		float mask = 1.0 - smoothstep(reach * 0.35, reach, edge + (n - 0.5) * 0.07);
		float needles = smoothstep(0.62, 0.9, noise(p * 61.0 + n * 3.0));
		c = mix(c, frost_color, mask * (0.5 + 0.25 * needles) * smoothstep(0.0, 0.25, frost));
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
