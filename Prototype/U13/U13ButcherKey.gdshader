shader_type canvas_item;
// Generated sheet uses a chroma background; remove it only on the sprite layer.
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float excess = c.g - max(c.r, c.b);
	float key = smoothstep(0.10, 0.35, excess);
	c.a *= 1.0 - key;
	c.g = min(c.g, max(c.r, c.b) + 0.04);
	COLOR = c;
}
