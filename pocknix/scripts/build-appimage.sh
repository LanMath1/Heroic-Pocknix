#!/usr/bin/env bash
# Build do AppImage ARM64. Espera rodar em aarch64 nativo.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

ARCH="$(uname -m)"
if [ "$ARCH" != "aarch64" ] && [ "${FORCE_ARCH:-0}" != "1" ]; then
  echo "arquitetura atual: $ARCH — este build precisa de aarch64 nativo." >&2
  echo "use um runner ubuntu-24.04-arm, ou FORCE_ARCH=1 para insistir." >&2
  exit 1
fi

NODE_PIN="22.23.3"
PNPM_PIN="12.5.1"

need() { command -v "$1" >/dev/null 2>&1 || { echo "faltando: $1" >&2; exit 1; }; }
need node
need curl

NODE_VER="$(node --version | sed 's/^v//')"
if [ "$NODE_VER" != "$NODE_PIN" ]; then
  echo "aviso: node $NODE_VER (pin do projeto: $NODE_PIN)" >&2
fi

corepack enable
corepack prepare "pnpm@$PNPM_PIN" --activate

pnpm install --frozen-lockfile

# binários auxiliares: sem isso build/bin não existe e o AppImage sai sem
# legendary/gogdl/nile/comet
pnpm download-helper-binaries

# legendary e gogdl são zipapps e rodam no Python do sistema (3.14 no Pocknix)
if ! command -v python3 >/dev/null 2>&1; then
  echo "faltando: python3 (necessário para o patch-tools.py)" >&2
  exit 1
fi
python3 pocknix/scripts/patch-tools.py \
  public/bin/arm64/linux/legendary \
  public/bin/arm64/linux/gogdl

pnpm build
pnpm exec electron-builder --linux AppImage --arm64 --publish never

echo
ls -l dist/*.AppImage
sha256sum dist/*.AppImage | tee dist/SHA256SUMS.txt

bash pocknix/scripts/verify.sh dist/*.AppImage
