// Rain and snow streaks, softened and tinted to sit in Mellow's picture:
// cool grey-blue rain, brighter snow.

override weather_opacity: f32 = 1.0;

fn weather(input: WeatherInput) -> vec4<f32> {
    var color = input.color;
    if (input.snow) {
        color = vec4<f32>(mix(color.rgb, vec3<f32>(0.95, 0.97, 1.0), 0.35), color.a);
    } else {
        color = vec4<f32>(mix(color.rgb, vec3<f32>(0.62, 0.68, 0.78), 0.3), color.a * 0.85);
    }
    // Streaks stand out a little more where the sky light is low.
    let light = mix(0.75, 1.0, input.light.y);
    return vec4<f32>(color.rgb * light, color.a * weather_opacity);
}
