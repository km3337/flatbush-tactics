shader_type canvas_item;

// "Glitching out" for stunned enemies: rows of the sprite jump sideways in
// whole pixels, the colour channels split apart, and a shimmer sweeps over
// it. `strength` 0 = off. Steps in whole texture pixels so it stays on the
// pixel-art grid. Tunable per material.

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shimmer_color : source_color = vec4(0.55, 1.0, 1.0, 1.0);
uniform float steps_per_second = 14.0;
uniform float max_shift_px = 4.0;
uniform float band_height_px = 3.0;
// Digitize-in: rows down to `reveal` (0 = nothing, 1 = all) are drawn, with
// a bright scanline at the edge. `pixel_uv` overrides the pixel size for
// untextured rectangles (1 / rect size); 0 = use the texture's.
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform vec4 edge_color : source_color = vec4(0.55, 1.0, 1.0, 1.0);
uniform vec2 pixel_uv = vec2(0.0);

varying vec4 tint;  // modulate / self_modulate, without the texture

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float t = floor(TIME * steps_per_second);
	// Horizontal bands that jump sideways on some steps.
	float band = floor(UV.y / px.y / band_height_px);
	float jumps = step(0.65, hash(band * 12.9898 + t * 78.233));
	float shift = floor((hash(band + t * 3.7) - 0.5) * 2.0 * max_shift_px) * jumps * strength;
	vec2 uv = UV + vec2(shift * px.x, 0.0);
	// Channel split: red one pixel right, blue one pixel left.
	float split = round(strength * (1.0 + step(0.8, hash(t * 1.3))));
	vec4 base = texture(TEXTURE, uv);
	float r = texture(TEXTURE, uv + vec2(split * px.x, 0.0)).r;
	float b = texture(TEXTURE, uv - vec2(split * px.x, 0.0)).b;
	float a = max(base.a, max(texture(TEXTURE, uv + vec2(split * px.x, 0.0)).a, texture(TEXTURE, uv - vec2(split * px.x, 0.0)).a));
	vec4 col = vec4(r, base.g, b, a);
	// Shimmer: a bright line sweeping down, plus brief full flashes.
	float sweep = fract(TIME * 1.6);
	float line = step(abs(UV.y - sweep), px.y * 2.0);
	float flash = step(0.86, hash(t * 0.77)) * 0.6;
	col.rgb = mix(col.rgb, shimmer_color.rgb, clamp((line * 0.7 + flash) * strength, 0.0, 1.0));
	COLOR = col * tint;
	if (reveal < 1.0) {
		vec2 pxs = pixel_uv.x > 0.0 ? pixel_uv : px;
		float row = floor(UV.y / pxs.y);
		float edge_row = floor(reveal / pxs.y);
		if (row > edge_row) {
			COLOR.a = 0.0;
		} else if (edge_row - row < 2.0) {
			COLOR.rgb = edge_color.rgb;
		}
	}
}
