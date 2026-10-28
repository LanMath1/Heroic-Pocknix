# Heroic Pocknix

> **Fork não oficial** do [Heroic Games Launcher](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher),
> com correções para rodar em **ARM64** no sistema [Pocknix](https://pocknix.org).
> Não afiliado ao projeto Heroic Games Launcher.

Este repositório não é uma cópia editada à mão. É um **fork com série de patches pequena e
versionada**, rebaseada a cada release do upstream — de forma que qualquer correção daqui possa
ser descartada quando o upstream resolver o mesmo problema.

## Estado

| | |
|---|---|
| Base upstream | `v2.22.4` (ver `pocknix/UPSTREAM_BASE`) — sincronizada com o hotfix do login da GOG |
| Artefato de referência | AppImage ARM64 validado em Pocknix, `sha256:414a9911…8fa06ce`, base v2.22.3 |
| Patches | 4 commits de código (`pocknix/patches/`) + 2 patches de ferramentas (`pocknix/tools/patches/`) |
| Build | CI em `ubuntu-24.04-arm` **verde**; AppImage ARM64 como artifact a cada push na `main` |
| Validação no aparelho | **ok** (v2.22.4, 2026-10-28) — Epic, GOG e Amazon logados; um jogo de cada baixado e aberto pelo atalho da Steam |


## Correções que este fork carrega

Cada correção de código é um **commit isolado** sobre o upstream; as correções em binários de
terceiros (que não estão neste repositório) são **arquivos `.patch`** aplicados no build.

1. **Atalhos de jogos na Steam** — atalhos gerados pelo Heroic executavam o AppImage direto e
   fechavam antes do jogo subir. `buildShortcutEntryConfig()` passa a gerar `Target=/usr/bin/env`
   com as variáveis necessárias, o caminho do AppImage e a URL `heroic://launch?...`.
2. **Artworks + inclusão automática na Steam** — `addSteamShortcuts` passa a ser `true` por padrão;
   a geração das artes é preservada.
3. **Notificação de atualização** — `checkForUpdatesOnStartup` passa a `false`. O fork **não**
   introduz mecanismo externo de auto-atualização.
4. **Legendary / Python 3.14** — falhas de `multiprocessing` (`BrokenPipeError` em
   `resource_tracker.py`) ao instalar jogos da Epic. Patch em
   [`pocknix/tools/patches/`](pocknix/tools/patches/).
5. **GOGDL / Python 3.14** — mesmas correções de `multiprocessing` e `SharedMemory` para as
   dependências GOG. Patch em [`pocknix/tools/patches/`](pocknix/tools/patches/).
6. **Game Mode** — o `AppImage` usa o `AppRun` padrão do `electron-builder`; o `--gamemode` do
   atalho do launcher é traduzido para `--fullscreen` dentro do app (patch 0004), que também
   recupera `$APPIMAGE` quando o runtime não propaga a variável.

## Instalação

Ver [`docs/INSTALL.md`](docs/INSTALL.md). Se algo não funcionar no aparelho (login da GOG, por
exemplo), ver [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Build

Ver [`docs/BUILD.md`](docs/BUILD.md). Resumo:

```bash
corepack enable && corepack prepare pnpm@12.5.1 --activate
pnpm install --frozen-lockfile
pnpm download-helper-binaries          # legendary, gogdl, nile, comet
python3 pocknix/scripts/patch-tools.py \
  public/bin/arm64/linux/legendary public/bin/arm64/linux/gogdl
pnpm build
pnpm exec electron-builder --linux AppImage --arm64 --publish never
```

Requer ARM64 nativo (ou o runner `ubuntu-24.04-arm` do GitHub Actions). Passo a passo, requisitos
e verificação do AppImage em [`docs/BUILD.md`](docs/BUILD.md).

## Como o fork se mantém atualizado

```
release nova no upstream  →  workflow sync-upstream  →  PR com patches rebaseados + AppImage de teste
                          →  validação manual no Pocknix  →  merge + tag  →  release publicado
```

Nada é publicado automaticamente. Detalhes em [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Licença

GPL-3.0-only, a mesma do upstream — ver [`COPYING`](COPYING). Este fork distribui o código
correspondente (upstream + patches deste repositório), conforme exigido pela licença.
