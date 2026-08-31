// TITLE_SCREEN_REVERSE_FORMATION_EXIT_V31B
shader_type canvas_item;

// -----------------------------------------------------------------------------
// ORIGINAL TITLE REVEAL CONTROLS
// -----------------------------------------------------------------------------

uniform float progress : hint_range(0.0, 1.2) = 0.0;
uniform float run_seed = 1.0;

uniform float edge_softness : hint_range(0.002, 0.08) = 0.018;
uniform float warp_strength : hint_range(0.0, 0.15) = 0.055;
uniform float tendril_strength : hint_range(0.0, 0.30) = 0.13;

uniform vec3 edge_tint : source_color = vec3(0.72, 0.60, 0.34);
uniform float edge_strength : hint_range(0.0, 1.5) = 0.28;

// These names are intentionally preserved because the title controller already
// drives them.
uniform float living_enabled : hint_range(0.0, 1.0) = 0.0;
uniform float living_time = 0.0;

// -----------------------------------------------------------------------------
// V27 CORRUPTION WAVE
// -----------------------------------------------------------------------------
//
// One readable event:
//   sickly wave enters from the left -> sweeps across -> exits -> rest -> repeat.
//
// V29 keeps the slower V28 sweep range, but restores a deliberate clean-title
// hold before ANY living effect begins. For the first ~6 seconds the revealed
// logo is left alone. After that, the wave and a much more legible slow pulse
// run continuously; there is still no post-wave flash.
//
// There is no crawler simulation, no infection graph, no FBM in the wave, and
// no alpha erosion.

// Give the reveal room to finish before the title starts breathing/rotting.
uniform float effect_delay_seconds : hint_range(0.0, 15.0) = 6.0;

uniform float wave_cycle_seconds : hint_range(10.0, 22.0) = 12.5;
uniform float wave_sweep_min_seconds : hint_range(4.0, 12.0) = 6.0;
uniform float wave_sweep_max_seconds : hint_range(5.0, 14.0) = 9.5;

uniform float wave_front_width : hint_range(0.004, 0.10) = 0.022;
uniform float wave_trail_width : hint_range(0.06, 0.50) = 0.24;
uniform float wave_shape_scale : hint_range(2.0, 30.0) = 8.0;
uniform float wave_shape_wander : hint_range(0.0, 0.12) = 0.035;

// Static breakup INSIDE the passing band. It never scrolls independently.
uniform float wave_material_scale : hint_range(4.0, 60.0) = 18.0;
uniform float wave_material_strength : hint_range(0.0, 1.0) = 0.42;

// Dark sickly green -> almost black-green.
uniform vec3 wave_sick_tint : source_color = vec3(0.26, 0.36, 0.075);
uniform vec3 wave_black_tint : source_color = vec3(0.055, 0.075, 0.020);
uniform float wave_corruption_strength : hint_range(0.0, 1.0) = 0.90;

// Persistent scars left behind by each corruption pass.
// A scar remains until the NEXT wave reaches that pixel and replaces it.

    uniform float wave_residue_strength : hint_range(0.0, 1.0) = 0.72;


    uniform float wave_residue_scale : hint_range(4.0, 80.0) = 18.0;


    uniform float wave_residue_threshold : hint_range(0.05, 0.90) = 0.34;


    uniform float wave_residue_black_strength : hint_range(0.0, 1.0) = 0.85;


// Narrow damp edge at the front. Deliberately not a huge neon halo.
uniform vec3 wave_front_tint : source_color = vec3(0.34, 0.42, 0.10);
uniform float wave_front_strength : hint_range(0.0, 1.0) = 0.20;

// Continuous breathing after the clean-title delay. V28's 11% dip was easy to
// miss; 20% is still restrained but should now read clearly as a heartbeat.
uniform float pulse_seconds : hint_range(2.0, 12.0) = 5.6;
uniform float pulse_depth : hint_range(0.0, 0.35) = 0.20;

// V31B exit transition. Controller still drives 0 -> 1 after confirmation.
// Disappearance reuses the ORIGINAL FORMATION FIELD itself, played backward.
uniform float exit_progress : hint_range(0.0, 1.0) = 0.0;
uniform float exit_front_sickness : hint_range(0.0, 1.0) = 0.72;


// -----------------------------------------------------------------------------
// CHEAP DETERMINISTIC NOISE
// -----------------------------------------------------------------------------

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}


vec2 hash22(vec2 p) {
    return vec2(
        hash21(p),
        hash21(p + vec2(71.17, 19.91))
    );
}


float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash21(i + vec2(0.0, 0.0) + run_seed);
    float b = hash21(i + vec2(1.0, 0.0) + run_seed);
    float c = hash21(i + vec2(0.0, 1.0) + run_seed);
    float d = hash21(i + vec2(1.0, 1.0) + run_seed);

    return mix(
        mix(a, b, u.x),
        mix(c, d, u.x),
        u.y
    );
}


// FBM remains ONLY for the original reveal that already looked good.
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < 4; i++) {
        value += value_noise(p) * amplitude;
        p = p * 2.03 + vec2(13.1, 7.7);
        amplitude *= 0.5;
    }

    return value;
}


vec2 source_point(float index) {
    vec2 r = hash22(
        vec2(
            run_seed * 0.173 + index * 17.31,
            run_seed * 0.097 + index * 43.17
        )
    );

    return vec2(
        mix(0.10, 0.90, r.x),
        mix(0.20, 0.80, r.y)
    );
}


// -----------------------------------------------------------------------------
// FRAGMENT
// -----------------------------------------------------------------------------

void fragment() {
    vec4 c = texture(TEXTURE, UV);

    // -------------------------------------------------------------------------
    // ORIGINAL REVEAL
    // -------------------------------------------------------------------------

    float warp_a = fbm(
        UV * 5.0
        + vec2(run_seed * 0.021, run_seed * 0.013)
    );

    float warp_b = fbm(
        UV * 5.0
        + vec2(31.7, 11.3)
        + vec2(run_seed * 0.017, run_seed * 0.029)
    );

    vec2 warped_uv = UV + (
        vec2(warp_a, warp_b) - vec2(0.5)
    ) * warp_strength;

    float nearest = 99.0;

    for (int i = 0; i < 5; i++) {
        vec2 s = source_point(float(i));
        vec2 delta = warped_uv - s;
        delta.x *= 1.18;
        nearest = min(nearest, length(delta));
    }

    float coarse = fbm(
        UV * 7.5
        + vec2(run_seed * 0.037, 23.0)
    );

    float ridge_noise = fbm(
        UV * 15.0
        + vec2(47.0, run_seed * 0.041)
    );

    float ridge = 1.0 - abs(
        ridge_noise * 2.0 - 1.0
    );

    ridge = pow(
        clamp(ridge, 0.0, 1.0),
        4.0
    );

    float fine = fbm(
        UV * 28.0
        + vec2(run_seed * 0.053, 79.0)
    );

    float arrival = nearest * 1.52;
    arrival += (coarse - 0.5) * 0.18;
    arrival += (fine - 0.5) * 0.045;
    arrival -= ridge * tendril_strength;

    arrival = clamp(
        0.025 + arrival,
        0.015,
        1.03
    );

    float reveal = smoothstep(
        arrival - edge_softness,
        arrival + edge_softness,
        progress
    );

    float edge = 1.0 - smoothstep(
        edge_softness * 0.45,
        edge_softness * 3.4,
        abs(progress - arrival)
    );

    edge *= reveal;

    vec3 revealed_rgb = (
        c.rgb
        + edge_tint * edge * edge_strength
    );

    // -------------------------------------------------------------------------
    // V27 LEFT-TO-RIGHT CORRUPTION WAVE
    // -------------------------------------------------------------------------

    float activity = clamp(
        living_enabled,
        0.0,
        1.0
    );

    float cycle_seconds = max(
        wave_cycle_seconds,
        wave_sweep_max_seconds + 0.75
    );

    float safe_time = max(
        living_time,
        0.0
    );

    // Old rule restored: reveal first, living title later. Before the delay,
    // effect_started is zero and the logo is exactly the clean revealed title.
    float effect_started = (
        activity
        * step(effect_delay_seconds, safe_time)
    );

    float effect_time = max(
        safe_time - effect_delay_seconds,
        0.0
    );

    float cycle_index = floor(
        effect_time / cycle_seconds
    );

    float local_clock = mod(
        effect_time,
        cycle_seconds
    );

    // Every pass picks a different duration, but remains linear and readable.
    float speed_random = hash21(
        vec2(
            run_seed * 13.71 + cycle_index * 17.0,
            91.0 + cycle_index * 3.0
        )
    );

    float sweep_min = min(
        wave_sweep_min_seconds,
        wave_sweep_max_seconds
    );

    float sweep_max = max(
        wave_sweep_min_seconds,
        wave_sweep_max_seconds
    );

    float sweep_seconds = mix(
        sweep_min,
        sweep_max,
        speed_random
    );

    float sweep_t = clamp(
        local_clock / max(sweep_seconds, 0.001),
        0.0,
        1.0
    );

    // Move far enough beyond each side that the ENTIRE trailing corruption
    // band has left before the post-pass glow begins.
    float travel_pad = wave_trail_width + 0.08;

    float wave_x = mix(
        -travel_pad,
        1.0 + travel_pad,
        sweep_t
    );

    // The front is not ruler-straight, but its shape is fixed for the duration
    // of each pass. Nothing crawls or swims independently.
    float front_shape = value_noise(
        vec2(
            UV.y * wave_shape_scale,
            run_seed * 0.31 + cycle_index * 4.73
        )
    );

    float local_front_x = (
        wave_x
        + (front_shape - 0.5) * wave_shape_wander
    );

    float behind_front = local_front_x - UV.x;

    float crossed = smoothstep(
        -wave_front_width,
        wave_front_width,
        behind_front
    );

    // A broad decaying tail behind the front. Farther behind = recovered metal.
    float trail = 1.0 - smoothstep(
        wave_trail_width * 0.22,
        wave_trail_width,
        behind_front
    );

    float wave_mask = (
        crossed
        * trail
        * effect_started
    );

    // One stationary material field breaks up the dark-green band without
    // turning it into animated smoke.
    float material = value_noise(
        UV * wave_material_scale
        + vec2(
            run_seed * 0.137,
            run_seed * 0.071
        )
    );

    float material_mod = mix(
        1.0 - wave_material_strength,
        1.0,
        material
    );

    float corruption = clamp(
        wave_mask
        * wave_corruption_strength
        * material_mod,
        0.0,
        1.0
    );

    // ---------------------------------------------------------------------
    // PERSISTENT CORRUPTION RESIDUE
    // ---------------------------------------------------------------------
    //
    // Before the current wave reaches a pixel, show residue generated by
    // the previous cycle. Once the new front crosses that pixel, replace
    // the old scar with the current cycles residue pattern.

    float previous_cycle_index = max(
        cycle_index - 1.0,
        0.0
    );

    float has_previous_cycle = step(
        1.0,
        cycle_index
    );

    vec2 residue_uv = UV * wave_residue_scale;

    float current_residue_field = value_noise(
        residue_uv
        + vec2(
            run_seed * 0.193 + cycle_index * 7.17,
            run_seed * 0.083 + cycle_index * 13.31
        )
    );

    float previous_residue_field = value_noise(
        residue_uv
        + vec2(
            run_seed * 0.193 + previous_cycle_index * 7.17,
            run_seed * 0.083 + previous_cycle_index * 13.31
        )
    );

    // Finer breakup so residue reads as damage/pitting rather than fog.
    float current_residue_detail = value_noise(
        UV * wave_residue_scale * 2.35
        + vec2(
            run_seed * 0.417 + cycle_index * 19.37,
            run_seed * 0.227 + cycle_index * 5.83
        )
    );

    float previous_residue_detail = value_noise(
        UV * wave_residue_scale * 2.35
        + vec2(
            run_seed * 0.417 + previous_cycle_index * 19.37,
            run_seed * 0.227 + previous_cycle_index * 5.83
        )
    );

    float residue_upper = min(
        wave_residue_threshold + 0.25,
        0.999
    );

    float current_residue = (
        smoothstep(
            wave_residue_threshold,
            residue_upper,
            current_residue_field
        )
        *
    mix(
            0.72,
            1.0,
            current_residue_detail
        )

        * wave_residue_strength
    );

    float previous_residue = (
        smoothstep(
            wave_residue_threshold,
            residue_upper,
            previous_residue_field
        )
        *
    mix(
            0.72,
            1.0,
            previous_residue_detail
        )

        * wave_residue_strength
        * has_previous_cycle
    );

    // Each pixel keeps its old scar until the current wave reaches it.
    float residue = (
        mix(
            previous_residue,
            current_residue,
            crossed
        )
        * effect_started
    );

    float active_residue_field = mix(
        previous_residue_field,
        current_residue_field,
        crossed
    );

    // The moving wave overwhelms the weaker scar while it passes.
    // After the tail leaves, persistent residue remains.
    float surface_corruption = max(
        corruption,
        residue
    );

    // Dark sickly oxidation while preserving the underlying metal texture.
    vec3 sick_rgb = revealed_rgb * wave_sick_tint;
    vec3 black_rgb = revealed_rgb * wave_black_tint;

    vec3 wave_rgb = mix(
        revealed_rgb,
        sick_rgb,
        surface_corruption
    );

    // Active-wave black rot.
    float active_deep_rot = (
        wave_mask
        * smoothstep(0.58, 0.88, material)
        * 0.72
    );

    // Persistent black-green pits left behind by the wave.
    float residue_deep_rot = (
        residue
        *
    smoothstep(
            0.55,
            0.82,
            active_residue_field
        )

        * wave_residue_black_strength
    );

    float deep_rot = clamp(
        max(
            active_deep_rot,
            residue_deep_rot
        ),
        0.0,
        1.0
    );

    wave_rgb = mix(
        wave_rgb,
        black_rgb,
        deep_rot
    );
        // Persistent dirty oxidation underneath the discrete pits.
    // This remains after the moving tail clears and is replaced
    // pixel-by-pixel when the next wave front crosses.
    float residue_stain = clamp(
        residue * (0.90 + active_residue_field * 0.55),
        0.0,
        1.0
    );

    vec3 residue_stain_rgb = revealed_rgb * vec3(0.16, 0.23, 0.035);

    wave_rgb = mix(
        wave_rgb,
        residue_stain_rgb,
        residue_stain * 0.72
    );

// Narrow damp/sick leading edge so the moving boundary reads immediately.
    float front_band = 1.0 - smoothstep(
        wave_front_width * 0.35,
        wave_front_width * 2.20,
        abs(behind_front)
    );

    wave_rgb += (
        wave_front_tint
        * front_band
        * wave_front_strength
        * effect_started
    );

    // -------------------------------------------------------------------------
    // DELAYED CONTINUOUS SLOW PULSE
    // -------------------------------------------------------------------------
    //
    // No post-pass glow. The title simply breathes forever: gently dims, then
    // returns to normal brightness. The wave rides inside that breathing state.

    float pulse_phase = mod(
        effect_time / max(pulse_seconds, 0.001),
        1.0
    );

    // Starts at full brightness, reaches the shallowest point halfway through
    // the cycle, then returns smoothly to full brightness.
    float pulse_wave = 0.5 - 0.5 * cos(
        pulse_phase * 6.28318531
    );

    float pulse_gain = mix(
        1.0,
        1.0 - pulse_depth * pulse_wave,
        effect_started
    );

    vec3 final_rgb = wave_rgb * pulse_gain;

    // -------------------------------------------------------------------------
    // V31B REVERSE FORMATION EXIT
    // -------------------------------------------------------------------------
    //
    // The opening already assigned every pixel an `arrival` value using the
    // warped five-source field, coarse/fine breakup, and tendril ridges.
    //
    // Opening:
    //     progress rises through arrival -> pixels appear.
    //
    // Exit:
    //     reverse_progress falls through the SAME arrival -> pixels disappear
    //     in exactly the opposite order.
    //
    // No left/right wipe exists here.

    float exit_t = clamp(
        exit_progress,
        0.0,
        1.0
    );

    // 1.20 is the same fully-revealed controller target. -0.06 is below the
    // minimum clamped arrival so even the earliest source pixels vanish.
    float reverse_progress = mix(
        1.20,
        -0.06,
        exit_t
    );

    // Same threshold equation as the original reveal, but driven backward.
    float reverse_alive = smoothstep(
        arrival - edge_softness,
        arrival + edge_softness,
        reverse_progress
    );

    // Same arrival boundary supplies the brief sickly death rim.
    float reverse_front = 1.0 - smoothstep(
        edge_softness * 0.45,
        edge_softness * 3.4,
        abs(reverse_progress - arrival)
    );

    // Keep the pre-confirmation frame perfectly unchanged at exit_progress = 0.
    float exit_started = step(
        0.0001,
        exit_t
    );

    float sick_front = (
        reverse_front
        * exit_started
        * exit_front_sickness
    );

    vec3 consumed_rgb = mix(
        final_rgb,
        final_rgb * wave_sick_tint,
        sick_front * 0.82
    );

    consumed_rgb = mix(
        consumed_rgb,
        final_rgb * wave_black_tint,
        sick_front * material * 0.76
    );

    float exit_alpha = mix(
        1.0,
        reverse_alive,
        exit_started
    );

    COLOR = vec4(
        consumed_rgb,
        c.a * reveal * exit_alpha
    );
}
