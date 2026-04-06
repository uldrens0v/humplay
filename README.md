# humplay

A terminal music player for YouTube playlists with an RGB bar visualizer and track list. No ads, no browser, just music.

Built with `mpv` + `yt-dlp` and controlled via IPC socket from your terminal.

![shell](https://img.shields.io/badge/shell-zsh-blue)
![license](https://img.shields.io/badge/license-MIT-green)

## Preview

![preview](screenshots/preview.png)

## Features

- Play YouTube playlists directly from the terminal
- No ads (bypasses YouTube web player via yt-dlp)
- **2 visualizer styles** cycled with `v`: bars and braille — both adapting to terminal width with a G (bass) to A (treble) frequency indicator
- **Isolated visualizer**: reacts only to the player's audio, not system-wide sound (via PulseAudio)
- **Track list overlay** (press `t`) showing 2 previous and 2 upcoming songs with real-time updates
- **Responsive layout**: on small terminals, the visualizer auto-shrinks or hides so the track list / search results are never clipped
- **Track search** (press `f`) — find tracks by name within the current playlist, with instant prefetch of highlighted results
- **Theme system**: 14 color themes loaded from JSON files — set permanently, cycle live, or create your own
- **Playback speed** control (press `s`) — cycles through 1x, 1.25x, 1.5x, 2x, 3x with themed arrow indicators
- **Track prefetch**: resolves and pre-downloads the next 3 tracks in background to reduce song change delay
- **Platform logo** next to playlist name (YouTube, SoundCloud, Spotify, Bandcamp)
- **Fetch playlists** from a YouTube channel by username or profile URL
- Full-screen alternate buffer rendering (no terminal scroll pollution)
- Keyboard controls (volume, seek, next/prev, pause)
- Multi-platform support: YouTube, SoundCloud, Bandcamp, Spotify
- Custom playlist aliases via config file
- Shuffle mode
- Clean audio startup/shutdown (no pops or crackles between sessions)

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
| [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/) | Isolated visualizer (reacts only to player audio) |
| [spotdl](https://github.com/spotDL/spotify-downloader) | Spotify playlist support |

### Install dependencies

<details>
<summary><b>Debian / Ubuntu</b></summary>

```bash
# Required
sudo apt install mpv socat jq

# Optional: RGB bar visualizer
sudo apt install cava

# PulseAudio is usually installed by default
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

> **Note:** The isolated visualizer feature requires PulseAudio (`pactl`), which is Linux-only. On macOS, the visualizer will react to all system audio.
</details>

<details>
<summary><b>Windows (via WSL)</b></summary>

Windows is supported through WSL (Windows Subsystem for Linux). Native Windows is not supported.

```bash
# 1. Install WSL (PowerShell as admin)
wsl --install

# 2. Inside WSL (Ubuntu), install dependencies
sudo apt install mpv socat jq cava

# 3. For audio to work, install PulseAudio on Windows
#    and set PULSE_SERVER in WSL:
export PULSE_SERVER=tcp:$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
```

> **Note:** WSL audio setup requires extra configuration. See [WSL audio guide](https://learn.microsoft.com/en-us/windows/wsl/) for details. For the simplest experience, use Linux or macOS.
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
git clone https://github.com/uldrens0v/humplay.git
cd humplay
chmod +x install.sh
./install.sh
source ~/.zshrc
```

## Configure playlists

Edit `~/.humplay/playlists.conf`:

```conf
# Format: name=URL
lofi=https://www.youtube.com/playlist?list=PLofht4PTcKYnaH8w5olJCI-wUVxuoMHqM
rock=https://www.youtube.com/playlist?list=PLxxxxxxx

# SoundCloud
sc=https://soundcloud.com/artist-name

# Bandcamp (format: artist.bandcamp.com/album/name)
bc=https://c418.bandcamp.com/album/minecraft-volume-alpha

# Spotify (requires spotdl)
chill-spotify=https://open.spotify.com/playlist/37i9dQZF1DX4WYpdgoIcn6
```

Or fetch playlists automatically from a YouTube channel (by name or URL):

```bash
humplay fetch uldrens0v
humplay fetch https://youtube.com/@uldrens0v
```

## Usage

```bash
humplay                        # list available playlists
humplay lofi                   # play a playlist
humplay lofi -s                # play shuffled
humplay lofi --no-vis          # play without visualizer
humplay lofi --theme=winter    # play with a specific theme
humplay "URL"                  # play any URL directly
humplay fetch <source>         # import playlists from a channel/URL
humplay --theme                # show available themes
humplay --theme autumn         # set default theme permanently
```

## Themes

14 built-in color themes with distinct gradients for the visualizer and UI:

| Theme | Style |
|-------|-------|
| `summer` | Warm yellows and oranges (default) |
| `autumn` | Deep amber and brown tones |
| `winter` | Cool blues and whites |
| `spring` | Fresh greens and pinks |
| `ocean` | Deep teal and aquamarine |
| `neon` | Electric magenta, cyan and yellow |
| `sakura` | Soft pinks and cherry blossom |
| `ember` | Intense reds and fire tones |
| `cyber` | Matrix-style bright greens |
| `midnight` | Deep purples and indigo |
| `vapor` | Vaporwave pink, blue and peach |
| `arctic` | Icy whites and pale blues |
| `dracula` | Classic Dracula palette (purple, pink, green) |
| `mono` | Monochrome grayscale |

Set a persistent theme: `humplay --theme winter`

Cycle themes live during playback: press `c`

### Custom themes

Themes are JSON files in the `themes/` directory. To create your own, add a `.json` file:

```json
{
  "name": "mytheme",
  "description": "Short description of the palette",
  "colors": {
    "primary": [255, 200, 50],
    "secondary": [255, 150, 50],
    "accent": [255, 100, 80],
    "dim": [180, 140, 60],
    "highlight": [255, 220, 80],
    "bar": [255, 140, 50],
    "bar_dim": [120, 90, 30]
  },
  "visualizer": {
    "stops": [
      [255, 220, 50],
      [255, 150, 30],
      [255, 80, 30],
      [255, 50, 100],
      [200, 30, 150]
    ]
  }
}
```

| Field | Description |
|-------|-------------|
| `primary` | Main text color (track title, labels) |
| `secondary` | Secondary text (artist, status info) |
| `accent` | Emphasis elements (active indicators) |
| `dim` | Muted text (timestamps, inactive items) |
| `highlight` | Bold highlights (current track marker) |
| `bar` | Progress bar fill color |
| `bar_dim` | Progress bar background color |
| `visualizer.stops` | 5 RGB gradient stops for the frequency bars (low to high) |

Save the file as `themes/mytheme.json` and it will appear automatically in `humplay --theme`.

## Controls

| Key | Action |
|-----|--------|
| `space` | pause / play |
| `-` / `+` | volume down / up (5%) |
| `↑` / `↓` | previous / next track |
| `←` / `→` | seek -5s / +5s |
| `s` | cycle playback speed (1x → 1.25x → 1.5x → 2x → 3x) |
| `v` | cycle visualizer style (bars → braille → off) |
| `t` | toggle track list |
| `f` | search tracks in playlist |
| `c` | cycle color theme |
| `q` | quit (graceful shutdown) |

### Search mode

Press `f` to enter search mode. Type to filter tracks by name:

- `↑` / `↓` — navigate results
- `Enter` — jump to the selected track
- `Esc` — cancel search
- `Backspace` — delete last character

Up to 8 matching results are displayed. The search closes the track list if it was open.

**Instant prefetch**: as soon as a result is highlighted (by typing or by navigating with arrows), the player resolves its URL and warms the CDN cache in the background. If you pause on a result for a second before pressing Enter, the jump is near-instant instead of waiting for yt-dlp resolution.

## Visualizer

When `cava` is installed, the player displays a frequency visualizer that **adapts to your terminal width**. Each column is colored in a theme-aware gradient, with a **G** (bass, Grave) to **A** (treble, Agudo) indicator underneath.

Press `v` during playback to cycle through 2 styles:

### 1. Bars (default)

Classic vertical RGB bars. Each bar is 2 characters wide with a smooth 5-stop theme gradient from low to high frequencies.

```
  ██                    ██            ██
  ██ ██          ██     ██      ██    ██ ██
  ██ ██ ██    ██ ██  ██ ██ ██   ██    ██ ██
  ██ ██ ██ ██ ██ ██  ██ ██ ██   ██ ██ ██ ██ ██
  ██ ██ ██ ██ ██ ██  ██ ██ ██ ██ ██ ██ ██ ██ ██
  G────────────────────────────────────────────A
```

### 2. Braille

Uses Unicode braille characters to pack **2 bars per character** with **4 sub-pixels per row**, for a higher-resolution, finer-grained look at the same terminal width.

```
  ⣿ ⣶ ⣤ ⣀ ⣦ ⣿ ⣶ ⣤ ⣀ ⣴ ⣿ ⣦ ⣀
  G──────────────────────────A
```

Cava runs continuously in the background during a session, so toggling between styles (or cycling on/off) is instant with no calibration delay.

### Isolated audio

When PulseAudio is available (`pactl`), the visualizer reacts **only to the player's audio**, ignoring other system sounds (browser, notifications, etc.). This is done automatically by routing mpv through a dedicated PulseAudio sink. The sink is created on start and cleaned up on exit.

If PulseAudio is not available, the visualizer falls back to monitoring all system audio.

Start without the visualizer: `humplay <playlist> --no-vis`

## Track List

Press `t` during playback to open the track list overlay:

```
     4. Previous Song
     5. One More Song
   ► 6. Currently Playing ◄
     7. Next Song
     8. After That
```

- Shows up to 2 previous and 2 next tracks around the current one
- If the current song is the **first**, no previous tracks are shown
- If the current song is the **last**, no next tracks are shown
- Current track is highlighted with reverse video
- Updates in real-time when the track changes
- Press `t` again to close

## Multi-platform support

| Platform | URL format | Requirements |
|----------|-----------|--------------|
| YouTube | `youtube.com/playlist?list=...` | yt-dlp |
| SoundCloud | `soundcloud.com/artist` or `.../sets/playlist` | yt-dlp |
| Bandcamp | `artist.bandcamp.com/album/name` | yt-dlp |
| Spotify | `open.spotify.com/playlist/...` | spotdl (`pipx install spotdl`) |

Import playlists from any supported platform:

```bash
humplay fetch https://soundcloud.com/artist/sets/playlist
humplay fetch https://artist.bandcamp.com/album/name
humplay fetch https://open.spotify.com/playlist/xxxxx
```

## How it works

1. Cleans up any orphaned processes/sinks from previous sessions
2. Creates an isolated PulseAudio null-sink (if available) so the visualizer only reacts to player audio
3. Launches `mpv` paused at volume 0, routed to the null-sink, with IPC socket
4. After IPC is ready, creates the PulseAudio loopback (null-sink → speakers) and fades in
5. Opens an alternate screen buffer for clean full-screen rendering
6. `cava` monitors the null-sink and sends frequency data through a FIFO pipe
7. Prefetches the next 3 tracks in background (URL resolution + partial download) to reduce gaps
8. A zsh loop queries mpv properties (title, volume, position, playlist) via the socket using `socat`
9. Renders a multi-line display (track list + visualizer + status bar) from a fixed top position using ANSI escape codes
10. Reads keyboard input with `read -sk1` and sends commands back to mpv via IPC
11. On exit: disconnects loopback first (silences speakers), then gracefully quits mpv, then removes the null-sink

## Platform compatibility

| OS | Status | Notes |
|----|--------|-------|
| **Linux** | Full support | All features including isolated visualizer |
| **macOS** | Supported | Visualizer reacts to all system audio (no PulseAudio) |
| **Windows** | WSL only | Requires WSL + extra audio configuration. Native Windows is not supported |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Error: yt-dlp is not installed` | Install yt-dlp with the curl command above |
| No audio / format not available | Update yt-dlp to the latest version |
| No supported JavaScript runtime | Install deno: `curl -fsSL https://deno.land/install.sh \| sh` |
| No visualizer bars | Install cava: `sudo apt install cava` |
| Visualizer reacts to all system audio | Install PulseAudio (usually pre-installed on Linux) |
| Status line overflows | Resize your terminal wider (80+ columns recommended) |
| Track list shows "Track N" instead of titles | Titles load as mpv fetches each track; wait a moment |
| Bandcamp URL not working | Use format `artist.bandcamp.com/album/name`, not `bandcamp.com/...` |

## Uninstall

```bash
cd humplay
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
