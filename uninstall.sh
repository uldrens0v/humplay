#!/bin/bash
set -e

INSTALL_DIR="$HOME/.humplay"

echo "=== humplay uninstaller ==="

# remove directory
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed: $INSTALL_DIR"
fi

# remove lines from .zshrc
if grep -qF "humplay" "$HOME/.zshrc" 2>/dev/null; then
    sed -i '/humplay/d' "$HOME/.zshrc"
    echo "Removed from .zshrc"
fi

echo "Uninstall complete. Run: source ~/.zshrc"
