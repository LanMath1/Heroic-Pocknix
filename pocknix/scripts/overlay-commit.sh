#!/usr/bin/env bash
# Dobra as mudanças pendentes no commit de overlay.
#
# Por que isto existe: o commit de overlay precisa ficar ANTES dos patches. Se
# uma mudança de infraestrutura for commitada depois deles, ela entra na série
# de patches (que deveria conter só correção de código) ou o `overlay..HEAD`
# passa a mentir. Como overlay é reconstruído no sync a partir do diff
# `upstream/<tag>..overlay`, ele tem que ser um retrato completo.
#
# O que faz: cria um commit temporário com tudo, reaplica por cima do commit de
# overlay (amend), move a tag `overlay`, e reaplica a série de patches com
# cherry-pick.
#
# uso: pocknix/scripts/overlay-commit.sh "docs: ..."
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

MSG="${1:-}"
[ -n "$MSG" ] || { echo 'uso: overlay-commit.sh "mensagem"' >&2; exit 2; }
[ -n "$(git status --porcelain)" ] || { echo "nada para commitar" >&2; exit 0; }

git rev-parse -q --verify refs/tags/overlay >/dev/null \
  || { echo "tag 'overlay' ausente" >&2; exit 1; }
OLD_OVERLAY="$(git rev-parse refs/tags/overlay)"

git add -A
git commit -q -m "$MSG"
TEMP="$(git rev-parse HEAD)"

echo "overlay atual : ${OLD_OVERLAY:0:8}"
echo "mensagem      : $(git log -1 --format=%s "$TEMP")  (o overlay é um squash, só o assunto fica registrado aqui)"
echo "mudanças      :"
git show --stat --oneline --format= "$TEMP" | sed 's/^/  /'

# avisa quando a mudança não é de overlay (esses caminhos são correção de código)
OUTSIDE="$(git show --name-only --format= "$TEMP" \
  | grep -vE '^(docs/|pocknix/|\.github/workflows/pocknix-|\.gitignore$|\.gitattributes$|README|CHANGELOG|COPYING)' || true)"
if [ -n "$OUTSIDE" ]; then
  echo "aviso: caminhos fora do overlay (deveriam ser um patch?):" >&2
  printf '  %s\n' "$OUTSIDE" >&2
fi

# 1. leva as mudanças para cima do commit de overlay, sem criar commit novo
git switch --detach "$OLD_OVERLAY" >/dev/null
if ! git cherry-pick --no-commit "$TEMP" >/dev/null 2>&1; then
  echo "conflito ao reaplicar as mudanças sobre o overlay." >&2
  echo "resolva, rode 'git cherry-pick --continue' e refaça a série." >&2
  exit 1
fi
git commit -q --amend --no-edit
NEW_OVERLAY="$(git rev-parse HEAD)"
git tag -f overlay "$NEW_OVERLAY" >/dev/null

# 2. reaplica a série de patches por cima do overlay novo
N="$(git rev-list --count "$OLD_OVERLAY..$TEMP^" 2>/dev/null || echo 0)"
git switch -C main "$NEW_OVERLAY" >/dev/null
if [ "$N" -gt 0 ]; then
  git cherry-pick $(git rev-list --reverse "$OLD_OVERLAY..$TEMP^") >/dev/null
fi

echo "overlay novo  : $(git rev-parse --short refs/tags/overlay)"
echo "patches       : $N reaplicados"
git log --oneline | sed 's/^/  /'
