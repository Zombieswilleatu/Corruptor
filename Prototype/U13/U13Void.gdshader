shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 95.0 + TIME * 1.7) * 0.0018;
	uv.y += sin(uv.x * 65.0 - TIME) * 0.0012;
	vec4 scene = texture(screen_texture, uv);
	float veil = 0.07 + 0.025 * sin(uv.y * 500.0 + TIME);
	COLOR = vec4(mix(scene.rgb, vec3(0.20, 0.10, 0.29), veil), 1.0);
}
