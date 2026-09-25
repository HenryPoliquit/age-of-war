#!/usr/bin/env bash
# Downloads the pinned headless-capable Godot binary so every cloud session starts identically.
# Usage: source-free — run `tools/setup_env.sh`, then use `tools/godot` (a symlink) for all commands.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/.godot-version")"
CACHE="${GODOT_CACHE:-$HOME/.cache/timefront-godot}/$VERSION"
BIN="$CACHE/Godot_v${VERSION}_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"

if [[ ! -x "$BIN" ]]; then
  mkdir -p "$CACHE"
  echo "Downloading Godot $VERSION ..."
  for delay in 2 4 8 16 0; do
    if curl -fsSL -o "$CACHE/godot.zip" "$URL"; then break; fi
    [[ $delay -eq 0 ]] && { echo "Download failed" >&2; exit 1; }
    sleep "$delay"
  done
  unzip -o -q "$CACHE/godot.zip" -d "$CACHE"
  rm -f "$CACHE/godot.zip"
  chmod +x "$BIN"
fi

ln -sf "$BIN" "$ROOT/tools/godot"
"$ROOT/tools/godot" --headless --version
# Import the project once so class_name globals and resources are registered.
"$ROOT/tools/godot" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
echo "Godot ready: tools/godot"
