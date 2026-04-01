#!/bin/bash
set -e

INSTALL_DIR="$HOME/.zsh-music-player"

echo "=== zsh-music-player uninstaller ==="

# remove directory
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed: $INSTALL_DIR"
fi

# remove lines from .zshrc
if grep -qF "zsh-music-player" "$HOME/.zshrc" 2>/dev/null; then
    sed -i '/zsh-music-player/d' "$HOME/.zshrc"
    echo "Removed from .zshrc"
fi

echo "Uninstall complete. Run: source ~/.zshrc"
