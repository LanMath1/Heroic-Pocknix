# Arquivos de runtime do artefato de referência

`AppRun` e `com.heroicgameslauncher.hgl.desktop` foram extraídos do AppImage de referência
(`pocknix/reference/SHA256SUMS`) e ficam aqui como **documentação do comportamento esperado**, não
como arquivos que o build instala.

O AppImage deste fork é gerado pelo `electron-builder`, que escreve o próprio `AppRun` e o próprio
`.desktop` (a partir de `linux.desktop.entry` no `electron-builder.yml`). O layout também difere do
artefato de referência:

| | referência | build deste fork |
|---|---|---|
| binário | `opt/heroic/heroic` | `heroic` (raiz do AppDir) |
| asar | `opt/heroic/resources/app.asar` | `resources/app.asar` |
| zipapps | dentro do asar | `resources/app.asar.unpacked/build/bin/arm64/linux/` |

O que o `AppRun` da referência fazia e que **hoje vive no código** (patch 0004, em
`src/backend/constants/environment.ts`):

1. recuperar `$APPIMAGE` a partir de `$ARGV0` quando o runtime não propaga a variável;
2. traduzir `--gamemode` (convenção do Steam Deck) para `--fullscreen`.

O `--no-sandbox` que ele passava continua coberto pelo `.desktop` gerado (`Exec=AppRun --no-sandbox
%U`) e pela linha de comando dos atalhos.

`com.heroicgameslauncher.hgl.png` é o ícone usado pelo atalho em `docs/INSTALL.md`.
