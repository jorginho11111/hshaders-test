// Mellow's bloom (BLOOM, BLOOM_STRENGTH 0.4, BLOOM_CURVE 0.5): a soft halo of
// the brightest pixels — the sun, lava, torches at night — on two rings of taps,
// scaled with the picture's height so it looks the same at any resolution. The
// daytime sky is bright too, so it glows only a quarter as much.

override bloom_strength: f32 = 0.4;
override bloom_curve: f32 = 0.5;

fn bright(uv: vec2<f32>) -> vec3<f32> {
    let c = textureSampleLevel(previous, linear_sampler, uv, 0.0).rgb;
    let sky = select(1.0, 0.25, depth_at(uv) == 0.0);
    return c * smoothstep(bloom_curve, 1.0, get_luminance(c)) * sky;
}

fn post(input: PostInput) -> vec4<f32> {
    if (bloom_strength <= 0.0) {
        return input.color;
    }
    let step_uv = frame.resolution.y / 720.0 / frame.resolution;
    var sum = vec3<f32>(0.0);
    for (var i = 0; i < 12; i++) {
        let angle = f32(i) * 0.5235988;
        let radius = select(3.0, 7.0, (i & 1) == 1);
        let offset = vec2<f32>(cos(angle), sin(angle)) * radius * step_uv;
        sum = sum + bright(input.uv + offset);
    }
    return vec4<f32>(input.color.rgb + sum * (bloom_strength / 8.0), input.color.a);
}
