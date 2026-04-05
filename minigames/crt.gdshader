shader_type canvas_item;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.30;
uniform float scanline_count : hint_range(10.0, 800.0) = 120.0;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.20;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.05;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.10;

// rolling bar
uniform float bar_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float bar_speed : hint_range(0.0, 2.0) = 0.18;
uniform float bar_thickness : hint_range(0.0, 0.5) = 0.08;

// fisheye
uniform float fisheye_strength : hint_range(0.0, 1.0) = 0.12;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 fisheye(vec2 uv, float strength) {
	vec2 centered = uv - 0.5;
	float dist = length(centered);
	float factor = 1.0 + dist * dist * strength;
	return centered * factor + 0.5;
}

void fragment() {
	// fisheye distortion — distort UV before everything else
	vec2 uv = fisheye(UV, fisheye_strength);

	// discard pixels that land outside 0..1 after fisheye (gives curved screen edge)
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		discard;
	}

	// scanlines
	float scanline = sin(uv.y * scanline_count * 3.14159);
	scanline = pow(abs(scanline), 0.5);
	float scanline_alpha = scanline_intensity * (1.0 - scanline);

	// vignette
	vec2 vig_uv = uv * (1.0 - uv);
	float vignette = vig_uv.x * vig_uv.y * 12.0;
	vignette = clamp(pow(vignette, vignette_intensity), 0.0, 1.0);
	float vignette_alpha = 1.0 - vignette;

	// flicker
	float flicker = flicker_intensity * rand(vec2(floor(TIME * 20.0), 0.3));

	// noise
	float noise = rand(uv + vec2(floor(TIME * 15.0) * 0.01, floor(TIME * 15.0) * 0.007));
	float noise_alpha = (noise - 0.5) * noise_intensity;

	// rolling bar — slow dark band scrolling down the screen
	float bar_pos = fract(TIME * bar_speed);
	float bar_dist = abs(uv.y - bar_pos);
	// wrap around at edges
	bar_dist = min(bar_dist, 1.0 - bar_dist);
	float bar = smoothstep(bar_thickness, 0.0, bar_dist) * bar_intensity;

	// combine
	float darkness = scanline_alpha + vignette_alpha * 0.5 + flicker + bar;
	darkness = clamp(darkness, 0.0, 0.92);

	COLOR = vec4(
		noise_alpha,
		noise_alpha,
		noise_alpha,
		darkness
	);
}