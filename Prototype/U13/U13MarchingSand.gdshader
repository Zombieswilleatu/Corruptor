shader_type canvas_item;
render_mode unshaded;
uniform float upper_level = 0.2;
uniform float lower_level = 1.0;
uniform float flow = 0.0;
uniform float phase = 0.0;
uniform float progress = 0.0;
uniform sampler2D grain_texture : filter_linear;

float half_width(float y) {
	// Interior traced in the supplied 1024 x 1536 artwork coordinates.
	if (y < 0.145 || y > 0.857) return 0.0;
	if (y < 0.23) return mix(0.195, 0.225, smoothstep(0.145, 0.23, y));
	if (y < 0.32) return mix(0.225, 0.180, smoothstep(0.23, 0.32, y));
	if (y < 0.46) return mix(0.180, 0.045, smoothstep(0.32, 0.46, y));
	if (y < 0.54) return 0.035;
	if (y < 0.69) return mix(0.045, 0.195, smoothstep(0.54, 0.69, y));
	if (y < 0.78) return mix(0.195, 0.225, smoothstep(0.69, 0.78, y));
	return mix(0.225, 0.190, smoothstep(0.78, 0.857, y));
}

void fragment() {
	vec2 p = UV;
	float x = abs(p.x - 0.5);
	float inside = step(x, half_width(p.y));
	float top = step(upper_level, p.y) * step(p.y, 0.477) * step(0.0001, 1.0 - progress);
	float bottom = step(lower_level, p.y - x * 0.35) * step(0.54, p.y) * step(0.0001, progress);
	float grain = fract(sin(dot(floor(p * vec2(360.0, 540.0)), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 sand = mix(vec3(0.45, 0.31, 0.13), vec3(0.90, 0.75, 0.43), grain * 0.6 + 0.25);
	float surface = max((1.0 - smoothstep(0.0, 0.006, abs(p.y - upper_level))) * top,
		(1.0 - smoothstep(0.0, 0.006, abs(p.y - x * 0.35 - lower_level))) * bottom);
	sand += surface * vec3(0.15, 0.12, 0.06);
	float fill = max(top, bottom) * inside;
	// Repeated instances of the supplied grain sprite fall through the neck.
	vec2 guv = vec2((p.x - 0.493) / 0.014, fract(p.y * 55.0 - phase * 8.0));
	vec4 falling = texture(grain_texture, clamp(guv, vec2(0.0), vec2(1.0)));
	float stream = step(0.0, guv.x) * step(guv.x, 1.0) * step(0.47, p.y) * step(p.y, lower_level) * flow;
	COLOR = vec4(mix(sand, falling.rgb, stream * falling.a), max(fill * 0.96, stream * falling.a) * inside);
}
