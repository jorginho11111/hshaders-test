# Issue a reportar em `Vasysik/horizon-android` (rascunho)

> O token do ambiente de conversão não tem permissão para criar issues em
> repositórios de terceiros. Copie o texto abaixo (em inglês) ao abrir a issue.

**Título:** `[Android] Native shader packs: bind group layouts exceed mobile max_sampled_textures_per_shader_stage (16) — sky stage panics uncaptured, material stage refused`

## What

On devices where `max_sampled_textures_per_shader_stage = 16` (common on mobile GPUs), native `.hshader` packs hit the limit with the renderer's bind group layouts:

1. **Material stage — graceful but unusable.** Enabling a pack with a `[material]` stage prints in chat (game keeps running):

   ```
   Shader pack probe-material.hshader refused:
   material.wgsl: Validation Error
   Caused by:
     In Device::create_pipeline_layout, label = 'Native shader pack terrain'
       Too many bindings of type SampledTextures in Stage ShaderStages(FRAGMENT), limit is 16, count was 19. Check the limit 'max_sampled_textures_per_shader_stage' passed to 'Adapter::request_device'
   ```

   So the terrain pipeline layout binds **19** sampled textures in FRAGMENT — every material pack is refused on such devices.

2. **Sky stage — hard crash.** A pack with a `[sky]` stage **closes the app** on enable. In `native_sky::build` (`crates/horizon-client-render/src/gfx/native_sky.rs`) `device.create_pipeline_layout` runs **outside** the error scope (the scope in `NativeSky::new` only wraps `create_shader_module`/`create_render_pipeline`), so the same class of limit error becomes an uncaptured wgpu error → panic → process exit. Reproduced with the repo's own `packs/golden_hour` fixture (shipped as `probe-golden.hshader`) — so this affects the official example too, not third-party packs.

## Bisection evidence (Horizon Android 0.7.7, one device)

| Probe (single stage each) | Result |
|---|---|
| `[weather]` only | **works** |
| `[material]` only | refused in chat — the 19 > 16 message above |
| `[sky]` only | **app closes** |
| golden_hour (sky + 2 post, the official fixture) | **app closes** |

## Suggested fix

- Wrap `create_pipeline_layout` (and bind group creation) in error scopes like the material/post paths, returning `Err(String)` so packs are refused with a message instead of crashing; and/or
- Slim the terrain/frame layouts (the frame group alone holds reflection + 3 shadow maps + opaque depth/color + 2 PBR maps + block light ≈ 9 sampled textures) or split them by need, so both fit in 16.

## Extra (pack-side info)

The `mipmaps` key some notes mention is **not** a `[[post]]` field on this API (`unknown field 'mipmaps'`) — the accepted stage fields are `file, files, name, fog, clouds, sun, stars, scale, output` only.
