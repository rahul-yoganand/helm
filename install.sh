#!/usr/bin/env bash
# Put the `helm` CLI on PATH so it runs as `helm` from any project directory.
# Usage: ./install.sh [target-bin-dir]   (default: ~/.local/bin)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$HOME/.local/bin}"

mkdir -p "$TARGET_DIR"
ln -sf "$HERE/helm" "$TARGET_DIR/helm"
echo "Linked $TARGET_DIR/helm -> $HERE/helm"
echo "(It's a symlink to the source file, so 'git pull' in $HERE keeps it current — no reinstall needed.)"

case ":$PATH:" in
  *":$TARGET_DIR:"*)
    echo
    echo "helm is on PATH. Try:  helm init <repo> [--preset default|jarvis|kestrel|path.json]"
    ;;
  *)
    echo
    echo "NOTE: $TARGET_DIR is not on your PATH yet. Add this to your shell profile"
    echo "(~/.zshrc or ~/.bashrc), then restart your shell:"
    echo
    echo "  export PATH=\"$TARGET_DIR:\$PATH\""
    ;;
esac
