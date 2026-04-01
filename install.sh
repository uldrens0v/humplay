#!/bin/bash
set -e

INSTALL_DIR="$HOME/.zsh-music-player"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== zsh-music-player installer ==="

# comprobar dependencias
missing=()
for dep in mpv yt-dlp socat jq; do
    if ! command -v $dep &>/dev/null; then
        missing+=($dep)
    fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    echo "Dependencias faltantes: ${missing[*]}"
    echo "Instala con:"
    echo "  sudo apt install ${missing[*]}"
    echo ""
    read -p "Continuar de todas formas? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# copiar archivos
echo "Instalando en $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$REPO_DIR/music.zsh" "$INSTALL_DIR/"

# crear playlists.conf si no existe
if [[ ! -f "$INSTALL_DIR/playlists.conf" ]]; then
    cp "$REPO_DIR/playlists.conf" "$INSTALL_DIR/"
    echo "Archivo de playlists creado en: $INSTALL_DIR/playlists.conf"
else
    echo "playlists.conf ya existe, no se sobreescribe"
fi

# agregar source al .zshrc si no esta
SOURCE_LINE="source \"$INSTALL_DIR/music.zsh\""
if ! grep -qF "zsh-music-player" "$HOME/.zshrc" 2>/dev/null; then
    echo "" >> "$HOME/.zshrc"
    echo "# --- zsh-music-player ---" >> "$HOME/.zshrc"
    echo "$SOURCE_LINE" >> "$HOME/.zshrc"
    echo "Agregado a .zshrc"
else
    echo "Ya esta en .zshrc"
fi

echo ""
echo "Instalacion completa!"
echo "Ejecuta: source ~/.zshrc"
echo "Edita tus playlists en: $INSTALL_DIR/playlists.conf"
echo "Usa: music <playlist> [--shuffle]"
