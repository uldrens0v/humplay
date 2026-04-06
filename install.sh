#!/bin/bash
set -e

INSTALL_DIR="$HOME/.humplay"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== humplay installer ==="

# check dependencies
missing=()
for dep in mpv yt-dlp socat jq; do
    if ! command -v $dep &>/dev/null; then
        missing+=($dep)
    fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    echo "Missing dependencies: ${missing[*]}"
    echo "Install them first (see README for your distro)."
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# copy files
echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$REPO_DIR/humplay.zsh" "$INSTALL_DIR/"
cp -r "$REPO_DIR/themes" "$INSTALL_DIR/"

# create playlists.conf if it doesn't exist
if [[ ! -f "$INSTALL_DIR/playlists.conf" ]]; then
    cp "$REPO_DIR/playlists.conf" "$INSTALL_DIR/"
    echo "Playlists file created at: $INSTALL_DIR/playlists.conf"
else
    echo "playlists.conf already exists, skipping"
fi

# add source to .zshrc if not present
SOURCE_LINE="source \"$INSTALL_DIR/humplay.zsh\""
if ! grep -qF "humplay.zsh" "$HOME/.zshrc" 2>/dev/null; then
    echo "" >> "$HOME/.zshrc"
    echo "# --- humplay ---" >> "$HOME/.zshrc"
    echo "$SOURCE_LINE" >> "$HOME/.zshrc"
    echo "Added to .zshrc"
else
    echo "Already in .zshrc"
fi

echo ""
echo "Installation complete!"
echo "Run: source ~/.zshrc"
echo "Edit your playlists at: $INSTALL_DIR/playlists.conf"
echo "Usage: humplay <playlist> [--shuffle]"
