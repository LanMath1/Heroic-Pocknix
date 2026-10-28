# Build

## Requisitos

| Item | Versão | Observação |
|---|---|---|
| Node.js | 22.23.3 | `engines.node >= 22` no upstream |
| pnpm | 12.5.1 | gerenciador oficial do upstream (`corepack`) |
| Arquitetura | **ARM64 nativo** | recomendado: runner `ubuntu-24.04-arm` |
| electron-builder | do lockfile | gera o AppImage |
| libopenjp2-tools | sistema | `opj_decompress` — electron-builder converte `build/icon.icns` para PNG |
| squashfs-tools | sistema | se for empacotar/desempacotar manualmente |

Não é obrigatório compilar dentro do Pocknix. Compilar em x86 com emulação é lento e não
reproduz o ambiente de destino — use ARM64 nativo (CI) e valide na console.

## Build completo

```bash
corepack enable
corepack prepare pnpm@12.5.1 --activate
pnpm install --frozen-lockfile

# 1. binários auxiliares → public/bin/arm64/linux/{legendary,gogdl,nile,comet}
pnpm download-helper-binaries

# 2. legendary e gogdl são zipapps: rodam no Python do sistema (3.14 no Pocknix)
python3 pocknix/scripts/patch-tools.py \
  public/bin/arm64/linux/legendary \
  public/bin/arm64/linux/gogdl

# 3. empacotamento (o build copia public/ → build/, inclusive public/bin)
pnpm build                                   # electron-vite → build/main/main.js
pnpm exec electron-builder --linux AppImage --arm64 --publish never
```

O passo 2 é obrigatório. Sem ele o AppImage gera, mas Epic e GOG travam o download no Pocknix:
o Python 3.14 trocou o start method padrão do `multiprocessing` no Linux de `fork` para
`forkserver`. Detalhes em `pocknix/tools/README.md`.

O passo 1 também é obrigatório: sem `public/bin`, `build/bin` não existe e o AppImage sai sem
`legendary`, `gogdl`, `nile` e `comet` — o `verify.sh` falha nesse caso.

Saída em `dist/`. Conferir:

```bash
sha256sum dist/*.AppImage
```

## Verificação do resultado

`pocknix/scripts/verify.sh <arquivo.AppImage>` checa, no AppImage gerado:

- hash e arquitetura (`e_machine 0xB7`);
- layout do `electron-builder`: `AppRun`, `heroic`, `heroic.desktop`, `resources/app.asar`;
- `AppRun` executável e apontando para o binário;
- campos obrigatórios do `.desktop` (`Name`, `Exec=AppRun`, `Icon`, `MimeType`, `Categories`);
- literais que só existem por causa dos patches (`APPIMAGE_EXTRACT_AND_RUN=1`,
  `FUSERMOUNT_PROG`, `--gamemode`) dentro do `app.asar`;
- `legendary` e `gogdl` em `resources/app.asar.unpacked/build/bin/arm64/linux/`, executáveis e
  com os patches de Python 3.14 (conta as ocorrências de `track=False` e do `set_start_method`);
- presença de `nile`, `comet` e `vulkan-helper`;
- empacotamento do `app.asar` (tamanho e integridade).

## Reconstruir a partir do artefato de referência

Usado **só para derivar patches**, não como processo de release.

```bash
# 1. extrair o AppImage (sem FUSE)
cp Heroic-Pocknix.AppImage work/Heroic-Pocknix.AppImage.work
chmod +x work/Heroic-Pocknix.AppImage.work
cd work && ./Heroic-Pocknix.AppImage.work --appimage-extract && mv squashfs-root appdir

# 2. instalar ferramenta de asar, fora do sistema
mkdir -p tools && cd tools
curl -LO https://nodejs.org/dist/v22.23.3/node-v22.23.3-linux-arm64.tar.xz
tar xf node-v22.23.3-linux-arm64.tar.xz
export PATH="$PWD/node-v22.23.3-linux-arm64/bin:$PATH"
npm install --no-save @electron/asar@4.3.1

# 3. extrair as duas versões do asar
npx asar extract ../appdir/opt/heroic/resources/app.asar ../asar-current
npx asar extract ../appdir/opt/heroic/resources/app.asar.before-steam-fix ../asar-before

# 4. diff → vira patch contra o fonte TS do upstream
diff -ruN ../asar-before ../asar-current > ../asar.diff
```

O diff do passo 4 é **indício**, não patch final: o alvo do patch é o TypeScript em `src/`,
não o JS compilado.

## Convenções do repositório

- Patches: um commit por correção, com mensagem explicando o sintoma observado e por que aquela é
  a menor mudança que resolve. A série é exportada para `pocknix/patches/` e não é versionada.
- Correções em binários de terceiros (as zipapps de legendary/gogdl) **não** são commits: ficam em
  `pocknix/tools/patches/` como `.patch` do `patch(1)` e são aplicadas no build.
- Modelo de 3 camadas: `base` (squash do upstream) → `overlay` (docs, pocknix/, workflows) →
  `patches`. A série exportada é `<overlay>..HEAD`; após um sync rodar
  `pocknix/scripts/export-patches.sh`.
- Mudança de overlay **não** se commita depois dos patches: use
  `pocknix/scripts/overlay-commit.sh "mensagem"`, que dobra a mudança no commit de overlay e
  reaplica a série por cima.
- Nunca commitar `*.AppImage`, `*.asar`, `node_modules/`, `build/`, `dist/`.
