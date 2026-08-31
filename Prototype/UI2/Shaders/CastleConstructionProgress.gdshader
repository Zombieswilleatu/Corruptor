shader_type canvas_item;
render_mode unshaded;

// UI2_CASTLE_CONSTRUCTION_REVEAL_V1
// CASTLE_CONSTRUCTION_SHADER_GODOT42_HOTFIX_V4
// UI2_CASTLE_BUILD_PROGRESS_HOLDBUTTON_V2
// UI2_CASTLE_BOTTOM_FILL_CUTLINE_V1
// UI2_CASTLE_BROKEN_MASONRY_CUTLINE_V2
//
// Built portion fills upward from the bottom.
// Unbuilt portion remains a dark architectural ghost.
// Boundary is a few broad, uneven masonry rises/valleys — not a repeating wave.
uniform float build_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float art_top : hint_range(0.0, 1.0) = 0.12;
uniform float art_bottom : hint_range(0.0, 1.0) = 0.94;
uniform vec4 outline_color : source_color = vec4(0.80, 0.62, 0.23, 1.0);


float _luma(vec3 color_value) {
	return dot(
		color_value,
		vec3(0.299, 0.587, 0.114)
	);
}


float _trapezoid(
	float x,
	float rise_start,
	float rise_end,
	float fall_start,
	float fall_end
) {
	float up = smoothstep(
		rise_start,
		rise_end,
		x
	);

	float down = 1.0 - smoothstep(
		fall_start,
		fall_end,
		x
	);

	return min(
		up,
		down
	);
}


void fragment() {
	vec4 source_pixel = COLOR;
	vec4 result = source_pixel;

	float safe_height = max(
		0.0001,
		art_bottom - art_top
	);

	if (
		build_ratio < 0.999
		&& UV.y >= art_top
		&& UV.y <= art_bottom
	) {
		float local_y = (
			(UV.y - art_top)
			/ safe_height
		);

		// 0 at top, 1 at bottom. Built amount grows upward from the bottom.
		float fill_start = (
			1.0 - build_ratio
		);

		float x = UV.x;

		// Hand-shaped broken masonry profile:
		// broad rise -> long shelf -> valley -> uneven shelf -> smaller rise.
		float profile = 0.0;

		profile += (
			_trapezoid(
				x,
				0.035,
				0.085,
				0.235,
				0.285
			)
			* -0.045
		);

		profile += (
			_trapezoid(
				x,
				0.285,
				0.345,
				0.445,
				0.495
			)
			* 0.030
		);

		profile += (
			_trapezoid(
				x,
				0.485,
				0.540,
				0.685,
				0.735
			)
			* -0.035
		);

		profile += (
			_trapezoid(
				x,
				0.735,
				0.790,
				0.905,
				0.955
			)
			* 0.020
		);

		// Tiny irregularity only; enough to avoid vector-perfect shelves.
		float grit = (
			sin(x * 47.0 + 0.8) * 0.0025
			+ sin(x * 83.0 + 2.4) * 0.0015
		);

		float cutline = clamp(
			fill_start
			+ profile
			+ grit,
			0.0,
			1.0
		);

		float source_luma = _luma(
			source_pixel.rgb
		);

		float faint_structure = smoothstep(
			0.08,
			0.22,
			source_luma
		);

		float hard_structure = smoothstep(
			0.22,
			0.48,
			source_luma
		);

		vec3 ghost_rgb = (
			vec3(0.004, 0.003, 0.002)
			+ outline_color.rgb
				* (
					faint_structure * 0.040
					+ hard_structure * 0.34
				)
		);

		float built_mask = smoothstep(
			-0.0015,
			0.0040,
			local_y - cutline
		);

		result.rgb = mix(
			ghost_rgb,
			source_pixel.rgb,
			built_mask
		);
		result.a = source_pixel.a;

		// Thin engraved edge: enough to read the frontier without glowing.
		float frontier_band = (
			1.0
			- smoothstep(
				0.0,
				0.0045,
				abs(local_y - cutline)
			)
		);

		result.rgb = mix(
			result.rgb,
			outline_color.rgb,
			frontier_band * 0.58
		);
	}

	COLOR = result;
}
