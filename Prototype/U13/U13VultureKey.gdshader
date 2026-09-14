shader_type canvas_item;

// Key only the near-black matte; keep the dark cloak above this narrow range.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float brightness = max(pixel.r, max(pixel.g, pixel.b));
	COLOR.a *= smoothstep(0.008, 0.035, brightness);
}
