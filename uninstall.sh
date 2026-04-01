#!/bin/bash
set -e

INSTALL_DIR="$HOME/.zsh-music-player"

echo "=== zsh-music-player uninstaller ==="

# eliminar directorio
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo "Eliminado: $INSTALL_DIR"
fi

# eliminar lineas de .zshrc
if grep -qF "zsh-music-player" "$HOME/.zshrc" 2>/dev/null; then
    sed -i '/zsh-music-player/d' "$HOME/.zshrc"
    echo "Eliminado de .zshrc"
fi

echo "Desinstalacion completa. Ejecuta: source ~/.zshrc"
