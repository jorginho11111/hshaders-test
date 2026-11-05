# mellow-full — Mellow with its lighting

This variant adds the **[material] stage** (`material.wgsl`): Mellow's shaped
light — deeper shade under cover (`light_falloff`), never-pitch-black floors
(`min_light`), per-channel light boosts (`light_red/green/blue`), **water
reflections** and **atmospheric fog**.

## Why two packs?

On Horizon Android 0.7.7 the app builds its terrain pipeline with **19 sampled
textures** in the fragment stage. Common mobile GPUs cap that limit at **16**
(the refusal message the app prints says exactly this), so the terrain pipeline
is refused and — because the app refuses the whole pack — even the weather
stage would stop. That is an app-side layout; a pack cannot slim it down.

- `mellow-<version>.hshader` (from `mellow/`) — weather + bloom + tone map +
  grade. **Runs on any device**, including yours.
- `mellow-full-<version>.hshader` (this pack) — adds the lighting. On
  weak devices the app refuses it with a message (the game keeps running);
  on PCs / flagship GPUs with 19+ slots everything runs.

The stage is not a crasher: it refuses gracefully. That is why the lighting
lives in this separate pack instead of being dropped.

Needs the same MIT attribution as `mellow/` (TheCMK, codeberg.org/TheCMK/mellow-shader).
