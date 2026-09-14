shader_type canvas_item;

// The approved walk has an opaque pale checkerboard. Key only bright,
// nearly neutral pixels on the replacement walk layer; original art is separate.
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float darkest = min(c.r, min(c.g, c.b));
	float brightest = max(c.r, max(c.g, c.b));
	float neutral = 1.0 - smoothstep(0.06, 0.14, brightest - darkest);
	float background = smoothstep(0.70, 0.81, darkest) * neutral;
	c.a *= 1.0 - background;
	COLOR = c;
}
