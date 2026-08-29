// TITLE_SCREEN_TENDRIL_BLOOM_ROT_V24
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
// V22 ERODING ROT CONTROLS
// -----------------------------------------------------------------------------
//
// Deliberately visible first-pass defaults. Once the motion feels right, width
// and colour can be dialled back without redesigning the simulation.

uniform float infection_growth_seconds : hint_range(12.0, 60.0) = 34.0;
uniform float infection_hold_seconds : hint_range(0.0, 20.0) = 4.0;
uniform float recovery_seconds : hint_range(15.0, 90.0) = 32.0;
uniform float infection_cycle_seconds : hint_range(55.0, 120.0) = 76.0;
uniform float infection_seed_stagger : hint_range(0.0, 12.0) = 2.8;

// V23 does not stop at an arbitrary radius. Main tendrils run to the
// horizontal UV edge; daughter growth runs to the vertical UV edge.
uniform float infection_edge_margin : hint_range(0.0, 0.08) = 0.012;
uniform float infection_front_seconds : hint_range(0.05, 1.5) = 0.16;
uniform float tendril_width : hint_range(0.008, 0.060) = 0.020;
uniform float tendril_wander : hint_range(0.0, 0.16) = 0.105;

// Local colonies grow at roots and branch junctions. These break the long
// tendrils into patches of corrosion instead of carving straight bands.
uniform float bloom_radius : hint_range(0.025, 0.12) = 0.060;
uniform float bloom_seconds : hint_range(1.0, 10.0) = 4.2;

// Material only. No moving material noise.
uniform vec3 rot_sick_tint : source_color = vec3(0.18, 0.26, 0.035);
uniform vec3 rot_fresh_tint : source_color = vec3(0.34, 0.55, 0.050);
uniform vec3 rot_crust_tint : source_color = vec3(0.09, 0.12, 0.025);

uniform float rot_mottle_scale : hint_range(8.0, 60.0) = 36.0;
uniform float rot_mottle_strength : hint_range(0.0, 1.0) = 0.38;
uniform float rot_pit_scale : hint_range(12.0, 90.0) = 56.0;
uniform float rot_pit_bite : hint_range(0.0, 1.0) = 0.26;


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


// The ORIGINAL reveal keeps its established FBM look.
// Importantly, V21 rot never calls FBM.
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


// Dedicated rot seeds. These are intentionally NOT source_point(); reveal
// sources are allowed to live in transparent space, infection seeds are not.
vec2 infection_anchor(float index) {
    float slot = mod(index, 12.0);

    // Hand-picked substantial strokes at several heights. V23 put every root
    // around y=0.50, which encouraged giant horizontal erosion bands.
    if (slot < 0.5)  return vec2(0.110, 0.43); // C upper-left
    if (slot < 1.5)  return vec2(0.118, 0.58); // C lower-left
    if (slot < 2.5)  return vec2(0.195, 0.44); // first O left/upper
    if (slot < 3.5)  return vec2(0.300, 0.56); // first R stem/lower
    if (slot < 4.5)  return vec2(0.397, 0.43); // second R stem/upper
    if (slot < 5.5)  return vec2(0.493, 0.58); // U lower stroke
    if (slot < 6.5)  return vec2(0.590, 0.44); // P stem/upper
    if (slot < 7.5)  return vec2(0.704, 0.56); // T stem/lower
    if (slot < 8.5)  return vec2(0.787, 0.43); // second O left/upper
    if (slot < 9.5)  return vec2(0.885, 0.56); // final R stem/lower
    if (slot < 10.5) return vec2(0.545, 0.46); // U/P neighborhood
    return vec2(0.340, 0.47);                  // R/R neighborhood
}


// x = soft body mask
// y = arrival time at this point on the segment
//
// Squared distance is used deliberately: no sqrt/length per segment.
vec2 rot_segment(
    vec2 p,
    vec2 a,
    vec2 b,
    float width,
    float start_seconds,
    float duration_seconds
) {
    vec2 ab = b - a;
    vec2 ap = p - a;

    float denom = max(
        dot(ab, ab),
        0.000001
    );

    float along = clamp(
        dot(ap, ab) / denom,
        0.0,
        1.0
    );

    vec2 nearest = a + ab * along;
    vec2 d = p - nearest;

    float d2 = dot(d, d);
    float w2 = width * width;

    float body = 1.0 - smoothstep(
        w2 * 0.48,
        w2 * 1.10,
        d2
    );

    float arrival = (
        start_seconds
        + along * duration_seconds
    );

    arrival = mix(
        999.0,
        arrival,
        step(0.001, body)
    );

    return vec2(
        body,
        arrival
    );
}

// x = soft bloom body
// y = arrival time of the outward-growing local colony
//
// Uses squared radius so it stays cheap. The slightly non-linear radial timing
// is useful here: a bloom establishes quickly near its seed, then creeps at the
// perimeter.
vec2 rot_bloom(
    vec2 p,
    vec2 center,
    float radius,
    float start_seconds,
    float duration_seconds
) {
    vec2 d = p - center;
    float d2 = dot(d, d);
    float r2 = max(radius * radius, 0.000001);

    float normalized_d2 = clamp(
        d2 / r2,
        0.0,
        1.0
    );

    float body = 1.0 - smoothstep(
        0.48,
        1.04,
        normalized_d2
    );

    float arrival = (
        start_seconds
        + normalized_d2 * duration_seconds
    );

    arrival = mix(
        999.0,
        arrival,
        step(0.001, body)
    );

    return vec2(
        body,
        arrival
    );
}



// -----------------------------------------------------------------------------
// FRAGMENT
// -----------------------------------------------------------------------------

void fragment() {
    vec4 c = texture(TEXTURE, UV);

    // -------------------------------------------------------------------------
    // ORIGINAL REVEAL — intentionally retained from V20
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
    // V24 TENDRILS + LOCAL BLOOMS
    // -------------------------------------------------------------------------
    //
    // Four staggered deterministic networks.
    //
    // Each network is:
    //   3 thin connected main tendril segments
    //   2 daughter tendrils seeded from reached points
    //   1 granddaughter seeded from daughter #1
    //   several cheap local blooms at established junctions
    //
    // There is NO moving noise and NO noise call inside a segment loop.
    // Overlaps use max(), not additive stacking, so they stay defined instead
    // of averaging into a smoky haze.

    float grain = value_noise(
        UV * rot_mottle_scale
        + vec2(
            run_seed * 0.137,
            run_seed * 0.071
        )
    );

    float width_mod = mix(
        0.82,
        1.18,
        grain
    );

    float rot_amount = 0.0;
    float fresh_amount = 0.0;
    float decay_amount = 0.0;
    float erosion_amount = 0.0;

    // Aspect-corrected infection working space.
    vec2 p = vec2(
        UV.x * 2.35,
        UV.y
    );

    for (int i = 0; i < 4; i++) {
        float fi = float(i);

        float h1 = hash21(
            vec2(
                run_seed * 0.173
                + fi * 17.31,
                19.7 + fi * 3.1
            )
        );

        float h2 = hash21(
            vec2(
                41.3 + fi * 13.9,
                run_seed * 0.097
                + fi * 5.7
            )
        );

        float h3 = hash21(
            vec2(
                run_seed * 0.131
                + fi * 29.1,
                73.7 + fi * 11.3
            )
        );

        float seed_delay = (
            fi * infection_seed_stagger
            + h1 * 0.65
        );

        float raw_clock = (
            living_time - seed_delay
        );

        float started = step(
            0.0,
            raw_clock
        );

        float cycle_index = floor(
            max(raw_clock, 0.0)
            / infection_cycle_seconds
        );

        float local_clock = mod(
            max(raw_clock, 0.0),
            infection_cycle_seconds
        );

        // Change the starting letter each cycle.
        float anchor_slot = mod(
            fi * 3.0
            + cycle_index * 2.0
            + floor(run_seed * 12.0),
            12.0
        );

        vec2 anchor_uv = infection_anchor(
            anchor_slot
        );

        vec2 p0 = vec2(
            anchor_uv.x * 2.35,
            anchor_uv.y
        );

        // ---------------------------------------------------------
        // V24 EDGE-SEEKING TENDRILS
        // ---------------------------------------------------------
        //
        // There is no arbitrary infection radius anymore.
        //
        // The primary tendril keeps travelling until it reaches the LEFT or
        // RIGHT edge of this shader's pixel/UV area. Daughter tendrils bud from
        // already infected points and continue until they reach the TOP or
        // BOTTOM edge. A granddaughter then turns back across the title.
        //
        // The geometry remains fixed for the lifetime of the outbreak; only
        // the infection front advances along it.

        float x_min = infection_edge_margin * 2.35;
        float x_max = (1.0 - infection_edge_margin) * 2.35;
        float y_min = infection_edge_margin;
        float y_max = 1.0 - infection_edge_margin;

        // Left-side roots travel right. Right-side roots travel left.
        // Middle roots choose a seeded direction.
        float horizontal_sign = mix(
            1.0,
            -1.0,
            step(0.50, anchor_uv.x)
        );

        if (
            anchor_uv.x > 0.43
            && anchor_uv.x < 0.57
        ) {
            horizontal_sign = (
                step(0.5, h1) * 2.0
                - 1.0
            );
        }

        float target_x = mix(
            x_min,
            x_max,
            step(0.0, horizontal_sign)
        );

        // Give the main line a gentle overall slope, but keep it inside the
        // pixel area so horizontal spread always reaches its screen-side edge.
        float target_y = clamp(
            p0.y + (h1 - 0.5) * 0.24,
            y_min,
            y_max
        );

        vec2 p3 = vec2(
            target_x,
            target_y
        );

        vec2 primary_delta = p3 - p0;
        vec2 primary_dir = normalize(primary_delta);
        vec2 primary_perp = vec2(
            -primary_dir.y,
            primary_dir.x
        );

        // Crooked intermediate points. They do not shorten the path: p3 is
        // still the actual horizontal boundary.
        vec2 p1 = mix(
            p0,
            p3,
            0.31
        );

        p1 += primary_perp * (
            (h2 - 0.5)
            * tendril_wander
            * 1.25
        );

        p1.y = clamp(
            p1.y,
            y_min,
            y_max
        );

        vec2 p2 = mix(
            p0,
            p3,
            0.64
        );

        p2 += primary_perp * (
            (h3 - 0.5)
            * tendril_wander
            * 1.55
        );

        p2.y = clamp(
            p2.y,
            y_min,
            y_max
        );

        // Daughter #1 buds from the first third of established growth and runs
        // all the way to a vertical edge.
        vec2 d1_seed = mix(
            p0,
            p1,
            0.72
        );

        float d1_to_top = step(
            0.5,
            h2
        );

        float d1_target_y = mix(
            y_min,
            y_max,
            d1_to_top
        );

        vec2 d1_end = vec2(
            clamp(
                d1_seed.x
                + (h3 - 0.5) * 0.34,
                x_min,
                x_max
            ),
            d1_target_y
        );

        // Daughter #2 starts later on the main line and deliberately seeks the
        // opposite vertical edge, so the network expands through the full
        // pixel area rather than collecting around one little root.
        vec2 d2_seed = mix(
            p1,
            p2,
            0.72
        );

        float d2_target_y = mix(
            y_max,
            y_min,
            d1_to_top
        );

        vec2 d2_end = vec2(
            clamp(
                d2_seed.x
                + (h1 - 0.5) * 0.30,
                x_min,
                x_max
            ),
            d2_target_y
        );

        // Granddaughter buds FROM daughter #1 and heads horizontally toward
        // whichever screen edge is farther away from that daughter seed.
        vec2 gd_seed = mix(
            d1_seed,
            d1_end,
            0.58
        );

        float gd_left_distance = gd_seed.x - x_min;
        float gd_right_distance = x_max - gd_seed.x;

        float gd_target_x = mix(
            x_min,
            x_max,
            step(
                gd_left_distance,
                gd_right_distance
            )
        );

        vec2 gd_end = vec2(
            gd_target_x,
            clamp(
                gd_seed.y
                + (h2 - 0.5) * 0.18,
                y_min,
                y_max
            )
        );

        float main_1_duration = infection_growth_seconds * 0.32;
        float main_2_duration = infection_growth_seconds * 0.33;
        float main_3_duration = infection_growth_seconds * 0.35;

        float main_2_start = main_1_duration;
        float main_3_start = main_1_duration + main_2_duration;

        // Branches wait until their parent point has already been infected.
        float d1_start = (
            main_1_duration * 0.58
            + 0.4
        );

        float d2_start = (
            main_2_start
            + main_2_duration * 0.58
            + 0.5
        );

        float d1_duration = infection_growth_seconds * 0.43;
        float d2_duration = infection_growth_seconds * 0.36;

        float gd_start = (
            d1_start
            + d1_duration * 0.56
            + 0.4
        );

        float gd_duration = infection_growth_seconds * 0.27;

        float base_width = (
            tendril_width * width_mod
        );

        // Root knot: visible immediately.
        vec2 root_delta = p - p0;
        float root_d2 = dot(
            root_delta,
            root_delta
        );

        float root_w = base_width * 1.30;
        float root_w2 = root_w * root_w;

        float root_body = 1.0 - smoothstep(
            root_w2 * 0.42,
            root_w2,
            root_d2
        );

        float best_body = root_body;

        float best_arrival = mix(
            999.0,
            0.0,
            step(0.001, root_body)
        );

        vec2 seg;

        // Main 1.
        seg = rot_segment(
            p,
            p0,
            p1,
            base_width,
            0.0,
            main_1_duration
        );

        best_body = max(best_body, seg.x);
        best_arrival = min(best_arrival, seg.y);

        // Main 2.
        seg = rot_segment(
            p,
            p1,
            p2,
            base_width * 0.94,
            main_2_start,
            main_2_duration
        );

        best_body = max(best_body, seg.x);
        best_arrival = min(best_arrival, seg.y);

        // Main 3.
        seg = rot_segment(
            p,
            p2,
            p3,
            base_width * 0.88,
            main_3_start,
            main_3_duration
        );

        best_body = max(best_body, seg.x);
        best_arrival = min(best_arrival, seg.y);

        // Daughter 1.
        seg = rot_segment(
            p,
            d1_seed,
            d1_end,
            base_width * 0.78,
            d1_start,
            d1_duration
        );

        best_body = max(best_body, seg.x);
        best_arrival = min(best_arrival, seg.y);

        // Daughter 2.
        seg = rot_segment(
            p,
            d2_seed,
            d2_end,
            base_width * 0.72,
            d2_start,
            d2_duration
        );

        best_body = max(best_body, seg.x);
        best_arrival = min(best_arrival, seg.y);

        // Granddaughter.
        seg = rot_segment(
            p,
            gd_seed,
            gd_end,
            base_width * 0.64,
            gd_start,
            gd_duration
        );

        best_body = max(best_body, seg.x);
        best_arrival = min(best_arrival, seg.y);

        // ---------------------------------------------------------
        // LOCAL CORROSION BLOOMS
        // ---------------------------------------------------------
        //
        // Thin tendrils carry the infection. At roots and branch junctions
        // the infection establishes a local colony and eats outward before
        // continuing. This prevents the edge-seeking network from reading as
        // a set of horizontal/vertical slices cut through the lettering.
        //
        // width_mod is static per pixel, so it roughens bloom boundaries for
        // free without another noise call.

        vec2 bloom;

        bloom = rot_bloom(
            p,
            p0,
            bloom_radius * width_mod * (0.90 + h1 * 0.18),
            0.0,
            bloom_seconds
        );

        best_body = max(best_body, bloom.x);
        best_arrival = min(best_arrival, bloom.y);

        bloom = rot_bloom(
            p,
            p1,
            bloom_radius * width_mod * (0.78 + h2 * 0.20),
            main_1_duration * 0.70,
            bloom_seconds * 0.90
        );

        best_body = max(best_body, bloom.x);
        best_arrival = min(best_arrival, bloom.y);

        bloom = rot_bloom(
            p,
            p2,
            bloom_radius * width_mod * (0.72 + h3 * 0.22),
            main_2_start + main_2_duration * 0.68,
            bloom_seconds * 0.86
        );

        best_body = max(best_body, bloom.x);
        best_arrival = min(best_arrival, bloom.y);

        bloom = rot_bloom(
            p,
            d1_seed,
            bloom_radius * width_mod * (0.68 + h1 * 0.18),
            d1_start + d1_duration * 0.18,
            bloom_seconds * 0.78
        );

        best_body = max(best_body, bloom.x);
        best_arrival = min(best_arrival, bloom.y);

        bloom = rot_bloom(
            p,
            d2_seed,
            bloom_radius * width_mod * (0.62 + h2 * 0.18),
            d2_start + d2_duration * 0.18,
            bloom_seconds * 0.74
        );

        best_body = max(best_body, bloom.x);
        best_arrival = min(best_arrival, bloom.y);

        bloom = rot_bloom(
            p,
            gd_seed,
            bloom_radius * width_mod * (0.52 + h3 * 0.14),
            gd_start + gd_duration * 0.16,
            bloom_seconds * 0.66
        );

        best_body = max(best_body, bloom.x);
        best_arrival = min(best_arrival, bloom.y);

        // Infection is a front moving down fixed geometry and expanding
        // outward through local colonies.
        float reached = smoothstep(
            best_arrival,
            best_arrival + infection_front_seconds,
            local_clock
        );

        reached *= best_body;
        reached *= started;

        // Every pixel ages from its OWN arrival time.
        // Root -> oldest -> heals first.
        // New branch tips -> youngest -> stay green.
        float pixel_age = max(
            local_clock - best_arrival,
            0.0
        );

        float recovery_age = max(
            pixel_age - infection_hold_seconds,
            0.0
        );

        float recovery_progress = clamp(
            recovery_age
            / max(recovery_seconds, 0.001),
            0.0,
            1.0
        );

        // The infection remains anchored, but its MATERIAL ages.
        // A young point is merely sick. Older points corrode, then disappear.
        // Near the end of the lifetime the original lettering returns, which
        // keeps the title alive without snapping an entire colony off at once.
        float persistence = pow(
            1.0 - recovery_progress,
            0.52
        );

        float layer = reached * persistence;

        // Only the newest edge gets a hint of green. This is intentionally
        // narrow so the effect reads as damage to the gold, not green paint.
        float fresh = reached * (
            1.0 - smoothstep(
                1.2,
                4.8,
                pixel_age
            )
        );

        // Established corrosion follows behind the green edge.
        float decay = reached * smoothstep(
            2.5,
            8.5,
            pixel_age
        ) * persistence;

        // Mature corrosion destroys the glyph itself. Because this is also
        // multiplied by persistence, the oldest holes eventually restore
        // gradually instead of popping back in a single frame.
        float erosion = reached * smoothstep(
            6.0,
            15.0,
            pixel_age
        ) * persistence;

        rot_amount = max(rot_amount, layer);
        fresh_amount = max(fresh_amount, fresh);
        decay_amount = max(decay_amount, decay);
        erosion_amount = max(erosion_amount, erosion);
    }

    rot_amount *= (
        living_enabled * reveal
    );

    fresh_amount *= (
        living_enabled * reveal
    );

    decay_amount *= (
        living_enabled * reveal
    );

    erosion_amount *= (
        living_enabled * reveal
    );

    // -------------------------------------------------------------------------
    // V24 CORROSION -> DESTRUCTION MATERIAL
    // -------------------------------------------------------------------------
    //
    // The tendril is not a coloured overlay anymore. It attacks the existing
    // lettering in place:
    //
    //     gold -> tarnished -> crusted -> eaten away -> slowly restored
    //
    // Green is confined mostly to the young advancing edge.

    float pit_noise = value_noise(
        UV * rot_pit_scale
        + vec2(
            run_seed * 0.091,
            run_seed * 0.173
        )
    );

    float fine_grain = value_noise(
        UV * (rot_mottle_scale * 1.63)
        + vec2(
            run_seed * 0.271,
            run_seed * 0.119
        )
    );

    // Preserve the original gold texture. All corrosion colours MULTIPLY the
    // title rather than replacing it with a flat green patch.
    vec3 fresh_material = revealed_rgb * mix(
        vec3(1.0),
        rot_fresh_tint * 1.35,
        0.58
    );

    vec3 sick_material = revealed_rgb * mix(
        vec3(1.0),
        rot_sick_tint,
        0.84
    );

    vec3 rotted = mix(
        revealed_rgb,
        fresh_material,
        fresh_amount * 0.62
    );

    // Behind the fresh edge the metal darkens and loses its warm gold.
    rotted = mix(
        rotted,
        sick_material,
        decay_amount * 0.92
    );

    // Dry, fixed crust interrupts the remaining material before it vanishes.
    float crust = smoothstep(
        0.50,
        0.78,
        grain * 0.62 + fine_grain * 0.38
    );

    rotted = mix(
        rotted,
        rotted * rot_crust_tint,
        crust * decay_amount * rot_mottle_strength
    );

    // Erosion is thresholded against two STATIC material fields. At first only
    // tiny pits vanish. As a point ages, the missing pieces join together until
    // most of that part of the glyph is simply gone. This is destruction, not
    // translucent green fog.
    float erosion_field = (
        erosion_amount * 1.18
        + (0.5 - grain) * 0.26
        + (0.5 - pit_noise) * 0.20
    );

    float destroyed = smoothstep(
        0.32,
        0.82,
        erosion_field
    );

    // A few hard cavities arrive slightly ahead of total structural failure.
    float hard_pits = step(
        pit_noise,
        0.14 + erosion_amount * 0.34
    ) * smoothstep(
        0.18,
        0.68,
        decay_amount
    );

    destroyed = max(
        destroyed,
        hard_pits * 0.78
    );

    // Near-destruction also darkens the surviving crumbs before alpha removes
    // them, which makes the disappearance read as corrosion rather than fade.
    rotted *= mix(
        1.0,
        0.30,
        destroyed * 0.72
    );

    COLOR = vec4(
        rotted,
        c.a * reveal * (1.0 - destroyed)
    );
}
