// One trivial post pass: a warm tint of the picture. No options, no chain —
// the leanest post path the app can take (straight to screen).

fn post(input: PostInput) -> vec4<f32> {
    return vec4<f32>(input.color.rgb * vec3<f32>(1.05, 1.0, 0.95), input.color.a);
}
