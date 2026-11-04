// Shared helpers for "Mellow" (Horizon conversion).
// Colour grading and tone mapping ported from Mellow Shaders by TheCMK (MIT),
// https://codeberg.org/TheCMK/mellow-shader — lib/tonemap.glsl, lib/tonemap_operators.glsl,
// program/final.fsh. Tone map operators originally from dmnsgn/glsl-tone-map
// (MIT, Copyright (C) 2019 Damien Seguin): Lottes 2016 and Uchimura 2017.
// AgX minimal implementation after Benjamin Wrensch (iolite-engine), with the
// matrices of the Filament project (Apache 2.0) and EaryChow's AgX LUT generator.

fn get_luminance(c: vec3<f32>) -> f32 {
    return dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
}

// Mellow's apply_saturation.
fn apply_saturation(color: vec3<f32>, sat: f32) -> vec3<f32> {
    return mix(vec3<f32>(get_luminance(color)), color, sat);
}

// Mellow's apply_vibrance: lifts colour where it is quiet, leaves strong colour be.
fn apply_vibrance(color: vec3<f32>, intensity: f32) -> vec3<f32> {
    let mn = min(color.r, min(color.g, color.b));
    let mx = max(color.r, max(color.g, color.b));
    let sat = (1.0 - clamp(mx - mn, 0.0, 1.0)) * clamp(1.0 - mx, 0.0, 1.0) * get_luminance(color) * 5.0;
    let lightness = vec3<f32>((mn + mx) * 0.5);
    return mix(color, mix(lightness, color, intensity), sat);
}

// Mellow's apply_contrast.
fn apply_contrast(color: vec3<f32>, contrast: f32) -> vec3<f32> {
    return (color - vec3<f32>(0.5)) * contrast + vec3<f32>(0.5);
}

// Uchimura 2017, "HDR theory and practice" — Mellow's default tone map (operator 6).
fn uchimura_channel(x_in: f32) -> f32 {
    let P = 1.0;
    let a = 1.0;
    let m = 0.22;
    let l = 0.4;
    let c = 1.33;
    let b = 0.0;
    let x = max(x_in, 0.0);

    let l0 = ((P - m) * l) / a;
    let s0 = m + l0;
    let s1 = m + a * l0;
    let c2 = (a * P) / (P - s1);
    let cp = -c2 / P;

    let w0 = 1.0 - smoothstep(0.0, m, x);
    let w2 = step(s0, x);
    let w1 = 1.0 - w0 - w2;

    let toe = m * pow(x / m, c) + b;
    let shoulder = P - (P - s1) * exp(cp * (x - s0));
    let linear = m + a * (x - m);
    return toe * w0 + linear * w1 + shoulder * w2;
}

fn uchimura(x: vec3<f32>) -> vec3<f32> {
    return vec3<f32>(uchimura_channel(x.r), uchimura_channel(x.g), uchimura_channel(x.b));
}

// Narkowicz's fitted ACES curve (Mellow's operator 1, ACESFilm).
fn aces_film(x_in: vec3<f32>) -> vec3<f32> {
    let x = x_in * 0.6;
    return (x * (2.51 * x + vec3<f32>(0.03))) / (x * (2.43 * x + vec3<f32>(0.59)) + vec3<f32>(0.14));
}

// AgX with the "Punchy" look (Mellow's operator 7, agxPunchy).
fn agx_punchy(color_in: vec3<f32>) -> vec3<f32> {
    let srgb_to_2020 = mat3x3<f32>(
        vec3<f32>(0.6274, 0.0691, 0.0164),
        vec3<f32>(0.3293, 0.9195, 0.0880),
        vec3<f32>(0.0433, 0.0113, 0.8956));
    let rec2020_to_srgb = mat3x3<f32>(
        vec3<f32>(1.6605, -0.1246, -0.0182),
        vec3<f32>(-0.5876, 1.1329, -0.1006),
        vec3<f32>(-0.0728, -0.0083, 1.1187));
    let inset = mat3x3<f32>(
        vec3<f32>(0.856627153315983, 0.137318972929847, 0.11189821299995),
        vec3<f32>(0.0951212405381588, 0.761241990602591, 0.0767994186031903),
        vec3<f32>(0.0482516061458583, 0.101439036467562, 0.811302368396859));
    let outset = mat3x3<f32>(
        vec3<f32>(1.1271005818144368, -0.1413297634984383, -0.14132976349843826),
        vec3<f32>(-0.11060664309660323, 1.157823702216272, -0.11060664309660294),
        vec3<f32>(-0.016493938717834573, -0.016493938717834257, 1.2519364065950405));
    let min_ev = -12.47393;
    let max_ev = 4.026069;

    var color = srgb_to_2020 * color_in;
    color = inset * color;
    color = max(color, vec3<f32>(1e-10));
    color = clamp(log2(color), vec3<f32>(min_ev), vec3<f32>(max_ev));
    color = (color - vec3<f32>(min_ev)) / (max_ev - min_ev);
    color = clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));

    // Sigmoid approximation (mean error^2 3.6705141e-06).
    let x2 = color * color;
    let x4 = x2 * x2;
    color = 15.5 * x4 * x2 - 40.14 * x4 * color + 31.96 * x4 - 6.868 * x2 * color
        + 0.4298 * x2 + 0.1191 * color - vec3<f32>(0.00232);

    // The "Punchy" look: slope 1, offset 0, power 1.35, saturation 1.4.
    color = pow(color, vec3<f32>(1.35));
    let luma = get_luminance(color);
    color = vec3<f32>(luma) + 1.4 * (color - vec3<f32>(luma));

    color = outset * color;
    color = pow(max(vec3<f32>(0.0), color), vec3<f32>(2.2));
    color = rec2020_to_srgb * color;
    return clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));
}

// Interleaved gradient noise, Mellow's dither in the final pass.
fn ign(p_in: vec2<f32>) -> f32 {
    let p = floor(p_in);
    return fract(52.9829189 * fract(dot(p, vec2<f32>(0.06711056, 0.00583715))));
}

fn hash12(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453123);
}

fn hash13(p: vec3<f32>) -> f32 {
    return fract(sin(dot(p, vec3<f32>(12.9898, 78.233, 37.719))) * 43758.5453123);
}

fn noise2(p_in: vec2<f32>) -> f32 {
    let p = floor(p_in);
    let f = fract(p_in);
    let u = f * f * (3.0 - 2.0 * f);
    let a = hash12(p);
    let b = hash12(p + vec2<f32>(1.0, 0.0));
    let c = hash12(p + vec2<f32>(0.0, 1.0));
    let d = hash12(p + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

fn fbm2(p_in: vec2<f32>) -> f32 {
    var p = p_in;
    var value = 0.0;
    var amp = 0.5;
    for (var i = 0; i < 3; i++) {
        value = value + amp * noise2(p);
        p = p * 2.03 + vec2<f32>(17.3, 9.1);
        amp = amp * 0.5;
    }
    return value;
}

// 1 while the sun is up in the Overworld, fading out around the horizon.
fn daylight() -> f32 {
    return select(0.0, smoothstep(-0.1, 0.1, frame.sun_direction.y), frame.dimension == 0);
}

// 1 when the sun is on the horizon, 0 from a quarter of the way up.
fn sun_low() -> f32 {
    return 1.0 - smoothstep(0.0, 0.35, abs(frame.sun_direction.y));
}
