# zsh-music-player

A terminal music player for YouTube playlists with an RGB bar visualizer and track list. No ads, no browser, just music.

Built with `mpv` + `yt-dlp` and controlled via IPC socket from your terminal.

![shell](https://img.shields.io/badge/shell-zsh-blue)
![license](https://img.shields.io/badge/license-MIT-green)

## Preview

![preview](screenshots/preview.png)

```
  ██          ██                ██
  ██ ██    ██ ██ ██      ██    ██ ██
  ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██ ██
  G──────────────────────────────────A
▶ YouTube · chill  ♪ S I C K  Vol: 40%  00:32 ━━━━━━━━━━━━ 03:21
```

## Features

- Play YouTube playlists directly from the terminal
- No ads (bypasses YouTube web player via yt-dlp)
- **RGB bar visualizer** that adapts to terminal width, with G (grave) to A (agudo) frequency indicator
- **Track list overlay** (press `t`) showing previous and upcoming songs with real-time updates
- **Platform logo** next to playlist name (YouTube, SoundCloud, Spotify, Bandcamp)
- Full-screen alternate buffer rendering (no terminal scroll pollution)
- Keyboard controls (volume, seek, next/prev, pause)
- Multi-platform support: YouTube, SoundCloud, Bandcamp, Spotify
- Custom playlist aliases via config file
- Shuffle mode

## Dependencies

### Required

| Tool | Purpose |
|------|---------|
| [mpv](https://mpv.io) | Audio playback |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | YouTube/URL extraction |
| [socat](http://www.dest-unreach.org/socat/) | IPC socket communication |
| [jq](https://github.com/jqlang/jq) | JSON parsing |

### Optional

| Tool | Purpose |
|------|---------|
| [cava](https://github.com/karlstav/cava) | RGB bar visualizer |
| [spotdl](https://github.com/spotDL/spotify-downloader) | Spotify playlist support |

### Install dependencies

<details>
<summary><b>Debian / Ubuntu</b></summary>

```bash
# Required
sudo apt install mpv socat jq

# Optional: RGB bar visualizer
sudo apt install cava
```
</details>

<details>
<summary><b>Arch Linux</b></summary>

```bash
# Required
sudo pacman -S mpv socat jq

# Optional: RGB bar visualizer
sudo pacman -S cava
```
</details>

<details>
<summary><b>Fedora</b></summary>

```bash
# Required
sudo dnf install mpv socat jq

# Optional: RGB bar visualizer (from COPR)
sudo dnf copr enable zeno/cava
sudo dnf install cava
```
</details>

<details>
<summary><b>macOS</b></summary>

```bash
# Required
brew install mpv socat jq

# Optional: RGB bar visualizer
brew install cava
```
</details>

### yt-dlp (latest version required)

Package managers often ship outdated versions. Install the latest directly:

```bash
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
```

> **Note:** yt-dlp may require a JavaScript runtime. If you see a warning about it, install deno: `curl -fsSL https://deno.land/install.sh | sh`

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
lofi=https://www.youtube.com/playlist?list=PLofht4PTcKYnaH8w5olJCI-wUVxuoMHqM
rock=https://www.youtube.com/playlist?list=PLxxxxxxx
chill=https://www.youtube.com/playlist?list=PLyyyyyyy
```

Or fetch playlists automatically from a YouTube channel:

```bash
music fetch uldrens0v
```

## Usage

```bash
music                  # list available playlists
music lofi             # play a playlist
music lofi -s          # play shuffled
music lofi --no-vis    # play without visualizer
music "URL"            # play any YouTube URL directly
music fetch <source>   # import playlists from a channel/URL
```

## Controls

| Key | Action |
|-----|--------|
| `space` | pause / play |
| `-` / `+` | volume down / up (5%) |
| `↑` / `↓` | previous / next track |
| `←` / `→` | seek -5s / +5s |
| `v` | toggle RGB bar visualizer |
| `t` | toggle track list |
| `q` | quit |

## RGB Bar Visualizer

When `cava` is installed, the player displays an RGB frequency visualizer that **adapts to your terminal width**. Each bar is colored in a gradient from red (bass) to blue (treble):

```
  ██                    ██            ██
  ██ ██          ██     ██      ██    ██ ██
  ██ ██ ██    ██ ██  ██ ██ ██   ██    ██ ██
  ██ ██ ██ ██ ██ ██  ██ ██ ██   ██ ██ ██ ██ ██
  ██ ██ ██ ██ ██ ██  ██ ██ ██ ██ ██ ██ ██ ██ ██
  G────────────────────────────────────────────A
```

- **G** = Grave (bass/low frequencies)
- **A** = Agudo (treble/high frequencies)
- Color gradient: Red -> Yellow -> Green -> Cyan -> Blue
- Bar count adapts dynamically to terminal width

Toggle with `v` during playback. Use `--no-vis` to start without it.

## Track List

Press `t` during playback to open the track list overlay:

```
     3. Previous Song
     4. Another Song
     5. One More Song
   ► 6. Currently Playing ◄
     7. Next Song
     8. After That
     9. Later Song
```

- Shows up to 3 previous and 3 next tracks around the current one
- If the current song is the **first**, no previous tracks are shown
- If the current song is the **last**, no next tracks are shown
- Current track is highlighted with reverse video
- Updates in real-time when the track changes
- Press `t` again to close

## How it works

1. Launches `mpv` in the background with `--no-terminal` and an IPC socket
2. Opens an alternate screen buffer for clean full-screen rendering
3. A zsh loop queries mpv properties (title, volume, position, playlist) via the socket using `socat`
4. `cava` sends audio frequency data through a FIFO pipe; bars are dynamically grouped to fit terminal width
5. Renders a multi-line display (track list + visualizer + status bar) from a fixed top position using ANSI escape codes
6. Reads keyboard input with `read -sk1` and sends commands back to mpv via IPC
7. On exit, restores the original terminal screen

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Error: yt-dlp is not installed` | Install yt-dlp with the curl command above |
| No audio / format not available | Update yt-dlp to the latest version |
| No supported JavaScript runtime | Install deno: `curl -fsSL https://deno.land/install.sh \| sh` |
| No visualizer bars | Install cava: `sudo apt install cava` |
| Status line overflows | Resize your terminal wider (80+ columns recommended) |
| Track list shows "Track N" instead of titles | Titles load as mpv fetches each track; wait a moment |

## Uninstall

```bash
cd zsh-music-player
chmod +x uninstall.sh
./uninstall.sh
source ~/.zshrc
```

## Built with

- [mpv](https://github.com/mpv-player/mpv) - Media player
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - YouTube extractor
- [socat](http://www.dest-unreach.org/socat/) - IPC socket communication
- [jq](https://github.com/jqlang/jq) - JSON parsing
- [cava](https://github.com/karlstav/cava) - Audio visualizer (optional)

## License

MIT
