# Diff recuperado do AppImage de referência

Registro do que o artefato de referência (`414a9911…8fa06ce`) realmente contém de diferente do
upstream. Este documento é a **fonte para os patches** — os de código viram commits (exportados em
`pocknix/patches/`) e os das zipapps ficam em `pocknix/tools/patches/`.

> Este documento descreve o artefato de referência, que é **v2.22.3**. A base do fork foi
> sincronizada com **v2.22.4** em 2026-10-28 — nenhum dos arquivos que patchamos mudou entre os dois
> tags, então o diff abaixo continua valendo linha por linha.

## Método

```
AppImage --appimage-extract        → AppDir
@electron/asar extract app.asar            → asar-current
@electron/asar extract app.asar.before-steam-fix → asar-before
comparação byte a byte das duas árvores
```

Ferramentas: Node 22.23.3 arm64 + `@electron/asar@4.3.1` (versões do build original).

## Resultado

| | |
|---|---|
| Arquivos em comum | 1839 |
| Arquivos **diferentes** | **1** — `build/main/main.js` (+232 bytes) |
| Arquivos só no `app.asar` atual | 15 |
| Versão dentro do asar | **2.22.3** (não 2.22.4) |

O `main.js` tem 26.949 linhas lógicas: o diff real é de **3 hunks**.

## Patch 0001 — atalhos da Steam

Arquivo de origem: `src/backend/shortcuts/nonesteamgame/nonesteamgame.ts`,
função `buildShortcutEntryConfig()`.

```diff
   } else if (!isWindows && isAppImage) {
-    exe = `"${process.env.APPIMAGE}"`
+    exe = `"/usr/bin/env"`
     startDir = `"${dirname(process.env.APPIMAGE!)}"`
   }
 
   const args = []
+  if (!isWindows && isAppImage) {
+    args.push('PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin')
+    args.push('FUSERMOUNT_PROG=/usr/bin/fusermount')
+    args.push('APPIMAGE_EXTRACT_AND_RUN=1')
+    args.push(`"${process.env.APPIMAGE}"`)
+  }
   args.push('--no-gui')
```

Efeito: o `Target` do atalho passa a ser `/usr/bin/env`, que interpreta as variáveis e depois
executa o AppImage. Sem isso, o atalho executava o AppImage direto e fechava antes do jogo subir.

## Patch 0002 + 0003 — padrões de configuração

Arquivo de origem: `src/backend/config.ts`, `getFactoryDefaults()`.

```diff
       addSteamShortcuts: false,                    →  true
       preferSystemLibs: false,
       checkForUpdatesOnStartup: !isFlatpak,        →  false
```

Esses dois valores **não** são padrão do upstream: em `v2.22.3`, `config.ts` traz
`addSteamShortcuts: false` e `checkForUpdatesOnStartup: !isFlatpak`.

## Ferramenta 0004 — legendary 0.21.1 (Python 3.14)

As ferramentas são **zipapps** com `#!/usr/bin/env python3` — rodam no Python do sistema (3.14),
que é a causa raiz dos problemas de `multiprocessing`. Elas estão **dentro** do AppImage,
em `build/bin/arm64/linux/`.

| Arquivo | Mudança |
|---|---|
| `legendary/downloader/mp/workers.py` (2×) | `SharedMemory(name=shm, track=False)` |
| `legendary/downloader/mp/manager.py` | `SharedMemory(create=True, size=…, track=False)` |
| `legendary/cli.py` | `set_start_method("fork", force=True)` em `main()` |

## Ferramenta 0005 — gogdl 1.3.0 (Python 3.14)

| Arquivo | Mudança |
|---|---|
| `gogdl/dl/workers/task_executor.py` (2×) | `SharedMemory(..., track=False)` |
| `gogdl/dl/managers/task_executor.py` | `SharedMemory(create=True, …, track=False)` |
| `gogdl/cli.py` | `set_start_method("fork", force=True)` em `main()` |

Atenção: o zipapp do gogdl contém **duas** cópias do pacote — `gogdl/` (corrigida) e
`lib.linux-aarch64-cpython-313/gogdl/` (sem `track=False`, artefato de build do mypyc).
**Resolvido:** em zipapp o `sys.path[0]` é a raiz do arquivo, então `import gogdl` resolve
`gogdl/`; o diretório `lib.*-cpython-313` não é adicionado ao path por ninguém e o próprio sufixo
não casa com o runtime (3.14). Os `.so` mypyc (`*__mypyc.cpython-*.so`) só compilam
`charset_normalizer` — conferido com `strings` + `grep PyInit_`. `nile` é ELF (PyInstaller) e
`comet` é Rust: não passam por Python.

Estes dois **não** são patches de commit — o código não está neste repositório, é baixado no
build. Vivem como `.patch` do `patch(1)` em `pocknix/tools/patches/`, aplicados por
`pocknix/scripts/patch-tools.py` antes do empacotamento, e conferidos pelo `verify.sh` no AppImage
final.

Verificado sobre os binários oficiais:

```
legendary 0.21.1  e901cb52…2143d9  →  b1b98d40…cf949f   (--version: 0.21.1)
gogdl 1.3.0       c49e1519…7a0f4c  →  0a5ee2c7…dc54f    (--version: 1.3.0)
```

Aplicação idempotente (rodar de novo mantém o hash) e determinística (duas cópias limpas geram o
mesmo hash).

## Por que o `app.asar` cresceu de 31,8 MB para 72,8 MB

Não é compressão nem sourcemap. São 15 arquivos que antes ficavam **fora** do asar
(`app.asar.unpacked`) e passaram a ficar **dentro**:

```
build/bin/arm64/linux/{comet,nile,legendary,gogdl,vulkan-helper}
build/bin/{x64/win32/EpicGamesLauncher.exe, x64/win32/GalaxyCommunication.exe}
build/icon*.png, build/icon.icns, build/mac-icon.icns, build/win_icon.ico
build/main/main.js.before-steam-fix   ← 13,2 MB, o "antes" da correção de atalhos
build/preload/webviewPreload.js
```

## Patch 0004 — ambiente do AppImage (AppRun)

O AppImage de referência trazia um `AppRun` próprio (ver `pocknix/runtime/`). O build deste fork
usa o `electron-builder`, que escreve o **seu** `AppRun` — e o layout é outro (`heroic` na raiz,
`resources/app.asar`, zipapps em `app.asar.unpacked`). Ou seja: o `AppRun` da referência nunca
chegaria ao artefato.

Duas coisas dele foram para o código (`src/backend/constants/environment.ts`):

| Antes (AppRun) | Agora (environment.ts) |
|---|---|
| `export APPIMAGE="$ARGV0"` quando `APPIMAGE` vazio | mesma regra, antes de `isAppImage` ser calculado |
| `--gamemode` → `exec heroic --no-sandbox --fullscreen` | `--gamemode` sai do argv e entra `--fullscreen` |

Motivo de manter: o atalho do launcher no Game Mode na console usa
`APPIMAGE_EXTRACT_AND_RUN=1 %command% --gamemode`, e `--gamemode` não é flag do Heroic.

## Consequência para o build novo

`main.js` contém:

```js
function fixAsarPath(origin) {
  if (!origin.includes('app.asar.unpacked')) {
    return origin.replace('app.asar', 'app.asar.unpacked')
  }
  return origin
}
```

Como o build de referência empacotou os binários **dentro** do asar, esse caminho aponta para
`app.asar.unpacked/build/bin/...` — que está **vazio** no AppImage de referência. Ou seja: no
artefato de referência, os zipapps embutidos provavelmente **não** são os executados, e sim os que
o Heroic baixa em `~/.config/heroic/tools/`.

No build novo isso deve ser feito do jeito do upstream (`asarUnpack` em `build/bin/**`), com os
patches de Python aplicados ao zipapp **antes** do empacotamento. Aí o caminho funciona e as
ferramentas corrigidas são as que o app usa.

## O que este levantamento NÃO recupera

- histórico Git, mensagens de commit e ordem original das mudanças;
- comandos e dependências exatas do build original;
- o TypeScript formatado — as linhas acima são a **reconstrução** a partir do JS compilado.
