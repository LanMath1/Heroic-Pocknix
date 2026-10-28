# Patches das ferramentas auxiliares

Os binários `legendary` e `gogdl` que o Heroic baixa em `public/bin/arm64/linux/` são
**zipapps** com `#!/usr/bin/env python3` — rodam no Python do sistema. No Pocknix esse Python é
o **3.14**, e é aí que eles quebram.

Estes patches não são commits: o código corrigido não está no nosso repositório, ele é baixado
de terceiros no momento do build. Por isso a correção vive aqui como arquivo `.patch` do
`patch(1)` e é aplicada por `pocknix/scripts/patch-tools.py` antes do empacotamento.

## O problema

| Mudança no Python 3.14 | Efeito |
|---|---|
| o start method padrão do `multiprocessing` no Linux passou de `fork` para `forkserver` | o filho do `Process` é serializado para outro processo; `SharedMemory`, `Queue` e os objetos que legendary/gogdl passam não são picklables → o download travava |
| `SharedMemory` registrado no `resource_tracker` por padrão | avisos de vazamento e limpeza indevida do segmento enquanto os filhos ainda usam |

## A correção

```
set_start_method("fork", force=True)       # em cli.py, antes de qualquer Pool/Process
SharedMemory(..., track=False)             # em quem cria e em quem anexa
```

## Arquivos

| Patch | Aplica em | Versão |
|---|---|---|
| `patches/legendary-0.21.1-py314.patch` | `legendary_linux_arm64` | 0.21.1 (tag `0.21.1`) |
| `patches/gogdl-1.3.0-py314.patch` | `gogdl_linux_arm64` | v1.3.0 (tag `v1.3.0`) |

As versões são as de `RELEASE_TAGS` em `meta/downloadHelperBinaries.ts`. Os diffs foram gerados
contra os binários oficiais dessas releases:

```
legendary_linux_arm64  sha256 e901cb52ada10d5cef6ffb2a0985099958124457bfb455a571023d1e042143d9
gogdl_linux_arm64      sha256 c49e1519146523ec94f33e2d21eedcc9a167004d7da218621e6d5fb84a7a0f4c
```

Ambos rodam em modo `--fuzz=0`: se o upstream mexer nessas linhas numa versão nova, o build
**falha** em vez de aplicar o patch torto. O `patch-tools.py` também falha se um patch daqui não
for aplicado em nenhuma zipapp — patch órfão não passa em silêncio.

## O que não é corrigido

`gogdl` carrega uma segunda cópia do pacote em `lib.linux-aarch64-cpython-313/gogdl/` (sobra do
build com mypyc). Ela **não** é corrigida, e não precisa: o `sys.path` da zipapp tem a raiz como
primeiro item, então `import gogdl` resolve `gogdl/`; além disso o diretório é para cpython-313
e o runtime é 3.14. Os `.so` mypyc (`*__mypyc.cpython-*.so`) só compilam `charset_normalizer`,
conferido com `strings ... | grep PyInit_`.

`nile` é binário ELF (PyInstaller), roda com o Python embutido — não é afetado.

`comet` é Rust — não é afetado.
