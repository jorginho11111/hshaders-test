// Mellow's bloom + final pass in ONE [[post]] pass (glow added, then tone map
// and grade). Merged on purpose: a chain of two passes makes the app allocate
// Rgba16Float chain targets and a history texture, which mobile GLES drivers
// choke on (the app closes); a single pass draws straight to the screen.
//
// Bloom (BLOOM, BLOOM_STRENGTH 0.4, BLOOM_CURVE 0.5): a soft halo of the
// brightest pixels on two rings of taps. The final pass (program/final.fsh):
// tone mapping (Uchimura default), vignette, vibrance, saturation, contrast,
// film grain when asked for, and a quiet dither.

override bloom_strength: f32 = 0.4;
override bloom_curve: f32 = 0.5;
override tonemap: u32 = 0u;
override exposure: f32 = 1.1;
override vibrance: f32 = 1.2;
override saturation: f32 = 1.0;
override contrast: f32 = 1.0;
override vignette_opacity: f32 = 0.0;
override vignette_falloff: f32 = 0.75;
override film_grain: bool = false;
override film_grain_strength: f32 = 0.05;

fn bright(uv: vec2<f32>) -> vec3<f32> {
    let c = textureSampleLevel(previous, linear_sampler, uv, 0.0).rgb;
    let sky = select(1.0, 0.25, depth_at(uv) == 0.0);
    return c * smoothstep(bloom_curve, 1.0, get_luminance(c)) * sky;
}

fn post(input: PostInput) -> vec4<f32> {
    // The bloom halo, added to the picture.
    var color = input.color;
    if (bloom_strength > 0.0) {
        let step_uv = frame.resolution.y / 720.0 / frame.resolution;
        var sum = vec3<f32>(0.0);
        for (var i = 0; i < 12; i++) {
            let angle = f32(i) * 0.5235988;
            let radius = select(3.0, 7.0, (i & 1) == 1);
            let offset = vec2<f32>(cos(angle), sin(angle)) * radius * step_uv;
            sum = sum + bright(input.uv + offset);
        }
        color = vec4<f32>(color.rgb + sum * (bloom_strength / 8.0), color.a);
    }

    // The grade.
    var c = color.rgb * exposure;

    // Tone map: Uchimura (Mellow's operator 6), AgX Punchy (its operator 7),
    // the fitted ACES curve (its operator 1), or nothing.
    if (tonemap == 0u) {
        c = uchimura(c);
    } else if (tonemap == 1u) {
        c = agx_punchy(c);
    } else if (tonemap == 2u) {
        c = aces_film(c);
    }

    // Film grain (off by default, as in Mellow).
    if (film_grain) {
        let jitter = vec2<f32>(f32(frame.frame_index) * 17.0, f32(frame.frame_index) * 29.0);
        let g = hash12(input.pixel + jitter);
        c = c + (vec3<f32>(g) - vec3<f32>(0.5)) * film_grain_strength;
    }

    // Vignette (Mellow's apply_vignette; opacity 0 turns it off).
    let pos = (input.uv - vec2<f32>(0.5)) * vignette_opacity;
    let strength = pow(dot(pos, pos), 2.0 - vignette_falloff);
    c = c * (1.0 - min(strength, 1.0));

    // Mellow's grade (final.fsh: vibrance, saturation, contrast).
    c = apply_vibrance(c, vibrance);
    c = apply_saturation(c, saturation);
    c = apply_contrast(c, contrast);

    // The dither Mellow always leaves in at the end.
    c = c + (vec3<f32>(ign(input.pixel)) - vec3<f32>(0.5)) / 128.0;

    return vec4<f32>(clamp(c, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
