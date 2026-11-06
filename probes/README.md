# Sondas de bissecção (Horizon Android 0.7.7)

O pacote **Mellow 0.1.1** importa e mostra as opções, mas o app **fecha ao ativar** o pack
(erro **[E2]** da release `mellow-v0.1.1`). Estas 4 sondas isolam **qual estágio** derruba
o app. Cada uma é o código real do Mellow (mesmos `.wgsl`) com **um único estágio**.

**Download direto:** os `.hshader` estão como **Assets** da release
[mellow-v0.1.2](https://github.com/jorginho11111/hshaders-test/releases/tag/mellow-v0.1.2)
(as fontes ficam aqui no repositório).

> **Nota (correção):** a primeira leva das sondas falhou na importação
> (`written for shader API >=0.3.0; this Horizon serves 0.1`) por um erro meu:
> o `api` do manifesto precisa ser literalmente `"0.1"` e o `id` só pode usar
> `[a-z0-9_]` (sem hífen). Corrigido — as sondas abaixo importam normalmente.

## Resultados (bissecção concluída em 2026-11-04)

| # | Sonda | Contém | Resultado no Horizon Android 0.7.7 |
|---|---|---|---|
| 1 | `probe-golden.hshader` | o **exemplo oficial Golden Hour** do próprio app | **FECHA O APP** ← o bug é do app/dispositivo, não do Mellow |
| 2 | `probe-sky.hshader` | só `[sky]` | **FECHA O APP** → o estágio de céu é o gatilho |
| 3 | `probe-post.hshader` | só os 2 `[[post]]` (glow → grade) | 3 bugs meus no manifesto corrigidos (`mipmaps`; `file` obrigatório; `scale` exige `output`). **Testado (2026-11-05): importa ✓ mas O APP FECHA ao ativar** — a cadeia de passes aloca alvos `Rgba16Float` + histórico no app, que derrubam o GLES móvel |
| 3b | `probe-post1.hshader` | 1 passe só (`[[post]]` trivial, sem cadeia, sem opções) | **Novo (0.1.4)** — se rodar onde o probe-post fecha, a cadeia é a causa confirmada |
| 4 | `probe-material.hshader` | só `[material]` + `[reflection]` | importa, mas é **recusado** no chat: `Too many bindings of type SampledTextures... limit is 16, count was 19` |
| 5 | `probe-weather.hshader` | só `[weather]` | **FUNCIONA PERFEITAMENTE** ✓ |

**Causa raiz:** os layouts de grupo do app pedem mais texturas por estágio do que GPUs
móveis permitem (`max_sampled_textures_per_shader_stage = 16`). O de materiais quer 19
(recusado com aviso); o do céu passa do limite e o erro do wgpu **não é capturado** →
panic → o app fecha. **RESOLUÇÃO FINAL (2026-11-05):** tudo isso era do **backend
OpenGL ES** do app — com **Vulkan** todas as sondas rodam, nada fecha e nada é
recusado. As sondas ficam aqui como registro da bissecção; o Mellow **0.1.5** volta
com todos os estágios (céu + materiais + clima + pós em 1 passe) e 29 opções.

- Se **todas** rodarem bem → o problema é a **combinação** de estágios (aí testa-se a soma aos poucos).
- Se **todas** fecharem → o problema é do app no caminho comum (frame/opções), não do pack.

## Relatório de crash (corta o diagnóstico pela metade)

O Horizon grava **`last-rust-panic.txt`** quando um panic Rust acontece:

1. Abra os arquivos do jogo (botão **Game files** do launcher → app de Arquivos do sistema).
2. Procure **`last-rust-panic.txt`** (ou a pasta **Reports** → `crash-reports/`).
3. Envie o conteúdo desse arquivo — a mensagem do panic aponta a linha exata do crash.

Os códigos-fonte analisados estão em `Vasysik/horizon-android`, branch `android`
(o caminho de ativação em `crates/horizon-client/src/game/native_shaders.rs` mostra os erros
como mensagens no chat — um **fechamento** do app indica panic fora desse tratamento).
