#!/usr/bin/env bash
# Exporta a série de patches.
#
# Modelo de 3 camadas:
#   base    = upstream/<tag>                 (squash da árvore do tag)
#   overlay = base + camada de infraestrutura deste repo (docs, pocknix/, workflows)
#   patches = overlay + correções de código  ← é o que este script exporta
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

BASE="$(tr -d '[:space:]' < pocknix/UPSTREAM_BASE)"
[ -n "$BASE" ] || { echo "pocknix/UPSTREAM_BASE vazio" >&2; exit 1; }
git rev-parse -q --verify "refs/tags/upstream/$BASE" >/dev/null \
  || { echo "tag 'upstream/$BASE' ausente — base inconsistente" >&2; exit 1; }

# fronteira overlay/patches marcada explicitamente (não inferida pela posição)
git rev-parse -q --verify "refs/tags/overlay" >/dev/null \
  || { echo "tag 'overlay' ausente — rode sync-upstream.sh ou recrie a marca" >&2; exit 1; }

OVERLAY="$(git rev-parse "refs/tags/overlay")"

COUNT="$(git rev-list --count "$OVERLAY..HEAD")"
echo "base    : $BASE"
echo "overlay : ${OVERLAY:0:8}"
echo "patches : $COUNT"

rm -f pocknix/patches/*.patch
if [ "$COUNT" -gt 0 ]; then
  git format-patch "$OVERLAY..HEAD" -o pocknix/patches --no-signature --zero-commit >/dev/null
  ls -1 pocknix/patches/*.patch
else
  echo "(nenhuma correção ainda — main está só base + overlay)"
fi
