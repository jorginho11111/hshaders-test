// Mellow's painterly sky: a warm halo around a low sun, soft clouds of its own,
// shader stars, an aurora at night, and Mellow's rainy sky (desaturated, darker).
// The sun, moon and clouds of vanilla are replaced where the manifest asks for it.
//
// *** DESATIVADO na v0.1.3 (workaround do erro [E2]): o layout de texturas do
// *** pipeline de céu do app passa do limite de 16 por estágio em GPUs móveis e
// *** o wgpu panic sem captura (fecha o app). O arquivo fica no repositório.

override sky_warmth: f32 = 0.5;
override rain_sky_desaturation: f32 = 0.5;
override rain_sky_darkening: f32 = 0.33;
override cloud_opacity: f32 = 0.24;
override cloud_amount: i32 = 22;
override cloud_speed: i32 = 2;
override aurora: bool = true;
override aurora_strength: f32 = 0.2;
override star_strength: f32 = 0.5;

fn star_layer(d: vec3<f32>, density: f32) -> vec3<f32> {
    let p = d * density;
    let cell = floor(p);
    let f = fract(p) - vec3<f32>(0.5);
    let h = hash13(cell);
    if (h < 0.92) {
        return vec3<f32>(0.0);
    }
    let bright = (h - 0.92) / 0.08;
    let point = smoothstep(0.18, 0.0, length(f));
    let twinkle = 0.75 + 0.25 * sin(frame.time * (0.5 + h * 3.0) + h * 60.0);
    return vec3<f32>(0.9, 0.95, 1.0) * point * bright * twinkle;
}

fn sky(input: SkyInput) -> vec4<f32> {
    let d = input.direction;
    var color = input.color.rgb;
    let night = 1.0 - smoothstep(-0.12, 0.06, frame.sun_direction.y);

    // Warm painterly halo around a low sun (Mellow's sunrise and sunset).
    let toward = max(dot(d, frame.sun_direction), 0.0);
    let near_horizon = 1.0 - smoothstep(0.0, 0.4, abs(d.y));
    let halo = pow(toward, 6.0) * 0.6 + near_horizon * toward * toward * 0.4;
    let warm = vec3<f32>(1.0, 0.55, 0.25) * halo * sun_low() * daylight() * (1.0 - frame.rain) * sky_warmth;
    color = color + warm;

    // Mellow's soft clouds (CLOUD_AMOUNT / CLOUD_OPACITY / CLOUD_SPEED), a
    // painterly noise layer where vanilla's clouds would hang.
    if (cloud_opacity > 0.0 && d.y > 0.02 && frame.dimension == 0) {
        let scale = f32(cloud_amount) * 0.016;
        let drift = frame.time * f32(cloud_speed) * 0.004;
        let uv = d.xz / (d.y + 0.12) * scale + vec2<f32>(drift, drift * 0.6);
        let n = fbm2(uv);
        let coverage = 1.0 - f32(cloud_amount) * 0.025;
        let cover = smoothstep(coverage, coverage + 0.22, n);
        let fade = smoothstep(0.02, 0.25, d.y);
        let cloud_col = mix(frame.fog_color, vec3<f32>(1.0), 0.35) * (0.9 + 0.4 * daylight());
        color = mix(color, cloud_col, cover * cloud_opacity * 2.5 * fade);
    }

    // Mellow's shader stars (STAR_STRENGTH): two layers of quiet points.
    if (star_strength > 0.0 && night > 0.0 && frame.dimension == 0) {
        let s = star_layer(d, 42.0) + star_layer(d, 84.0) * 0.6;
        color = color + s * star_strength * night;
    }

    // Mellow's aurora (AURORA_BOREALIS, AURORA_STRENGTH): slow green curtains.
    if (aurora && night > 0.0 && frame.dimension == 0 && d.y > 0.05) {
        let band = smoothstep(0.06, 0.3, d.y) * (1.0 - smoothstep(0.45, 0.9, d.y));
        let uv = vec2<f32>(d.x * 4.5 + frame.time * 0.02, d.z * 4.5 - frame.time * 0.012);
        let curtain = fbm2(uv);
        let ribbons = smoothstep(0.35, 0.75, curtain);
        color = color + vec3<f32>(0.15, 0.9, 0.55) * band * ribbons * aurora_strength * night;
    }

    // Mellow's rainy sky (RAIN_SKY_DESATURATION, RAIN_SKY_DARKENING).
    if (frame.rain > 0.0) {
        color = mix(vec3<f32>(get_luminance(color)), color, 1.0 - frame.rain * rain_sky_desaturation);
        color = color * (1.0 - frame.rain * rain_sky_darkening);
    }

    return vec4<f32>(color, input.color.a);
}
