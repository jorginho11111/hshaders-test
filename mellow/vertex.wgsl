// Mellow's wavy world (WAVY_PLANTS, WAVE_LEAVES, wavy water, RAIN_TILT):
// plants sway, leaves stir, and the top of water rolls gently. The wave is
// driven by the world position and time, so it travels with the player.

override wave_amplitude: f32 = 0.1;
override wave_speed: f32 = 0.75;
override wave_size: f32 = 1.5;
override wave_leaves: bool = true;
override wave_water: bool = true;
override rain_tilt: f32 = 1.2;

fn vertex(input: VertexInput) -> vec3<f32> {
    var pos = input.position;
    let world = input.position + frame.camera_position;
    let t = frame.time * wave_speed;

    // Plants (material 2) sway; leaves (material 1) stir when the option is on.
    let is_leaves = input.material == 1u;
    let is_plant = input.material == 2u;
    if (is_plant || (is_leaves && wave_leaves)) {
        let phase = (world.x + world.z) * (1.0 / wave_size) + t * 1.7;
        let sway = sin(phase) + 0.35 * sin(phase * 2.7 + world.y * 0.8);
        var offset = vec2<f32>(sway, cos(phase * 0.9)) * wave_amplitude;
        // Plants lean with the wind while the ground is wet (RAIN_TILT_STRENGTH).
        offset = offset + vec2<f32>(0.6, 0.2) * frame.wetness * rain_tilt * 0.03;
        pos.x = pos.x + offset.x;
        pos.z = pos.z + offset.y;
    }

    // Water rolls: the up face fully, the sides fading down so faces stay welded.
    if (wave_water && input.fluid == 1u) {
        let topness = select(1.0 - input.uv.y, 1.0, input.face == 1u);
        let wave = sin(world.x * 0.7 / wave_size + t * 1.3) + cos(world.z * 0.6 / wave_size + t * 1.1);
        pos.y = pos.y + wave * wave_amplitude * 0.5 * topness;
    }

    return pos;
}
