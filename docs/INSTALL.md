# Instalação e atualização no Pocknix

## O que nunca deve ser apagado

```
/home/deck/Games/Heroic      # jogos instalados, prefixos Wine/Proton, saves
/home/deck/.config/heroic    # contas, credenciais, configurações, ferramentas baixadas
```

Atualizar o AppImage **não** toca nesses diretórios. Qualquer script deste repositório que apague
algo fora do próprio AppImage está errado.

## Instalação

```bash
mkdir -p /home/deck/Applications/Heroic
cp Heroic-Pocknix.AppImage /home/deck/Applications/Heroic/
chmod +x /home/deck/Applications/Heroic/Heroic-Pocknix.AppImage
```

Conferir o hash baixado contra o publicado no release:

```bash
sha256sum /home/deck/Applications/Heroic/Heroic-Pocknix.AppImage
```

## Primeira execução

```bash
/home/deck/Applications/Heroic/Heroic-Pocknix.AppImage
```

Se o FUSE estiver disponível (`fuse2`/`fuse3` instalados, `/dev/fuse` presente), monta direto.
Caso contrário, `APPIMAGE_EXTRACT_AND_RUN=1` funciona sem montagem — e é o modo usado no Game Mode.

## Game Mode / Steam

Dois casos **diferentes**, que não devem ser misturados:

**Abrir o Heroic pelo Game Mode** (atalho do próprio launcher):

```
APPIMAGE_EXTRACT_AND_RUN=1 %command% --gamemode
```

`--gamemode` não é flag do Heroic: o app traduz para `--fullscreen` (patch 0004). O `--no-sandbox`
já vem do `Exec` do `.desktop` gerado pelo `electron-builder`.

O AppImage **não** depende de FUSE para isso: `APPIMAGE_EXTRACT_AND_RUN=1` faz o runtime extrair
para um diretório temporário.

**Atalhos dos jogos** são gerados pelo Heroic durante o uso normal — com
`Target=/usr/bin/env`, as variáveis necessárias, o caminho do AppImage e a URL
`heroic://launch?...`. Não edite esses atalhos à mão.

## Atualização

1. baixar o AppImage novo do release;
2. validar o SHA-256 publicado;
3. fechar o Heroic;
4. copiar por cima do arquivo em `/home/deck/Applications/Heroic/Heroic-Pocknix.AppImage`;
5. `chmod +x` e abrir.

Alternativa com rollback: guardar a versão anterior como
`Heroic-Pocknix.AppImage.<versão>` antes de substituir.

## Desinstalação

```bash
rm -rf /home/deck/Applications/Heroic
```

Só isso. `Games/Heroic` e `.config/heroic` ficam intactos — apague manualmente apenas se quiser
remover jogos/configurações de verdade.

## Problemas conhecidos

| Sintoma | Causa | Solução |
|---|---|---|
| Atalho na Steam abre e fecha na hora | versão sem a correção de `buildShortcutEntryConfig()` | usar release deste fork |
| Sem artworks nos atalhos da Steam | `addSteamShortcuts` desligado por padrão | usar release deste fork |
| Aviso de atualização ao abrir | `checkForUpdatesOnStartup` ligado | usar release deste fork (padrão `false`) |
| Download da Epic falha com `BrokenPipeError` | `multiprocessing` no Python 3.14 | ver patch Legendary |
| Dependências GOG interrompem no meio | idem, GOGDL | ver patch GOGDL |
