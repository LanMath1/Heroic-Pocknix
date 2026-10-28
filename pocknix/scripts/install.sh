#!/usr/bin/env bash
# Instala/atualiza o AppImage em /home/deck/Applications/Heroic.
# Nunca toca em /home/deck/Games/Heroic nem /home/deck/.config/heroic.
#
# uso: install.sh <arquivo.AppImage> [sha256-esperado]
set -euo pipefail

SRC="${1:?uso: install.sh <arquivo.AppImage> [sha256-esperado]}"
EXPECTED="${2:-}"
DEST_DIR="${DEST_DIR:-$HOME/Applications/Heroic}"
DEST="$DEST_DIR/Heroic-Pocknix.AppImage"

[ -f "$SRC" ] || { echo "não encontrado: $SRC" >&2; exit 1; }

ACTUAL="$(sha256sum "$SRC" | cut -d' ' -f1)"
echo "origem : $SRC"
echo "sha256 : $ACTUAL"
if [ -n "$EXPECTED" ]; then
  [ "$ACTUAL" = "$EXPECTED" ] || { echo "hash não confere com o esperado: $EXPECTED" >&2; exit 1; }
  echo "hash   : confere"
fi

mkdir -p "$DEST_DIR"
if [ -f "$DEST" ]; then
  BKP="$DEST.$(date +%Y%m%d-%H%M%S).bak"
  cp -p "$DEST" "$BKP"
  echo "backup : $BKP"
fi

cp "$SRC" "$DEST.new"
chmod +x "$DEST.new"
mv -f "$DEST.new" "$DEST"

echo "instalado em: $DEST"
echo
echo "dados preservados (não tocados):"
echo "  $HOME/Games/Heroic"
echo "  $HOME/.config/heroic"
