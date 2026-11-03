shader_type canvas_item;

// Red glow around the screen edges when the player is hit. Banded in whole
// game pixels so it reads as pixel art, not a smooth gradient. `size` is the
// rect's size in game pixels (set by the HUD).
uniform vec2 size = vec2(360.0, 780.0);
uniform vec4 tint : source_color = vec4(0.91, 0.27, 0.27, 1.0);

void fragment() {
	vec2 p = floor(UV * size);
	float d = min(min(p.x, size.x - 1.0 - p.x), min(p.y, size.y - 1.0 - p.y));
	float a = d < 4.0 ? 0.9 : d < 10.0 ? 0.6 : d < 20.0 ? 0.35 : d < 34.0 ? 0.15 : 0.0;
	COLOR = vec4(tint.rgb, tint.a * a);
}
