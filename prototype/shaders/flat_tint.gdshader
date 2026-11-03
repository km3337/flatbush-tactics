shader_type canvas_item;

// Draws the texture's shape in one flat colour (the lock-on overlay).
uniform vec4 tint : source_color = vec4(1.0, 0.84, 0.41, 1.0);

void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
