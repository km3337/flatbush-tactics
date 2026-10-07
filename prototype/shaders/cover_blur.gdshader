shader_type canvas_item;

// Blurs whatever is drawn beneath this rect (the battlefield) while the
// player is in cover. A 5x5 gaussian; `radius_px` is in screen pixels, set
// by FTCover from the game's integer scale so the blur looks the same at
// any window size. `strength` fades the blur in and out with the cover.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float radius_px = 3.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 step_uv = SCREEN_PIXEL_SIZE * radius_px * strength;
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.0);
			sum += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * step_uv) * w;
			total += w;
		}
	}
	COLOR = vec4((sum / total).rgb, 1.0);
}
