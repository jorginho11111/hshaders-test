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

## Como testar (na ordem)

Instale cada `.hshader` pelo botão **Import file** do launcher, ative-o no **jogo** e observe:

| # | Sonda | Contém | Se FECHAR o app | Conclusão |
|---|---|---|---|---|
| 1 | `probe-golden.hshader` | o **exemplo oficial Golden Hour** do próprio app (byte a byte o fixture de testes dele) | o problema é do app/dispositivo com packs `.hshader` — não do Mellow | |
| 2 | `probe-sky.hshader` | só `[sky]` (nuvens/estrelas desativadas) | o problema está no estágio de céu (ou nas flags `clouds/stars = false`) | |
| 3 | `probe-post.hshader` | só os 2 `[[post]]` (glow → grade) | o problema está na cadeia de pós-processamento | |
| 4 | `probe-material.hshader` | só `[material]` + `[reflection]` | o problema está no estágio de materiais (ou no espelho/reflexão) | |
| 5 | `probe-weather.hshader` | só `[weather]` | o problema está no estágio de clima | |

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
