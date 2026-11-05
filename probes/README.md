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
| 3 | `probe-post.hshader` | só os 2 `[[post]]` (glow → grade) | import recusado na 1ª leva (`mipmaps` não existe nesta API) — **corrigido**, falta testar |
| 4 | `probe-material.hshader` | só `[material]` + `[reflection]` | importa, mas é **recusado** no chat: `Too many bindings of type SampledTextures... limit is 16, count was 19` |
| 5 | `probe-weather.hshader` | só `[weather]` | **FUNCIONA PERFEITAMENTE** ✓ |

**Causa raiz:** os layouts de grupo do app pedem mais texturas por estágio do que GPUs
móveis permitem (`max_sampled_textures_per_shader_stage = 16`). O de materiais quer 19
(recusado com aviso); o do céu passa do limite e o erro do wgpu **não é capturado** →
panic → o app fecha. Enquanto o app não corrigir, o Mellow roda sem `[sky]`/`[material]`
(clima + pós) — release **0.1.3**.

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
