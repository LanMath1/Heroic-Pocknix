# Arquitetura do fork

## Princípio

O valor deste repositório é **o diff**, não o binário.

O AppImage de referência já vinha compilado: dentro do `app.asar` está o `build/main/main.js`
gerado pelo **electron-vite** — JavaScript empacotado, não o TypeScript original. Portanto:

- não existe "recuperar o código-fonte" a partir do AppImage;
- o que se recupera é **comportamento**, e ele é re-expresso como patch contra o fonte oficial;
- o histórico Git anterior e o processo de build original **não** são recuperáveis.

## Três camadas

```
upstream/v2.22.4   →   overlay            →   main
(commit-base)         (infraestrutura)       (+ patches)
```

| Camada | O que é | Entra na série exportada? |
|---|---|---|
| **base** | árvore squash do tag do Heroic | — |
| **overlay** | `docs/`, `.github/pocknix-*.yml`, `pocknix/`, `README`/`CHANGELOG`/`COPYING`, `.gitignore`/`.gitattributes` | **não** |
| **patches** | `src/`, `electron-builder.yml`, `package.json` | **sim** |

Motivo de separar overlay de patches: o overlay é *sobrescrito*, não mesclado. A cada tag novo ele é
reconstruído de forma determinística sobre a base nova, então um `README.md` nosso **nunca** gera
conflito de rebase — só os patches de código geram, que é exatamente onde o conflito é informativo.

O overlay é marcado explicitamente pela **tag `overlay`** (não inferido pela posição no histórico —
um commit de overlay novo moveria a fronteira). O `export-patches.sh` exporta
`git format-patch overlay..HEAD`.

### Invariante: overlay vem antes dos patches

O overlay precisa ser **um único commit, ancestral de todos os patches**. Duas consequências
práticas:

- mudança de overlay se dobra no commit de overlay com
  `pocknix/scripts/overlay-commit.sh "mensagem"` — nunca `git commit` direto depois dos patches;
- se você commitar depois, o `export-patches.sh` transforma infraestrutura em "patch de código" e o
  `sync-upstream.sh` reconstrói o overlay a partir de `git diff upstream/<tag>..overlay`, perdendo
  o que ficou de fora.

As correções nas zipapps de legendary/gogdl (que rodam no Python 3.14) **não** são patches de
commit: o código delas não está aqui, é baixado no build. Elas ficam em `pocknix/tools/patches/`
e são aplicadas por `pocknix/scripts/patch-tools.py` antes do empacotamento.

## Como o sync reconstrói

`pocknix/scripts/sync-upstream.sh <tag>`:

1. baixa a árvore do tag e cria a nova base (squash, sem `.github/workflows` do Heroic);
2. **sobrescreve** os caminhos do overlay com a versão do fork (`.gitignore`/`.gitattributes` fazem
   união com o que o upstream adicionou de novo);
3. `git rebase --onto <overlay-novo> <overlay-antigo> main` — só os patches se movem;
4. detecta patches que ficaram obsoletos (o upstream resolveu o mesmo problema);
5. regrava `UPSTREAM_BASE`, a tag `upstream/<tag>` e a série exportada.

Se a árvore do upstream mudar em um arquivo que patchamos, o rebase para e o conflito fica visível
em um patch só — nunca no repositório inteiro.

A base nova **não é órfã**: ela tem a base anterior como pai, então o histórico é uma corrente
linear (`upstream/v2.22.3 → upstream/v2.22.4 → … → upstream/v2.23.0`) e a branch `sync/<tag>` compartilha ancestral
com a `main`. É o que permite revisar o sync em um PR e mergeá-lo com **Rebase and merge**; com
bases órfãs o GitHub não consegue mesclar sem reescrever tudo na mão.


## Proveniência da base

- A base é um **commit único** com a árvore do tag (`upstream: Heroic Games Launcher v2.22.4`),
  não o histórico completo do Heroic — que tem ~719 MB. A árvore em si tem 21 MB e o `.git` deste
  repositório fica em ~16 MB. Cada base aponta para a anterior como pai (corrente linear), então o
  histórico continua navegável e mergeável.
- O SHA do commit upstream vai na mensagem do commit-base; a tag `upstream/<tag>` marca o ponto.
- `.github/workflows/` do upstream é **removido** da base: quem cuida do CI deste fork são os
  `pocknix-*.yml`. Sem isso, 15 workflows do Heroic rodariam aqui e falhariam por falta de secrets.
- O código-fonte publicado fica completo e navegável, mas `git blame` não remonta aos autores
  originais. Para consultar o histórico do Heroic: `git fetch upstream --tags` (local, não publicado).

**Fonte da verdade = os commits na `main`.** A série em `pocknix/patches/` é **gerada** por
`export-patches.sh` e não é versionada (depende dos commits que descreve — versionar criaria
circularidade). O CI exporta e publica como artifact do PR.

## Tamanho do diff é tudo

| Diff | Rebase de release nova |
|---|---|
| ~5 commits pequenos em `src/` | minutos |
| AppDir remendado à mão | inviável |

Regra: se um patch passar de ~30 linhas, provavelmente o problema está sendo resolvido no lugar
errado. Preferir configuração a código, e código a remendo no binário.

## Sincronização com o upstream

`.github/workflows/pocknix-sync-upstream.yml` (agendado):

1. consulta a última release do Heroic;
2. compara com `pocknix/UPSTREAM_BASE`;
3. se mudou: nova base (squash do tag) + overlay reconstruído + rebase dos patches;
4. **detecta patches obsoletos** — se um patch aplica vazio ou o trecho já existe no upstream,
   avisa que aquele patch pode ser removido;
5. regenera `pocknix/patches/` e a tag `upstream/<tag>`;
6. abre PR (rascunho se houver conflito), com o AppImage ARM64 como artefato do PR.

`.github/workflows/pocknix-build.yml` roda em todo PR e push: build + verificação do AppImage
gerado.

`.github/workflows/pocknix-release.yml` roda em tag `v*-pocknix.*`: build, `sha256sum`, publicação
do release com changelog e hash.

## O que deliberadamente NÃO automatizamos

- **Merge e publicação automáticos.** É um launcher de jogos em ARM64; cada release precisa passar
  por Epic, GOG, Amazon, atalhos da Steam, artworks e Game Mode no aparelho real.
- **Auto-update no app.** O upstream usa `electron-updater` com provider GitHub
  (`resources/app-update.yml`). Neste fork a checagem no boot fica desligada por padrão e não há
  canal de update próprio.

## Riscos conhecidos

1. **Ferramentas vendorizadas: onde o patch vale.** Resolvido o mistério — legendary 0.21.1 e
   gogdl 1.3.0 são **zipapps** (`#!/usr/bin/env python3`, logo rodam no Python 3.14 do sistema) e
   estão **dentro** do AppImage, em `build/bin/arm64/linux/`, já com as correções de
   `SharedMemory(track=False)` e `set_start_method("fork")`. O que continua em aberto: no artefato
   de referência esses binários foram empacotados **dentro** do `app.asar`, e `fixAsarPath()`
   reescreve o caminho para `app.asar.unpacked/…`, que está vazio. Ou seja, provavelmente o app em
   execução usava cópias em `~/.config/heroic/tools/`. No build novo: `asarUnpack` como o upstream
   e patches aplicados ao zipapp antes do empacotamento. Detalhes em
   [`RECOVERED-DIFF.md`](RECOVERED-DIFF.md).
2. **Tamanho do `app.asar`.** Explicado: 72,8 MB vs 31,8 MB é a diferença entre binários
   `unpacked` e binários empacotados dentro (mais ícones, `webviewPreload.js` e o backup
   `main.js.before-steam-fix` de 13,2 MB). Não é compressão nem sourcemap.
3. **Deriva de patch.** Toda correção nossa que o upstream adotar deve ser removida do fork, senão
   o diff cresce e o rebase quebra.
4. **Duplicata no zipapp do gogdl.** O pacote traz `gogdl/` (corrigido) e
   `lib.linux-aarch64-cpython-313/gogdl/` (sem correção). Se o import resolver a segunda, o patch
   não tem efeito — validar em runtime.

