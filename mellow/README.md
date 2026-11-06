# Mellow for Horizon

A conversion of **Mellow Shaders** — the painterly, gameplay-first Iris/OptiFine
shaderpack by **TheCMK** (<https://codeberg.org/TheCMK/mellow-shader>, MIT) — to
the **Horizon shader API** (WGSL, `horizon-shaders.toml` schema 1).

Mellow's look comes from its colour grading, soft bloom, shaped lightmap and
sky work. Those became Horizon stages: a painterly `[sky]`, a `[material]` that
shapes the light (with water reflections and atmospheric fog), a soft
`[weather]`, and one `[[post]]` pass (bloom + tone map + grade, merged for
speed). All stages are active since v0.1.5.

This pack targets the API surface of **Horizon Android 0.7.7** (the sky,
material, weather and post stages; that build has no `[vertex]` stage and no
`MaterialInput.colored_light`).

## Status — v0.1.5 (erros por versão)

| Versão | Erro no Horizon Android 0.7.7 |
| --- | --- |
| 0.1.0 | **[E1]** Import falhava: `unknown field 'vertex'` (TOML). |
| 0.1.1 | **[E1]** corrigido · **[E2]** o app **fecha ao ativar** o pack. |
| 0.1.2 | **[E2]** persistia (workaround `[material]` insuficiente). |
| 0.1.3 | **[E2] resolvido por workaround** — causa raiz: os **layouts de textura do app** passam do limite de **16 texturas por estágio** das GPUs móveis. O de materiais (19) é recusado com mensagem; o do céu **pânica no wgpu sem captura** (fecha o app — também com o exemplo oficial Golden Hour neste dispositivo). Por isso o `[material]` (desde 0.1.2) **e o `[sky]`** (desde 0.1.3) ficam desativados: o pack roda com **clima + bloom + tone map/grade** (12 opções). Arquivos ficam no repositório, prontos para reativar quando o app corrigir os layouts (issue reportada). |
| 0.1.4 | **[E3] a cadeia de 2 passes do pós fecha o app** — o app aloca alvos `Rgba16Float` + histórico para cadeias, que quebram o GLES móvel (sonda `probe-post` reproduz; `probe-post1` = 1 passe só, para confirmar). **Contornado**: bloom + tone map + grade **fundidos em UM passe** (`post_final.wgsl`). **Iluminação de volta**: `[material]` vai no pacote **`mellow-full`** (aparelhos com 19+ slots de textura por estágio — no seu aparelho o app recusa com aviso, sem fechar). |
| **0.1.5** | **✅ CAUSA RAIZ DE TODOS OS ERROS: o backend OPENGL ES do app.** Com **Vulkan** nada fecha, nada é recusado — todas as sondas rodam. **Tudo religado**: `[sky]` + `[material]` (luz, reflexos, névoa) + `[weather]` + pós (o passe único otimizado fica). **MAS**: o import falhava com `TOML parse error ... duplicate key [sky]` — bug meu na montagem do manifesto (chaves `[sky]`, `[reflection]` e `[budget]` duplicadas). |
| **0.1.6** | **✅ Import corrigido** — as chaves duplicadas saíram e o `tools/validate_manifests.py` agora faz **parse TOML estrito** (a mesma rejeição do app), então essa classe de erro não passa mais. **Pack completo no ar**: céu + luz + clima + pós, **29 opções**. |

Bissecção (sondas da release): no **OpenGL ES** `probe-weather` funcionava ·
`probe-material` era recusado (`limit is 16, count was 19`) · `probe-sky`,
`probe-golden` e `probe-post` fechavam o app. No **Vulkan** todas funcionam —
eram limites e panics do backend GLES do app, não do pacote.

## Using it

Put this folder in `shaderpacks/` beside `options.txt`, or download
`mellow-<version>.hshader` from the release's **Assets** (download direto) and
import it from the launcher's Shaders page, then pick **Mellow** on
Options > Horizon Settings > Shader Packs. Every knob of the original that maps
to this API is on the pack's options page, named after the `#define` it came
from.

## What was converted

| Mellow (GLSL) | Here (WGSL) |
| --- | --- |
| `final.fsh` grade: vibrance 1.2, saturation 1.0, contrast 1.0 | `post_grade.wgsl`, same formulas and defaults |
| Tone maps (8 operators; default `TONEMAP_OPERATOR 6` = Uchimura) | `shared.wgsl`: Uchimura (default), AgX Punchy, ACES |
| Vignette (`VIGNETTE_FALLOFF 0.75`, `VIGNETTE_OPACITY 0`, off by default) | `post_grade.wgsl`, same formula and defaults |
| Film grain (`FILM_GRAIN` off, `FILM_GRAIN_STRENGTH 0.05`) | `post_grade.wgsl`, off by default |
| The always-on dither of `final.fsh` | `post_grade.wgsl` |
| Bloom (`BLOOM_STRENGTH 0.4`, `BLOOM_CURVE 0.5`) | `post_glow.wgsl` (two-ring halo) |
| Lightmap shadows (`LM_FALLOFF_CURVE 1.6`) and `MIN_LIGHT_AMOUNT 0.15` | `material.wgsl` |
| Adjustable light colours (`LM_RED/GREEN/BLUE`) | `material.wgsl` options |
| Reflections on water | `material.wgsl` + `[reflection]` |
| `ATM_FOG_STRENGTH 0.25` ambient fog | `material.wgsl` |
| Rainy sky (`RAIN_SKY_DESATURATION 0.5`, `RAIN_SKY_DARKENING 0.33`) | `sky.wgsl` |
| Clouds (`CLOUD_AMOUNT 22`, `CLOUD_OPACITY 0.24`, `CLOUD_SPEED 2`) | `sky.wgsl`, its own soft clouds |
| Shader stars (`STAR_STRENGTH 0.5`) and aurora (`AURORA_STRENGTH 0.2`) | `sky.wgsl` |
| Weather streaks | `weather.wgsl` |

## What did not convert (and why)

- **Wavy plants, leaves and water (`WAVY_PLANTS`, `WAVE_LEAVES`, `RAIN_TILT`)** —
  the `[vertex]` stage is not in this build's shader API (it exists on newer
  desktop builds; the stage and its options are one manifest table away when
  the app catches up).
- **Handheld lights (`HANDHELD_LIGHTS`)** — needs `MaterialInput.colored_light`,
  which this build does not upload yet.
- **Shadow map, SSAO, god rays, DOF, TAA/SMAA, motion blur, CAS/dynamic
  sharpening, chromatic aberration, outlines** — extra passes and buffers this
  API has no stage for (a pack changes how things look, not how they are
  drawn). The look leans on the shaped lightmap instead, like Mellow's own
  "lightmap based shadows".
- **Coloured lights (`COLORED_LIGHTS`), PBR/POM, puddles, seasons, rainbows,
  Purkinje effect, colour balance, channel mixer, LUTs** — off or neutral in
  Mellow's own defaults, or needing data this API does not expose yet.
- **Distant Horizons, per-dimension `world*` programs** — Horizon's
  `frame.dimension` covers the basics only.
- **`EXPOSURE 1.7`** — that value belongs to Mellow's internal linear pipeline;
  the `exposure` option here starts at 1.1, which suits this one.

## Rules this pack follows

No bindings, no entry points, no `horizon_` names; every `override` is an
option of the manifest and every option is used; within the budgets of the
check (20 000 expressions and 64 texture reads a stage).

## Credits

- **Mellow Shaders** by TheCMK — MIT, <https://codeberg.org/TheCMK/mellow-shader>.
  The formulas, defaults and option names in this pack come from it.
- Tone map operators from **dmnsgn/glsl-tone-map** (MIT, Copyright (C) 2019
  Damien Seguin): Uchimura 2017, and the fitted ACES curve.
- The **AgX** minimal implementation after Benjamin Wrensch (iolite-engine),
  with the matrices of **Google Filament** (Apache 2.0) and EaryChow's AgX LUT
  generator; the "Punchy" look parameters are Mellow's.
- The bloom pass follows the pattern of Horizon's own `golden_hour` example
  pack (MIT, Horizon).
