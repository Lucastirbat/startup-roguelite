shader_type canvas_item;

// Animated CRT-style backdrop: drifting glow, faint grid, scanlines, vignette.
// Tint via base_color / glow_color so scenes can theme it (win/lose screens).

uniform vec4 base_color : source_color = vec4(0.07, 0.08, 0.11, 1.0);
uniform vec4 glow_color : source_color = vec4(0.10, 0.14, 0.21, 1.0);
uniform vec4 accent_color : source_color = vec4(0.13, 0.83, 0.93, 1.0);
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.10;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.05;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.85;

void fragment() {
	vec2 uv = UV;

	// Slow diagonal glow drift.
	float t = TIME * 0.06;
	float g = sin(uv.x * 3.1 + t) * sin(uv.y * 2.3 - t * 1.4);
	vec3 col = mix(base_color.rgb, glow_color.rgb, 0.5 + 0.5 * g);

	// Faint blueprint grid.
	vec2 grid_uv = uv * vec2(40.0, 22.5);
	vec2 gv = abs(fract(grid_uv) - 0.5);
	float line = smoothstep(0.46, 0.5, max(gv.x, gv.y));
	col += accent_color.rgb * line * grid_strength;

	// CRT scanlines, slowly rolling.
	float scan = 0.5 + 0.5 * sin(uv.y * 480.0 - TIME * 1.5);
	col *= 1.0 - scanline_strength * scan;

	// Barely-there flicker.
	col *= 1.0 + 0.008 * sin(TIME * 9.0);

	// Vignette.
	vec2 c = uv - 0.5;
	col *= 1.0 - vignette_strength * dot(c, c);

	COLOR = vec4(col, 1.0);
}
