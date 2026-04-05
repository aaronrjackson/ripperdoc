shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float t = TIME + time_offset;
	
	// horizontal slice glitching
	float slice = floor(UV.y * 20.0) / 20.0;
	float noise = fract(sin(slice * 127.3 + t * 7.0) * 4375.5453);
	float offset = (noise - 0.5) * glitch_intensity * 0.3;
	
	if (noise > (1.0 - glitch_intensity * 0.8)) {
		offset *= 3.0;
	} else {
		offset *= 0.1;
	}
	
	vec2 uv = UV + vec2(offset, 0.0);
	
	vec4 col_r = texture(TEXTURE, uv + vec2(glitch_intensity * 0.02, 0.0));
	vec4 col_g = texture(TEXTURE, uv);
	vec4 col_b = texture(TEXTURE, uv - vec2(glitch_intensity * 0.02, 0.0));
	
	vec4 col = vec4(col_r.r, col_g.g, col_b.b, col_g.a);
	
	float flicker = 1.0 - glitch_intensity * 0.3 * fract(sin(t * 60.0) * 1000.0);
	col.rgb *= flicker;
	
	col.a *= 1.0 - glitch_intensity * 0.7;
	col.a *= opacity;
	
	COLOR = col;
}