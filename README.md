# hshaders-test

Converting "normal" shaders (GLSL, Iris/OptiFine packs) to **hshaders** —
Horizon shader packs (`.hshader`: WGSL against Horizon's renderer stages, with
a `horizon-shaders.toml` manifest; see
[horizon-rust/horizon `docs/shaders.md`](https://github.com/horizon-rust/horizon/blob/main/docs/shaders.md)).

## Packs here

| Pack | Source | What it is |
| --- | --- | --- |
| [`mellow/`](mellow/) | [Mellow Shaders](https://codeberg.org/TheCMK/mellow-shader) by TheCMK (Iris/OptiFine, MIT) | A painterly, gameplay-first shaderpack converted to the Horizon shader API: its colour grading (vibrance 1.2, Uchimura tone map), soft bloom, shaped-lightmap shading, its own clouds, stars and aurora. Ready to drop in `shaderpacks/` — the folder, or `mellow-0.1.1.hshader`. Built against the API surface of Horizon Android 0.7.7 (sky, material, weather and post stages). |

## Status / depuração (Horizon Android 0.7.7)

Downloads diretos (`.hshader`) ficam nas **[Releases](https://github.com/jorginho11111/hshaders-test/releases)**;
o código-fonte fica no repositório (como no port do Horizon Android).

| Release | Erro registrado |
| --- | --- |
| [mellow-v0.1.0](https://github.com/jorginho11111/hshaders-test/releases/tag/mellow-v0.1.0) | **[E1]** `unknown field 'vertex'` na importação |
| [mellow-v0.1.1](https://github.com/jorginho11111/hshaders-test/releases/tag/mellow-v0.1.1) | **[E1]** corrigido · **[E2]** app fecha ao ativar o pack |
| [mellow-v0.1.2](https://github.com/jorginho11111/hshaders-test/releases/tag/mellow-v0.1.2) | **[E2]** sob teste — workaround: `[material]`/`[reflection]` desativados (suspeito nº 1); NaN do AgX corrigido. Assets: pack + 4 sondas de bissecção |

- **`probes/`** — sondas (sky / post / material / weather) que isolam o estágio do **[E2]**; instruções em `probes/README.md`.
- Relatório de crash do app: `last-rust-panic.txt` (botão *Game files* do launcher → Reports).
- Os `.hshader` são construídos por `tools/build_hshader.py` e anexados às releases pelo
  workflow `.github/workflows/release-assets.yml` (o upload direto não funciona no sandbox).

## How a conversion goes

1. **Map the effects to Horizon's stages**: `[sky]`, `[vertex]` (waving
   plants/water), `[material]` (how surfaces are lit), `[weather]`, and up to
   8 `[[post]]` passes. A stage the pack leaves out keeps vanilla's look.
2. **Rewrite in WGSL** against the documented inputs: `frame` (camera, sun and
   moon, time of day, rain, fog...), `SkyInput`/`VertexInput`/`MaterialInput`/
   `WeatherInput`/`PostInput`, and the helpers (`depth_at`, `view_position`,
   `shadow_position`, `block_light_color`, ...). No bindings, no entry points,
   no `horizon_` names.
3. **Declare the pack**: `horizon-shaders.toml` with the stages, `[[options]]`
   (each becomes a WGSL `override` of the same name), `[[materials]]` sprite
   ids, `[[textures]]`, `[[lights]]`, `[reflection]`, `[budget]`.
4. **Keep to the check**: every option used, 20 000 expressions and 64 texture
   reads per stage, 256 KiB per file, 8 MiB per pack.
5. **Pack it**: the folder is the pack; zipping the same files in path order
   with fixed dates gives a reproducible `.hshader`.

With the toolchain (`horizon-shader` from `crates/horizon-shader-api`) you
would run `horizon-shader check` and `horizon-shader pack`; this repo also
documents what a plain-text conversion validated by hand and by a WGSL parser
looks like.

## What does not convert

Vertex displacement that changes how the world is *drawn* (beyond `[vertex]`),
custom shadow/SSAO/TAA passes, compute, and anything entity- or
particle-specific have no stage yet. See each pack's README for its own list.
