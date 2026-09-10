shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// Canonical circle projected onto the battlefield's two differently scaled axes.
uniform vec2 center_uv = vec2(0.5);
uniform vec2 radius_uv = vec2(0.05);
uniform vec4 clip_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float swirl = 2.5;
uniform float phase = 0.0;
uniform float chaos = 0.0;

void fragment() {
	vec2 radii = max(radius_uv, vec2(0.00001));
	vec2 p = (SCREEN_UV - center_uv) / radii;
	float dist = length(p);
	float feather = 1.0 - smoothstep(0.72, 1.0, dist);
	float edge_warp = sin(atan(p.y, p.x) * 9.0 + phase * 3.0) * chaos * 0.12;
	float angle = (1.0 - clamp(dist + edge_warp, 0.0, 1.0)) * swirl * strength + sin(phase) * 0.2 * feather;
	mat2 rotation = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	vec2 warped = center_uv + (rotation * p) * radii;
	warped = clamp(warped, clip_uv.xy, clip_uv.zw);
	vec3 color = texture(screen_texture, warped).rgb;
	vec3 negative = vec3(1.0) - color;
	float inside_lane = step(clip_uv.x, SCREEN_UV.x) * step(clip_uv.y, SCREEN_UV.y) * step(SCREEN_UV.x, clip_uv.z) * step(SCREEN_UV.y, clip_uv.w);
	COLOR = vec4(mix(color, negative, 0.88), feather * strength * inside_lane);
}
