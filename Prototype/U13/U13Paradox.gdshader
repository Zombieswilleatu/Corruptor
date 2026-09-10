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
	// Rolling displacement and uneven interference bands suggest an oil film.
	vec2 rolled = rotation * p;
	float flow = sin(rolled.y * 8.0 - phase * 2.0 + sin(rolled.x * 5.0 + phase));
	rolled.x += flow * 0.055 * feather * strength;
	rolled.y += sin(rolled.x * 7.0 + phase * 1.6) * 0.035 * feather * strength;
	// Keep the approved oil palette, but move the sampled battlefield itself.
	// The old angle barely changed during the sustained part of the effect.
	float interior = 1.0 - smoothstep(0.0, 1.0, dist);
	float twist = (swirl * 1.5 + sin(phase * 1.8) * (2.8 + chaos)) * interior;
	twist += sin(dist * 10.0 - phase * 3.0) * chaos * 0.4 * feather;
	twist *= strength;
	mat2 pixel_rotation = mat2(vec2(cos(twist), sin(twist)), vec2(-sin(twist), cos(twist)));
	vec2 pulled = pixel_rotation * p;
	// Pull inward while twisting, keeping the normal effect a clean spiral.
	float pull = 1.0 - 0.28 * interior * strength;
	pulled *= pull;
	pulled += vec2(sin(p.y * 9.0 - phase * 3.4), cos(p.x * 8.0 + phase * 2.7)) * 0.08 * chaos * feather * strength;
	vec2 warped = center_uv + pulled * radii;
	warped = clamp(warped, clip_uv.xy, clip_uv.zw);
	vec3 color = texture(screen_texture, warped).rgb;
	float film = dist * 2.8 + flow * 0.35 + sin(rolled.x * 4.0 - rolled.y * 3.0 + phase * 0.7) * 0.45 - phase * 0.32;
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831853 * (film + vec3(0.0, 0.33, 0.67)));
	// Saturated, bounded sheen: never invert the dark field into a white disk.
	float sheen = 0.26 + 0.12 * sin(film * 6.2831853);
	vec3 oil = color * (vec3(0.55) + rainbow * 0.45) + rainbow * sheen;
	float inside_lane = step(clip_uv.x, SCREEN_UV.x) * step(clip_uv.y, SCREEN_UV.y) * step(SCREEN_UV.x, clip_uv.z) * step(SCREEN_UV.y, clip_uv.w);
	COLOR = vec4(oil, feather * strength * inside_lane);
}
