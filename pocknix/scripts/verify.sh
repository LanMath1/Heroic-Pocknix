#!/usr/bin/env bash
# Verifica um AppImage gerado: arquitetura, layout do electron-builder,
# patches presentes no bundle e zipapps corrigidas.
# uso: verify.sh <arquivo.AppImage>
set -euo pipefail

APPIMAGE="${1:?uso: verify.sh <arquivo.AppImage>}"
[ -f "$APPIMAGE" ] || { echo "não encontrado: $APPIMAGE" >&2; exit 1; }

fail=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FALHA %s\n' "$1"; fail=1; }

echo "== $APPIMAGE"
echo "  tamanho: $(wc -c <"$APPIMAGE") bytes"
echo "  sha256 : $(sha256sum "$APPIMAGE" | cut -d' ' -f1)"

# --- arquitetura -------------------------------------------------------------
EM="$(od -An -tx1 -j18 -N2 "$APPIMAGE" | tr -d ' \n')"
if [ "$EM" = "b700" ]; then ok "arquitetura aarch64 (e_machine 0xB7)"
else bad "arquitetura inesperada: e_machine 0x$EM (esperado b700)"; fi

# --- extração ----------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$APPIMAGE" "$TMP/app.AppImage"
chmod +x "$TMP/app.AppImage"
if ( cd "$TMP" && ./app.AppImage --appimage-extract >/dev/null 2>&1 ); then
  DIR="$TMP/squashfs-root"
  ok "extração do AppImage"
else
  bad "extração do AppImage"; echo; exit 1
fi

# --- layout (o do electron-builder, não o do artefato de referência) ---------
for p in AppRun heroic heroic.desktop heroic.png resources/app.asar; do
  [ -e "$DIR/$p" ] && ok "$p" || bad "$p ausente"
done

if [ -x "$DIR/AppRun" ] && grep -q 'APPDIR' "$DIR/AppRun" \
   && grep -q 'exec ' "$DIR/AppRun"; then
  ok "AppRun executável e executa o binário"
else
  bad "AppRun inválido"
fi

# --- .desktop ----------------------------------------------------------------
DESK="$DIR/heroic.desktop"
if [ -f "$DESK" ]; then
  for field in '^Name=' '^Exec=AppRun' '^Icon=' '^MimeType=x-scheme-handler/heroic;' \
               '^Categories=Game;'; do
    grep -q "$field" "$DESK" && ok ".desktop tem ${field#^}" \
      || bad ".desktop sem ${field#^}"
  done
else
  bad "heroic.desktop ausente"
fi

# --- patches de código dentro do bundle -------------------------------------
# literais que só existem por causa dos patches deste fork
ASAR="$DIR/resources/app.asar"
for marker in 'APPIMAGE_EXTRACT_AND_RUN=1' 'FUSERMOUNT_PROG=/usr/bin/fusermount' \
              '--gamemode'; do
  if grep -qa -- "$marker" "$ASAR"; then
    ok "app.asar contém '$marker'"
  else
    bad "app.asar sem '$marker' (patch de código não entrou?)"
  fi
done

# --- ferramentas auxiliares (zipapps) ---------------------------------------
check_tool() {
  local tool="$1" f="$2"
  if [ ! -f "$f" ]; then
    bad "$tool ausente em app.asar.unpacked (faltou download-helper-binaries?)"
    return
  fi
  [ -x "$f" ] && ok "$tool executável" || bad "$tool sem permissão de execução"
  if python3 - "$f" "$tool" <<'PY'
import sys, zipfile

path, tool = sys.argv[1], sys.argv[2]
FORK = 'set_start_method("fork", force=True)'
expect = {
    "legendary": {
        "legendary/cli.py": (FORK, 1),
        "legendary/downloader/mp/workers.py": ("track=False", 2),
        "legendary/downloader/mp/manager.py": ("track=False", 1),
    },
    "gogdl": {
        "gogdl/cli.py": (FORK, 1),
        "gogdl/dl/workers/task_executor.py": ("track=False", 2),
        "gogdl/dl/managers/task_executor.py": ("track=False", 1),
    },
}[tool]

with zipfile.ZipFile(path) as zf:
    for name, (marker, count) in expect.items():
        total = zf.read(name).decode("utf-8").count(marker)
        if total < count:
            raise SystemExit(f"{name}: {marker!r} {total}x (esperado {count}x)")
PY
  then
    ok "$tool: patch de Python 3.14 presente"
  else
    bad "$tool: zipapp sem o patch de Python 3.14"
  fi
}

BIN="$DIR/resources/app.asar.unpacked/build/bin/arm64/linux"
check_tool legendary "$BIN/legendary"
check_tool gogdl "$BIN/gogdl"
for tool in nile comet vulkan-helper; do
  [ -f "$BIN/$tool" ] && ok "$tool presente" || bad "$tool ausente"
done

# --- app.asar ----------------------------------------------------------------
if [ -f "$ASAR" ]; then
  echo "  app.asar: $(wc -c <"$ASAR") bytes  \
sha256 $(sha256sum "$ASAR" | cut -d' ' -f1)"
fi

echo
[ "$fail" -eq 0 ] && echo "RESULTADO: ok" || { echo "RESULTADO: falhou"; exit 1; }
