# zsh-music-player

A minimal terminal music player for YouTube playlists. No ads, no browser, just music.

Built with `mpv` + `yt-dlp` and controlled via IPC socket from your terminal.

![shell](https://img.shields.io/badge/shell-zsh-blue)
![license](https://img.shields.io/badge/license-MIT-green)

## Preview

![preview](screenshots/preview.png)

```
♪ chill       S I C K       Vol: 40%      00:00 ━━━━━━━━━━━━━━━━━━━━ 05:32
↓                ↓              ↓              ↓              ↓           ↓
playlist name    track title    volume level   position       progress    duration
```

## Features

- Play YouTube playlists directly from the terminal
- No ads (bypasses YouTube web player via yt-dlp)
- Colored single-line status with progress bar
- Keyboard controls (volume, seek, next/prev, pause)
- Custom playlist aliases via config file
- Shuffle mode

## Dependencies

<details>
<summary><b>Debian / Ubuntu</b></summary>

```bash
sudo apt install mpv socat jq
```
</details>

<details>
<summary><b>Arch Linux</b></summary>

```bash
sudo pacman -S mpv socat jq
```
</details>

<details>
<summary><b>Fedora</b></summary>

```bash
sudo dnf install mpv socat jq
```
</details>

<details>
<summary><b>macOS</b></summary>

```bash
brew install mpv socat jq
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

Then:

```bash
music lofi
```

## Usage

```bash
music              # list available playlists
music lofi         # play a playlist
music lofi -s      # play shuffled
music "URL"        # play any YouTube URL directly
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

| Problem | Solution |
|---------|----------|
| `Error: yt-dlp is not installed` | Install yt-dlp with the curl command above |
| No audio / format not available | Update yt-dlp to the latest version |
| No supported JavaScript runtime | Install deno: `curl -fsSL https://deno.land/install.sh \| sh` |
| Status line overflows | Resize your terminal wider |

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

## License

MIT
