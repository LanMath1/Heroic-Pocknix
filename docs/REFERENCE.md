# Artefato de referência

O AppImage abaixo é a **referência de comportamento** deste fork: a versão que foi testada e
validada no aparelho Pocknix. Ele **não** é um release deste repositório e não é armazenado no
histórico Git.

## Identificação

| Campo | Valor |
|---|---|
| Arquivo | `Heroic-Pocknix.AppImage` |
| Tamanho | 180.140.552 bytes (171,8 MiB) |
| SHA-256 | `414a99115e8e79b15b8753b5433c6883e05bbf851b901c07e8fd35e3d8fa06ce` |
| Arquitetura | ARM64 (`ELF 64-bit LSB`, `e_machine 0xB7`), runtime AppImage tipo 2 |
| Data do build | 2026-10-03 |
| Base upstream | **`v2.22.3`** (lido do `package.json` dentro de `app.asar`) |
| Ferramentas embutidas | legendary 0.21.1, gogdl 1.3.0 (zipapps) |

> A base do **fork** não é mais esta: em 2026-10-28 ela foi sincronizada com `v2.22.4` (hotfix do
> login da GOG). Este documento descreve o **artefato de referência**, que ficou em v2.22.3.

Hash verificado de forma independente nas duas pontas (Windows e Pocknix) e conferido com
`sha256sum -c`.

## Conteúdo recuperado

Extraído com `--appimage-extract` (sem FUSE), 95 arquivos, 441 MB:

```
AppRun                                   805 B   modificado (ver pocknix/runtime/)
AppRun.backup                            805 B   idêntico ao AppRun (md5 f4de4027…)
com.heroicgameslauncher.hgl.desktop      265 B   nome/mime personalizados
com.heroicgameslauncher.hgl.png       90.394 B   ícone 512x512
opt/heroic/heroic                    208 MB     ELF aarch64, Electron, stripped
opt/heroic/resources/app.asar       72,8 MB     sha256 158911a81fc6b428…2493eaf65d
opt/heroic/resources/app.asar.before-steam-fix  31,8 MB
opt/heroic/resources/app-update.yml      108 B   electron-updater / provider github
opt/heroic/resources/app.asar.unpacked/ vazio
usr/share/icons/hicolor/512x512
```

`AppRun.backup` ser idêntico ao `AppRun` atual indica que o backup foi tirado **depois** da
edição — não há uma versão "limpa" embutida.

`app.asar.before-steam-fix` é o achado mais útil: dá o **antes e depois** da correção de atalhos,
permitindo derivar o diff real em vez de reconstruir por suposição.

## Onde o binário fica

- **Não** no Git (`.gitignore` cobre `*.AppImage`).
- Cópia de referência publicada como asset do release `reference-2.22.4-pocknix` no GitHub,
  com este mesmo SHA-256.

## Cópia local de trabalho na console

```
/home/deck/Heroic-Pocknix-Build/Heroic-Pocknix.AppImage     # 444, read-only
/home/deck/Heroic-Pocknix-Build/SHA256SUMS.txt
/home/deck/Heroic-Pocknix-Build/work/Heroic-Pocknix.AppImage.work   # cópia executável
/home/deck/Heroic-Pocknix-Build/work/appdir/                        # AppDir extraído
```
