#!/usr/bin/env bash
# Sincroniza com um tag do upstream.
#
# Modelo de 3 camadas:
#   base    = upstream/<tag>    squash da árvore do tag (sem .github/workflows do Heroic)
#   overlay = base + camada de infraestrutura deste repo (docs, pocknix/, workflows pocknix-*)
#   main    = overlay + correções de código (os patches)
#
# A cada tag novo: nova base, overlay reconstruído de forma determinística (sem merge),
# e só então os patches são rebaseados — assim um README nosso nunca gera conflito.
#
# uso: sync-upstream.sh <tag>
# saída: 0 = ok ou já sincronizado | 2 = conflito nos patches
set -euo pipefail

TAG="${1:?uso: sync-upstream.sh <tag>}"
UPSTREAM_REPO="${UPSTREAM_REPO:-Heroic-Games-Launcher/HeroicGamesLauncher}"

REPO="$(git rev-parse --show-toplevel)"
GITDIR="$(git rev-parse --absolute-git-dir)"
cd "$REPO"

BASE_TAG="$(tr -d '[:space:]' < pocknix/UPSTREAM_BASE)"
if [ "$TAG" = "$BASE_TAG" ]; then
  echo "já sincronizado com $TAG"
  exit 0
fi

git rev-parse -q --verify "refs/tags/upstream/$BASE_TAG" >/dev/null \
  || { echo "tag 'upstream/$BASE_TAG' ausente — base inconsistente" >&2; exit 1; }

OLD_BASE="refs/tags/upstream/$BASE_TAG"
git rev-parse -q --verify "refs/tags/overlay" >/dev/null \
  || { echo "tag 'overlay' ausente — base inconsistente" >&2; exit 1; }
OLD_OVERLAY="$(git rev-parse "refs/tags/overlay")"

BEFORE="$(git rev-list --count "$OLD_OVERLAY..main")"
TMPLOG="$(mktemp)"
git log --format='%s' "$OLD_OVERLAY..main" | sort > "$TMPLOG"

echo "base atual : $BASE_TAG"
echo "nova base  : $TAG"
echo "patches    : $BEFORE"

# --- 1. nova base ---------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$IDX" "$TMPLOG"' EXIT
IDX="$TMP.idx"

echo "baixando árvore de $TAG..."
curl -fsSL "https://codeload.github.com/$UPSTREAM_REPO/tar.gz/refs/tags/$TAG" \
  | tar xz -C "$TMP" --strip-components=1

# o CI deste fork é próprio
rm -rf "$TMP/.github/workflows"

UPSTREAM_SHA="$(git ls-remote "https://github.com/$UPSTREAM_REPO.git" "refs/tags/$TAG^{}" | cut -f1)"
[ -n "$UPSTREAM_SHA" ] || UPSTREAM_SHA="$(git ls-remote "https://github.com/$UPSTREAM_REPO.git" "refs/tags/$TAG" | cut -f1)"

TREE="$(
  cd "$TMP"
  GIT_DIR="$GITDIR" GIT_INDEX_FILE="$IDX" git add -A -f . >/dev/null
  GIT_DIR="$GITDIR" GIT_INDEX_FILE="$IDX" git write-tree
)"

NEW_BASE="$(GIT_DIR="$GITDIR" git commit-tree "$TREE" -p "$OLD_BASE" -m "upstream: Heroic Games Launcher $TAG

Árvore squash do tag $TAG de $UPSTREAM_REPO
(commit upstream $UPSTREAM_SHA).

O histórico completo do Heroic não é importado: este fork precisa de uma base
estável para reaplicar os patches. Consulte com 'git fetch upstream --tags'.

.github/workflows/ do upstream removido: o CI deste fork é próprio.

Gerado por pocknix/scripts/sync-upstream.sh.")"
echo "nova base  : ${NEW_BASE:0:8}"

# --- 2. overlay reconstruído (sobrescreve, não faz merge) -----------------------
OVERLAY_PATHS="$(git diff --name-only "$OLD_BASE..$OLD_OVERLAY")"

git switch -c "overlay-$TAG" "$NEW_BASE" >/dev/null
git checkout "$OLD_OVERLAY" -- $OVERLAY_PATHS

# .gitignore/.gitattributes: união com o que o upstream trouxe de novo
for f in .gitignore .gitattributes; do
  case " $OVERLAY_PATHS " in
    *" $f "*)
      UP_ONLY="$(mktemp)"
      git show "$NEW_BASE:$f" > "$UP_ONLY" 2>/dev/null || : > "$UP_ONLY"
      awk 'NR==FNR { seen[$0]=1; next }
           $0 != "" && !($0 in seen) { print }' "$f" "$UP_ONLY" >> "$f"
      rm -f "$UP_ONLY"
      ;;
  esac
done

git add -A
# UPSTREAM_BASE é conteúdo de overlay: precisa entrar NO commit de overlay, que
# fica antes dos patches. Se fosse commitado depois, viraria um "patch" e o
# overlay reconstruído no próximo sync perderia o arquivo.
printf '%s\n' "$TAG" > pocknix/UPSTREAM_BASE
git add pocknix/UPSTREAM_BASE
git commit -q -m "chore(overlay): infraestrutura do fork sobre $TAG"
NEW_OVERLAY="$(git rev-parse HEAD)"
echo "novo overlay: ${NEW_OVERLAY:0:8}"

# --- 3. rebase dos patches ------------------------------------------------------
# o rebase roda na branch atual (sync/$TAG). Passar `main` como argumento
# reescreveria a main e deixaria a branch de sync apontando para o commit velho.
git switch -C "sync/$TAG" main >/dev/null
if ! git rebase --onto "$NEW_OVERLAY" "$OLD_OVERLAY"; then
  echo
  echo "CONFLITO de rebase em sync/$TAG — resolva manualmente:" >&2
  git status --short >&2
  echo
  echo "  git rebase --continue   # após resolver"
  echo "  git rebase --abort      # para descartar"
  exit 2
fi

AFTER="$(git rev-list --count "$NEW_OVERLAY..HEAD")"
git log --format='%s' "$NEW_OVERLAY..HEAD" | sort > "$TMPLOG.after"
echo
echo "patches após rebase: $AFTER (antes: $BEFORE)"
if [ "$AFTER" -lt "$BEFORE" ]; then
  echo "PATCHES OBSOLETOS — o upstream já resolveu isto, remova do fork:"
  comm -23 "$TMPLOG" "$TMPLOG.after" | sed 's/^/  - /'
fi

# --- 4. registra a nova base ----------------------------------------------------
# patch não deve mexer em caminho de overlay: o conteúdo já está no overlay e a
# correção viraria duplicada (e o overlay do próximo sync nasceria desatualizado)
TOUCHED="$(git diff --name-only "$NEW_OVERLAY..HEAD" \
  | grep -E '^(docs/|pocknix/|\.github/workflows/pocknix-|\.gitignore$|\.gitattributes$|README|CHANGELOG|COPYING)' || true)"
if [ -n "$TOUCHED" ]; then
  echo "aviso: patch mexendo em caminho de overlay (deveria estar no commit de overlay):" >&2
  printf '  %s\n' $TOUCHED >&2
fi

# nada a commitar aqui: UPSTREAM_BASE já entrou no commit de overlay
git tag -f "upstream/$TAG" "$NEW_BASE" >/dev/null
git tag -f overlay "$NEW_OVERLAY" >/dev/null
git branch -D "overlay-$TAG" >/dev/null 2>&1 || true
bash pocknix/scripts/export-patches.sh

if [ -n "$(git status --porcelain)" ]; then
  echo "aviso: a árvore não está limpa após o sync:" >&2
  git status --short >&2
fi

echo
echo "branch pronta: sync/$TAG"
echo "próximo passo: push e abrir PR (o CI builda o AppImage para validação)"
