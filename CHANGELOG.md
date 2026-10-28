# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: `<versão-upstream>-pocknix.<n>`.

## [Não publicado]

### v2.22.4-pocknix.1 — primeira release

Fork do Heroic Games Launcher para ARM64 / Pocknix. Base sincronizada com o **v2.22.4** do
upstream (o artefato de referência estava em v2.22.3); o histórico deste fork é
`upstream/<tag>` → `overlay` → patches.

**O que muda em relação ao Heroic 2.22.4 oficial**

- Atalhos de jogos na Steam passam a usar `Target=/usr/bin/env` com as variáveis necessárias
  (`APPIMAGE_EXTRACT_AND_RUN=1`, `FUSERMOUNT_PROG`, o caminho do AppImage e a URL
  `heroic://launch?...`). Antes o atalho executava o AppImage direto e fechava antes de iniciar o
  jogo. (patch 0001)
- `addSteamShortcuts` ligado por padrão, com a geração de artworks preservada. (patch 0002)
- `checkForUpdatesOnStartup` desligado: o launcher não procura atualização no boot. (patch 0003)
- `--gamemode` (convenção do Steam Deck) traduzido para `--fullscreen`, e `$APPIMAGE` recuperado de
  `$ARGV0` quando o runtime não propaga a variável. (patch 0004)
- `legendary` 0.21.1 e `gogdl` 1.3.0 corrigidos para o Python 3.14 do Pocknix
  (`multiprocessing` / `SharedMemory`).

**Validado no aparelho** — Pocknix OS 0.5.0, aarch64

- login nas três lojas (Epic, GOG e Amazon);
- download e instalação de um jogo de cada loja;
- abertura dos jogos pelo atalho criado na Steam, com artwork;
- execução no Game Mode.

## [v2.22.3-pocknix.0] — levantamento

Base real do artefato de referência: **v2.22.3** (lido do `app.asar`). Diff contra o upstream
reduzido a **3 hunks** em `main.js` + ajustes em dois zipapps.
Ver [`docs/RECOVERED-DIFF.md`](docs/RECOVERED-DIFF.md).

- Patches 0001–0003 mapeados para `src/backend/shortcuts/nonesteamgame/nonesteamgame.ts`
  (`buildShortcutEntryConfig`) e `src/backend/config.ts` (`getFactoryDefaults`).
- Patches 0004–0005 localizados **dentro** do AppImage: legendary 0.21.1 e gogdl 1.3.0 são
  zipapps que rodam no Python 3.14 do sistema.
