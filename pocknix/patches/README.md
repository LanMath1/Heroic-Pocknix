# Série de patches

Um arquivo por correção, **gerado** por:

```bash
pocknix/scripts/export-patches.sh    # = git format-patch overlay..HEAD
```

A fonte da verdade são os **commits da `main`**, não estes arquivos. Eles não são versionados
(`.gitignore` cobre `pocknix/patches/*.patch`) porque dependem dos commits que descrevem — versionar
o artefato criaria circularidade. O CI exporta a série e publica como artifact de cada PR.

## Convenção

```
NNNN-descricao-curta-em-kebab-case.patch
```

Cada mensagem de commit deve conter:

- **sintoma** — o que o usuário via (ex.: "atalho da Steam abre e fecha");
- **causa** — o que no código provocava;
- **mudança** — a menor alteração que resolve;
- **verificação** — como foi testado no aparelho.

## Regras

1. Um patch = uma correção. Não misturar configuração com código.
2. Preferir configuração a código; código a remendo em binário.
3. Se um patch passar de ~30 linhas, revisar se o problema está sendo resolvido no lugar certo.
4. Quando o upstream adotar a correção, **remover o patch** — não deixar como no-op.
5. Patch que mexe em ferramenta vendorizada (legendary/GOGDL) precisa dizer explicitamente onde
   ele é aplicado, já que essas ferramentas não estão dentro do AppImage.

## O que não é patch

`docs/`, `.github/`, `pocknix/`, `README.md`, `CHANGELOG.md`, `COPYING`, `.gitignore` e
`.gitattributes` formam a **camada de overlay**: existem só neste repositório e são reconstruídos
sobre cada base nova, nunca exportados como patch. Se você editou só isso, o `export-patches.sh`
não gera patch nenhum — e está correto.

## Patches previstos

| # | Assunto | Status |
|---|---|---|
| 0001 | atalhos Steam: `Target=/usr/bin/env` + `heroic://launch?...` | a derivar |
| 0002 | `addSteamShortcuts: true` por padrão | a derivar |
| 0003 | `checkForUpdatesOnStartup: false` | a derivar |
| 0004 | Legendary / Python 3.14 `multiprocessing` | a investigar (fora do AppImage?) |
| 0005 | GOGDL / Python 3.14 `multiprocessing` + `SharedMemory` | a investigar (fora do AppImage?) |
