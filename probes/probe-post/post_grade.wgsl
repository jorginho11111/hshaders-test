// Mellow's final pass (program/final.fsh): tone mapping (Uchimura is its
// default operator), then vignette, vibrance, saturation and contrast in the
// picture's own space, film grain when asked for, and a quiet dither at the end.

override tonemap: u32 = 0u;
override exposure: f32 = 1.1;
override vibrance: f32 = 1.2;
override saturation: f32 = 1.0;
override contrast: f32 = 1.0;
override vignette_opacity: f32 = 0.0;
override vignette_falloff: f32 = 0.75;
override film_grain: bool = false;
override film_grain_strength: f32 = 0.05;

fn post(input: PostInput) -> vec4<f32> {
    var c = input.color.rgb * exposure;

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
