# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: `<versão-upstream>-pocknix.<n>`.

## [Não publicado]

### Adicionado

- **Sync automático de saves em todos os jogos.** O `autoSyncSaves` já existia como padrão global,
  mas só aparecia no Settings de cada jogo, e a pasta de save só era detectada quando essa tela era
  aberta — na prática, era preciso configurar jogo por jogo. Agora há o toggle global
  *Settings → General → Synchronize saves automatically for all games*, e o backend detecta a pasta
  na primeira abertura do jogo e a grava em `GameConfig` (`savesPath` no Epic, `gogSaves` no GOG).
  Vale também para jogos abertos pelo atalho da Steam. (patch 0006)

### Corrigido

- **Detecção da pasta de saves de jogos Epic.** Em *Settings → Sync Saves* de um jogo Epic com cloud
  save, o Heroic mostrava “Save folder not found” mesmo com a pasta existindo dentro do prefixo. O
  `legendary` calculava e gravava o caminho em `installed.json`, mas o Heroic relia o valor do mapa
  em memória (`installedGames`), preenchido apenas por `refreshInstalled()`. Agora
  `getGameInfo(app, true)` relê o arquivo antes de montar o `GameInfo`. (patch 0005)

  Validado no aparelho: o Jotunnslayer, que falhava às 22:30, passou a registrar
  `Computed save path` às 22:45; e o Viewfinder completou o ciclo (detecção → upload → save visível
  no PC).

## [v2.22.4-pocknix.1] - 2026-10-28

Primeira release buildada pelo CI e validada no aparelho.

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
