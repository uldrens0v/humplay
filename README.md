# zsh-music-player

A minimal terminal music player for YouTube playlists. No ads, no browser, just music.

Built with `mpv` + `yt-dlp` and controlled via IPC socket from your terminal.

![shell](https://img.shields.io/badge/shell-zsh-blue)
![license](https://img.shields.io/badge/license-MIT-green)

## Features

- Play YouTube playlists directly from the terminal
- No ads (bypasses YouTube web player via yt-dlp)
- Colored single-line status: playlist name, track title, volume, progress bar
- Keyboard controls (volume, seek, next/prev, pause)
- Custom playlist aliases via simple config file
- Shuffle mode

## Requirements

- **zsh** (your default shell must be zsh)
- **mpv** - media player
- **yt-dlp** - YouTube extractor (must be up to date)
- **socat** - IPC socket communication
- **jq** - JSON parsing

### Install dependencies

**Debian / Ubuntu:**
```bash
sudo apt install mpv socat jq
```

**Arch Linux:**
```bash
sudo pacman -S mpv socat jq
```

**Fedora:**
```bash
sudo dnf install mpv socat jq
```

**macOS:**
```bash
brew install mpv socat jq
```

### Install yt-dlp (latest version required)

The version from your package manager may be outdated. Install the latest directly:

```bash
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
```

Verify it works:
```bash
yt-dlp --version
```

If YouTube changes break extraction, update with:
```bash
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
```

> **Note:** yt-dlp may require a JavaScript runtime (deno) for some YouTube formats. If you see a warning about it, install deno: `curl -fsSL https://deno.land/install.sh | sh`

## Install

```bash
git clone https://github.com/uldrens0v/zsh-music-player.git
cd zsh-music-player
chmod +x install.sh
./install.sh
source ~/.zshrc
```

## Configure playlists

Edit `~/.zsh-music-player/playlists.conf`:

```conf
# Format: name=URL
# One playlist per line. Lines starting with # are comments.

lofi=https://www.youtube.com/playlist?list=PLofht4PTcKYnaH8w5olJCI-wUVxuoMHqM
rock=https://www.youtube.com/playlist?list=PLxxxxxxx
chill=https://www.youtube.com/playlist?list=PLyyyyyyy
```

Then just use the name you defined:

```bash
music lofi
```

## Usage

```bash
music              # list available playlists and controls
music lofi         # play a playlist by name
music lofi -s      # play shuffled
music lofi --shuffle
music "https://www.youtube.com/playlist?list=PLxxxxx"   # play any URL directly
```

## Controls

| Key | Action |
|-----|--------|
| `space` | pause / play |
| `9` / `0` | volume down / up (5%) |
| `↑` / `↓` | next / previous track |
| `←` / `→` | seek -5s / +5s |
| `q` | quit |

## How it works

1. Launches `mpv` in the background with `--no-terminal` and an IPC socket
2. A zsh loop queries mpv properties (title, volume, position) via the socket using `socat`
3. Renders a single-line colored status bar with `printf \r` (no scrolling)
4. Reads keyboard input with `read -sk1 -t1` and sends commands back to mpv via IPC

## Troubleshooting

**"Error: yt-dlp no esta instalado"**
Install yt-dlp following the instructions above.

**No audio / "Requested format is not available"**
Your yt-dlp is outdated. Update it with the curl command above.

**"No supported JavaScript runtime"**
Install deno: `curl -fsSL https://deno.land/install.sh | sh`

**Status line overflows / multiple lines**
Resize your terminal wider, or the title will be auto-truncated.

## Uninstall

```bash
cd zsh-music-player
chmod +x uninstall.sh
./uninstall.sh
source ~/.zshrc
```

## License

MIT
