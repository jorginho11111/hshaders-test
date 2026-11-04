// Mellow's lighting of block surfaces: the lightmap shaped by LM_FALLOFF_CURVE
// (its "lightmap based shadows" — shade under cover goes deeper), MIN_LIGHT_AMOUNT
// so nothing is pitch black, the adjustable light colours (LM_RED/GREEN/BLUE) and
// the water mirror. Vanilla's own surface is albedo * tint * vec4(lightmap, 1.0);
// this changes only what the light means.
//
// *** DESATIVADO na v0.1.2 (workaround do erro E2 — crash ao ativar no Horizon
// *** Android 0.7.7). O arquivo fica no repositório para reativar quando o crash
// *** for isolado (ver probes/ e a release mellow-v0.1.2). Não é citado no
// *** manifesto nem vai no .hshader.

override light_falloff: f32 = 1.6;
override min_light: f32 = 0.15;
override light_red: f32 = 0.0;
override light_green: f32 = 0.0;
override light_blue: f32 = 0.0;
override reflections: bool = true;
override reflection_strength: f32 = 0.5;
override atmospheric_fog: f32 = 0.25;

fn material(input: MaterialInput) -> Surface {
    // LM_FALLOFF_CURVE: a steeper curve deepens the shade away from full light.
    var light = pow(max(input.lightmap, vec3<f32>(0.0)), vec3<f32>(light_falloff));

    // MIN_LIGHT_AMOUNT, eased by the Brightness option and night vision.
    let light_floor = clamp(min_light + frame.brightness * 0.1 - 0.1, 0.0, 0.5) + frame.night_vision / 7.0;
    light = max(light, vec3<f32>(light_floor));

    // "Fully adjustable light colors": shifts the colour of the light itself.
    light = light * (vec3<f32>(1.0) + vec3<f32>(light_red, light_green, light_blue));

    let lit = input.albedo * input.tint * vec4<f32>(light, 1.0);
    var color = lit.rgb;

    // Mellow's reflections: the world mirrored on the top of water.
    if (reflections && input.fluid == 1u && input.face == 1u && frame.has_reflection == 1u) {
        let mirrored = textureSampleLevel(reflection, reflection_sampler, input.screen, 0.0);
        color = mix(color, mirrored.rgb, reflection_strength);
    }

    // Mellow's ambient (atmospheric) fog: a soft haze that closes in with
    // distance, on top of the fog the game applies afterwards.
    let dist = length(input.position);
    let haze = atmospheric_fog * smoothstep(frame.fog_start * 0.5, frame.fog_end, dist);
    color = mix(color, frame.fog_color, haze * 0.5);

    return Surface(vec4<f32>(color, lit.a));
}
