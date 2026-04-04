# --- ZSH MUSIC PLAYER ---
# Terminal YouTube music player with IPC controls, RGB bar visualizer, and track list
# Dependencies: mpv, yt-dlp, socat, jq
# Optional: cava (RGB bar visualizer), spotdl (Spotify support)

MUSIC_PLAYER_DIR="${0:A:h}"
MUSIC_PLAYLISTS_FILE="${MUSIC_PLAYER_DIR}/playlists.conf"

# ── Playlist loading ──────────────────────────────────────────────

_music_load_playlists() {
    declare -gA PLAYLISTS
    PLAYLISTS=()
    [[ ! -f "$MUSIC_PLAYLISTS_FILE" ]] && return
    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        key="${key## }"; key="${key%% }"
        val="${val## }"; val="${val%% }"
        PLAYLISTS[$key]="$val"
    done < "$MUSIC_PLAYLISTS_FILE"
}

_music_sanitize_name() {
    local name="$1"
    name="${name:l}"
    name="${name//á/a}"; name="${name//é/e}"
    name="${name//í/i}"; name="${name//ó/o}"
    name="${name//ú/u}"; name="${name//ñ/n}"
    name="${name//[^a-z0-9]/-}"
    name="${name//--/-}"
    name="${name#-}"; name="${name%-}"
    echo "$name"
}

# ── Platform detection & display ─────────────────────────────────

_music_detect_platform() {
    local url="$1"
    case "$url" in
        *youtube.com/*|*youtu.be/*)     echo "youtube" ;;
        *soundcloud.com/*)              echo "soundcloud" ;;
        *open.spotify.com/*|*spotify:*) echo "spotify" ;;
        *bandcamp.com/*)                echo "bandcamp" ;;
        *) echo "generic" ;;
    esac
}

_music_platform_icon() {
    case "$1" in
        youtube)    printf "\e[31m▶\e[0m" ;;
        soundcloud) printf "\e[38;5;208m☁\e[0m" ;;
        spotify)    printf "\e[32m●\e[0m" ;;
        bandcamp)   printf "\e[36m♦\e[0m" ;;
        *)          printf "\e[38;5;220m♪\e[0m" ;;
    esac
}

_music_platform_label() {
    case "$1" in
        youtube)    printf "\e[1;31mYouTube\e[0m" ;;
        soundcloud) printf "\e[1;38;5;208mSoundCloud\e[0m" ;;
        spotify)    printf "\e[1;32mSpotify\e[0m" ;;
        bandcamp)   printf "\e[1;36mBandcamp\e[0m" ;;
        *)          printf "\e[1;38;5;220mMusic\e[0m" ;;
    esac
}

# ── RGB Bar Visualizer ───────────────────────────────────────────

_music_bars_build() {
    local data="$1" max_val=$2 target_cols=$3
    local -a vals=("${(@s/;/)data}")
    local n=${#vals}
    local bar_rows=5
    local _e=$'\e' _n=$'\n'
    local -a blocks=("█" "▇" "▆" "▅" "▄" "▃" "▂" "▁")

    _VIS_FRAME=""
    _VIS_LINES=0
    (( n == 0 )) && return

    # Calculate how many display bars fit the terminal width
    # Each bar = 2 chars + 1 space = 3 chars, plus 2 indent
    local display_bars=$(( (target_cols - 4) / 3 ))
    (( display_bars < 4 )) && display_bars=4
    (( display_bars > 80 )) && display_bars=80

    # Group cava values into display_bars by averaging
    local -a disp_vals
    local di gs ge gi sum count
    for (( di = 1; di <= display_bars; di++ )); do
        sum=0; count=0
        gs=$(( (di - 1) * n / display_bars + 1 ))
        ge=$(( di * n / display_bars ))
        (( ge < gs )) && ge=$gs
        (( ge > n )) && ge=$n
        for (( gi = gs; gi <= ge; gi++ )); do
            (( sum += ${vals[$gi]:-0} ))
            (( count++ ))
        done
        disp_vals[$di]=$(( count > 0 ? sum / count : 0 ))
    done

    # RGB gradient: red -> yellow -> green -> cyan -> blue
    local -a _br _bg _bb
    local i t
    for (( i = 1; i <= display_bars; i++ )); do
        t=$(( ((i - 1) * 1020) / (display_bars > 1 ? display_bars - 1 : 1) ))
        if (( t <= 255 )); then
            _br[$i]=255; _bg[$i]=$t; _bb[$i]=30
        elif (( t <= 510 )); then
            _br[$i]=$(( 255 - (t - 255) )); _bg[$i]=255; _bb[$i]=30
        elif (( t <= 765 )); then
            _br[$i]=30; _bg[$i]=255; _bb[$i]=$(( t - 510 ))
        else
            _br[$i]=30; _bg[$i]=$(( 255 - (t - 765) )); _bb[$i]=255
        fi
    done

    # Map to sub-row heights (0..bar_rows*8)
    local -a _h
    for (( i = 1; i <= display_bars; i++ )); do
        _h[$i]=$(( (disp_vals[$i] * bar_rows * 8) / (max_val > 0 ? max_val : 1) ))
        (( _h[$i] > bar_rows * 8 )) && _h[$i]=$(( bar_rows * 8 ))
    done

    # Render bar rows (top to bottom)
    local row rb rt h ci
    for (( row = bar_rows; row >= 1; row-- )); do
        _VIS_FRAME+="  "
        rb=$(( (row - 1) * 8 )); rt=$(( row * 8 ))
        for (( i = 1; i <= display_bars; i++ )); do
            h=${_h[$i]}
            if (( h >= rt )); then
                _VIS_FRAME+="${_e}[38;2;${_br[$i]};${_bg[$i]};${_bb[$i]}m██"
            elif (( h > rb )); then
                ci=$(( 8 - (h - rb) ))
                (( ci > 7 )) && ci=7
                _VIS_FRAME+="${_e}[38;2;${_br[$i]};${_bg[$i]};${_bb[$i]}m${blocks[$((ci+1))]}${blocks[$((ci+1))]}"
            else
                _VIS_FRAME+="  "
            fi
            (( i < display_bars )) && _VIS_FRAME+=" "
        done
        _VIS_FRAME+="${_e}[0m${_e}[K${_n}"
        (( _VIS_LINES++ ))
    done

    # G────A frequency indicator (spans full visualizer width)
    local lw=$(( display_bars * 3 - 1 - 2 ))
    (( lw < 1 )) && lw=1
    local dashes=""
    for (( i = 0; i < lw; i++ )); do dashes+="─"; done
    _VIS_FRAME+="  ${_e}[1;38;5;208mG${_e}[0;38;5;240m${dashes}${_e}[1;38;5;39mA${_e}[0m${_e}[K${_n}"
    (( _VIS_LINES++ ))
}

# ── Fetch subcommand ──────────────────────────────────────────────

_music_fetch() {
    local source="$1"
    local platform="youtube"

    if [[ "$source" == http* ]]; then
        platform=$(_music_detect_platform "$source")
    fi

    case "$platform" in
        youtube)
            for dep in yt-dlp jq; do
                command -v $dep &>/dev/null || { echo "Error: $dep is not installed"; return 1; }
            done
            local channel_url
            if [[ "$source" == http* ]]; then
                channel_url="$source"
            else
                channel_url="https://www.youtube.com/@${source}/playlists"
            fi
            echo "Fetching playlists from $channel_url..."
            local tmpfile=$(mktemp)
            yt-dlp --flat-playlist -j "$channel_url" 2>/dev/null | jq -r '[.title, .url] | @tsv' > "$tmpfile"
            if [[ ! -s "$tmpfile" ]]; then
                echo "No public playlists found"
                rm -f "$tmpfile"; return 1
            fi
            echo "" >> "$MUSIC_PLAYLISTS_FILE"
            echo "# Playlists from ${source}" >> "$MUSIC_PLAYLISTS_FILE"
            _music_load_playlists
            local existing_urls=""
            for v in ${(v)PLAYLISTS}; do existing_urls+="$v"$'\n'; done
            local count=0 skipped=0
            while IFS=$'\t' read -r title url; do
                local key=$(_music_sanitize_name "$title")
                [[ -z "$key" || -z "$url" ]] && continue
                if echo "$existing_urls" | grep -qF "$url"; then
                    (( skipped++ )); continue
                fi
                echo "${key}=${url}" >> "$MUSIC_PLAYLISTS_FILE"
                (( count++ ))
            done < "$tmpfile"
            rm -f "$tmpfile"
            echo "Added $count new playlists ($skipped already existed)"
            ;;

        soundcloud)
            for dep in yt-dlp jq; do
                command -v $dep &>/dev/null || { echo "Error: $dep is not installed"; return 1; }
            done
            echo "Fetching SoundCloud playlists from $source..."
            local tmpfile=$(mktemp)
            yt-dlp --flat-playlist -j "$source" 2>/dev/null | jq -r '[.title, .url // .webpage_url] | @tsv' > "$tmpfile"
            if [[ ! -s "$tmpfile" ]]; then
                [[ "$source" != */sets* ]] && yt-dlp --flat-playlist -j "${source%/}/sets" 2>/dev/null | jq -r '[.title, .url // .webpage_url] | @tsv' > "$tmpfile"
            fi
            if [[ ! -s "$tmpfile" ]]; then
                echo "No playlists found at $source"
                rm -f "$tmpfile"; return 1
            fi
            echo "" >> "$MUSIC_PLAYLISTS_FILE"
            echo "# SoundCloud playlists from ${source}" >> "$MUSIC_PLAYLISTS_FILE"
            _music_load_playlists
            local existing_urls=""
            for v in ${(v)PLAYLISTS}; do existing_urls+="$v"$'\n'; done
            local count=0 skipped=0
            while IFS=$'\t' read -r title url; do
                local key=$(_music_sanitize_name "$title")
                [[ -z "$key" || -z "$url" ]] && continue
                if echo "$existing_urls" | grep -qF "$url"; then
                    (( skipped++ )); continue
                fi
                echo "${key}=${url}" >> "$MUSIC_PLAYLISTS_FILE"
                (( count++ ))
            done < "$tmpfile"
            rm -f "$tmpfile"
            echo "Added $count new playlists ($skipped already existed)"
            ;;

        spotify)
            if ! command -v spotdl &>/dev/null; then
                echo "Error: spotdl required for Spotify"
                echo "Install: pipx install spotdl"
                return 1
            fi
            echo "Resolving Spotify playlist via spotdl..."
            local spot_m3u="${MUSIC_PLAYER_DIR}/spotify-$(_music_sanitize_name "$source").m3u"
            spotdl url "$source" > "$spot_m3u" 2>/dev/null
            if [[ ! -s "$spot_m3u" ]]; then
                local spot_json=$(mktemp --suffix=.spotdl)
                spotdl save "$source" --save-file "$spot_json" 2>/dev/null
                if [[ -s "$spot_json" ]]; then
                    jq -r '.[] | "ytdl://ytsearch:\(.artists // [] | join(", ")) - \(.name)"' "$spot_json" > "$spot_m3u" 2>/dev/null
                fi
                rm -f "$spot_json"
            fi
            if [[ ! -s "$spot_m3u" ]]; then
                echo "Could not resolve Spotify playlist"
                rm -f "$spot_m3u"; return 1
            fi
            local key=$(_music_sanitize_name "spotify-$(basename "$source")")
            echo "" >> "$MUSIC_PLAYLISTS_FILE"
            echo "# Spotify playlist" >> "$MUSIC_PLAYLISTS_FILE"
            echo "${key}=${spot_m3u}" >> "$MUSIC_PLAYLISTS_FILE"
            local track_count=$(wc -l < "$spot_m3u")
            echo "Saved $track_count tracks as: music $key"
            ;;

        bandcamp)
            for dep in yt-dlp jq; do
                command -v $dep &>/dev/null || { echo "Error: $dep is not installed"; return 1; }
            done
            echo "Fetching Bandcamp album/playlist from $source..."
            local tmpfile=$(mktemp)
            yt-dlp --flat-playlist -j "$source" 2>/dev/null | jq -r '[.title, .url // .webpage_url] | @tsv' > "$tmpfile"
            if [[ ! -s "$tmpfile" ]]; then
                echo "No tracks found at $source"
                rm -f "$tmpfile"; return 1
            fi
            echo "" >> "$MUSIC_PLAYLISTS_FILE"
            echo "# Bandcamp: ${source}" >> "$MUSIC_PLAYLISTS_FILE"
            local key=$(_music_sanitize_name "$(echo "$source" | sed 's|.*://||;s|/.*||')")
            echo "${key}=${source}" >> "$MUSIC_PLAYLISTS_FILE"
            local track_count=$(wc -l < "$tmpfile")
            rm -f "$tmpfile"
            echo "Added Bandcamp album ($track_count tracks) as: music $key"
            ;;

        *)
            for dep in yt-dlp jq; do
                command -v $dep &>/dev/null || { echo "Error: $dep is not installed"; return 1; }
            done
            echo "Fetching playlist from $source (generic)..."
            local tmpfile=$(mktemp)
            yt-dlp --flat-playlist -j "$source" 2>/dev/null | jq -r '[.title, .url // .webpage_url] | @tsv' > "$tmpfile"
            if [[ ! -s "$tmpfile" ]]; then
                echo "Could not fetch playlist from $source"
                rm -f "$tmpfile"; return 1
            fi
            echo "" >> "$MUSIC_PLAYLISTS_FILE"
            echo "# Playlist from ${source}" >> "$MUSIC_PLAYLISTS_FILE"
            local key=$(_music_sanitize_name "$(echo "$source" | sed 's|.*://||;s|/.*||')")
            echo "${key}=${source}" >> "$MUSIC_PLAYLISTS_FILE"
            local track_count=$(wc -l < "$tmpfile")
            rm -f "$tmpfile"
            echo "Added playlist ($track_count tracks) as: music $key"
            ;;
    esac

    _music_load_playlists
    echo "\nAvailable playlists:"
    for key in ${(k)PLAYLISTS}; do
        local purl="${PLAYLISTS[$key]}"
        local picon=$(_music_platform_icon "$(_music_detect_platform "$purl")")
        echo "  ${picon} music $key"
    done
}

# ── Main command ──────────────────────────────────────────────────

music() {
    _music_load_playlists

    # ── fetch ──
    if [[ "$1" == "fetch" ]]; then
        if [[ -z "$2" ]]; then
            echo "Usage:"
            echo "  music fetch <youtube_username>"
            echo "  music fetch <youtube_playlist_url>"
            echo "  music fetch <soundcloud_url>"
            echo "  music fetch <spotify_playlist_url>"
            echo "  music fetch <bandcamp_url>"
            echo "  music fetch <any_url>  (yt-dlp generic)"
            return 1
        fi
        _music_fetch "$2"
        return $?
    fi

    # ── list / help ──
    if [[ -z "$1" ]]; then
        echo "Available playlists:"
        for key in ${(k)PLAYLISTS}; do
            local purl="${PLAYLISTS[$key]}"
            local picon=$(_music_platform_icon "$(_music_detect_platform "$purl")")
            echo "  ${picon} music $key"
        done
        echo "\nUsage:"
        echo "  music <playlist>       [--shuffle|-s] [--no-vis]"
        echo "  music <url>            play any URL directly"
        echo "  music fetch <source>   import playlists"
        echo "\nPlatforms: YouTube, SoundCloud, Bandcamp, Spotify (needs spotdl)"
        echo "\nControls:"
        echo "  space      pause/play       9/0   volume down/up"
        echo "  ↑/↓        prev/next track  ←/→   seek -5s/+5s"
        echo "  v          toggle visualizer"
        echo "  t          toggle track list"
        echo "  q          quit"
        return 0
    fi

    # ── dependency check ──
    for dep in mpv yt-dlp socat jq; do
        if ! command -v $dep &>/dev/null; then
            echo "Error: $dep is not installed"
            return 1
        fi
    done

    # ── parse args ──
    local shuffle="" name="" no_vis=0
    for arg in "$@"; do
        case "$arg" in
            --shuffle|-s) shuffle="--shuffle" ;;
            --no-vis)     no_vis=1 ;;
            *)            name="$arg" ;;
        esac
    done

    local url="${PLAYLISTS[$name]:-$name}"
    local platform=$(_music_detect_platform "$url")
    local icon=$(_music_platform_icon "$platform")
    local plat_label=$(_music_platform_label "$platform")
    local sock="/tmp/mpv-music-$$"
    local mpv_playlist_file=""

    # ── resolve Spotify URLs at play time ──
    if [[ "$platform" == "spotify" ]]; then
        if ! command -v spotdl &>/dev/null; then
            echo "Error: spotdl required for Spotify (pipx install spotdl)"
            return 1
        fi
        echo "Resolving Spotify tracks..."
        mpv_playlist_file="/tmp/spotdl-urls-$$"
        spotdl url "$url" > "$mpv_playlist_file" 2>/dev/null
        if [[ ! -s "$mpv_playlist_file" ]]; then
            echo "Could not resolve Spotify URL"
            rm -f "$mpv_playlist_file"; return 1
        fi
        echo "Resolved $(wc -l < "$mpv_playlist_file") tracks"
    fi

    # ── build mpv command ──
    local -a mpv_args=(
        --no-terminal --no-video --volume=100
        --input-ipc-server="$sock"
        --prefetch-playlist=yes
        --cache=yes
        --demuxer-max-bytes=50MiB
        --ytdl-raw-options=format="ba/b",extractor-args="youtube:player_client=android_music"
    )
    [[ -n "$shuffle" ]] && mpv_args+=("$shuffle")

    if [[ -n "$mpv_playlist_file" ]]; then
        mpv_args+=("--playlist=$mpv_playlist_file")
    elif [[ -f "$url" ]]; then
        mpv_args+=("--playlist=$url")
    else
        mpv_args+=("$url")
    fi

    mpv "${mpv_args[@]}" &
    local mpv_pid=$!

    # Wait for IPC socket
    for i in {1..30}; do
        [[ -S "$sock" ]] && break
        sleep 0.2
    done
    if [[ ! -S "$sock" ]]; then
        echo "Error: mpv failed to start"
        kill $mpv_pid 2>/dev/null
        rm -f "$mpv_playlist_file"
        return 1
    fi

    _mpv_get() {
        echo "{\"command\":[\"get_property\",\"$1\"]}" | socat - "$sock" 2>/dev/null | jq -r '.data // empty' 2>/dev/null
    }
    _mpv_cmd() {
        echo "{\"command\":$1}" | socat - "$sock" 2>/dev/null >/dev/null
    }

    # ── cava setup for bar visualizer ──
    local cava_pid=0
    local cava_fifo="/tmp/cava-music-$$"
    local cava_conf="/tmp/cava-conf-$$"
    local vis_enabled=0
    local cava_bars=64

    if (( ! no_vis )) && command -v cava &>/dev/null; then
        vis_enabled=1
        mkfifo "$cava_fifo" 2>/dev/null

        cat > "$cava_conf" << CAVAEOF
[general]
bars = $cava_bars
framerate = 30
sensitivity = 120
autosens = 1

[output]
method = raw
raw_target = $cava_fifo
data_format = ascii
ascii_max_range = 50
bar_delimiter = 59
frame_delimiter = 10
CAVAEOF

        cava -p "$cava_conf" &>/dev/null &
        cava_pid=$!
        exec 3<>"$cava_fifo"
    elif (( ! no_vis )); then
        echo "(install cava for RGB bar visualizer: sudo apt install cava)"
        sleep 1
    fi

    # ── render state ──
    local _VIS_FRAME="" _VIS_LINES=0

    # ── track list state ──
    local tracklist_open=0
    local -a _tl_titles=()
    local _tl_count=0
    local _tl_pos=-1
    local _tl_last_refresh=-1

    _music_tl_refresh() {
        local raw=$(echo '{"command":["get_property","playlist"]}' | socat - "$sock" 2>/dev/null)
        _tl_count=$(echo "$raw" | jq '.data | length' 2>/dev/null)
        [[ "$_tl_count" == "null" || -z "$_tl_count" ]] && _tl_count=0
        (( _tl_count == 0 )) && return
        _tl_titles=()
        local _line _idx=1
        while IFS= read -r _line; do
            [[ -n "$_line" ]] && _tl_titles[$_idx]="$_line"
            (( _idx++ ))
        done <<< "$(echo "$raw" | jq -r '.data | to_entries[] | .value.title // "Track \(.key + 1)"' 2>/dev/null)"
    }

    # ── cleanup ──
    _music_cleanup() {
        printf "\e[?1049l\e[?25h"  # restore original screen
        if (( cava_pid > 0 )); then
            kill $cava_pid 2>/dev/null
            wait $cava_pid 2>/dev/null
            exec 3<&- 2>/dev/null
        fi
        kill $mpv_pid 2>/dev/null
        rm -f "$sock" "$cava_fifo" "$cava_conf" "$mpv_playlist_file"
        stty sane 2>/dev/null
    }

    trap "_music_cleanup; trap - INT; return" INT

    # ── colors ──
    local _e=$'\e' _n=$'\n'
    local purple="${_e}[38;5;141m" cyan="${_e}[38;5;51m"
    local white="${_e}[38;5;255m"  magenta="${_e}[38;5;201m"
    local dim="${_e}[38;5;240m"    reset="${_e}[0m"
    local bold_purple="${_e}[1;38;5;141m"
    local clr="${_e}[K"
    local paused=0 bar_size=20
    local frame_n=0
    local last_title="" last_vol="" cava_data=""

    printf "\e[?1049h\e[?25l\e[H"  # alternate screen, hide cursor, home

    # ── main loop ──
    while kill -0 $mpv_pid 2>/dev/null; do

        # Drain cava FIFO, keep latest frame
        if (( vis_enabled && cava_pid > 0 )); then
            local _cline=""
            while read -t 0.005 -u 3 _cline 2>/dev/null; do
                cava_data="$_cline"
            done
        fi

        # Query mpv (title/vol less often)
        if (( frame_n % 8 == 0 )); then
            last_title=$(_mpv_get media-title)
            last_vol=$(_mpv_get volume)
        fi
        local pos=$(_mpv_get time-pos)
        local dur=$(_mpv_get duration)

        # Track playlist position for track list
        local cur_pl_pos=""
        if (( tracklist_open || frame_n % 16 == 0 )); then
            cur_pl_pos=$(_mpv_get playlist-pos)
        fi

        # Refresh track list data when needed
        if (( tracklist_open )); then
            if [[ -n "$cur_pl_pos" && "$cur_pl_pos" != "$_tl_pos" ]] || (( _tl_last_refresh < 0 )) || (( frame_n % 60 == 0 )); then
                _music_tl_refresh
                _tl_last_refresh=$frame_n
            fi
            [[ -n "$cur_pl_pos" ]] && _tl_pos=$cur_pl_pos
        fi

        # Format times
        local pos_fmt="--:--" dur_fmt="--:--"
        if [[ -n "$pos" ]]; then
            pos_fmt=$(printf "%02d:%02d" $((${pos%.*} / 60)) $((${pos%.*} % 60)))
        fi
        if [[ -n "$dur" ]]; then
            dur_fmt=$(printf "%02d:%02d" $((${dur%.*} / 60)) $((${dur%.*} % 60)))
        fi

        # Progress bar
        local bar=""
        if [[ -n "$pos" && -n "$dur" ]]; then
            local pos_s=${pos%.*} dur_s=${dur%.*}
            if (( dur_s > 0 )); then
                local filled=$(( (pos_s * bar_size) / dur_s ))
                local empty_b=$(( bar_size - filled ))
                bar="${magenta}"
                for ((b=0; b<filled; b++)); do bar+="━"; done
                bar+="${dim}"
                for ((b=0; b<empty_b; b++)); do bar+="━"; done
                bar+="${reset}"
            fi
        fi
        if [[ -z "$bar" ]]; then
            bar="${dim}"
            for ((b=0; b<bar_size; b++)); do bar+="━"; done
            bar+="${reset}"
        fi

        local vol_int=${last_vol%.*}
        local pause_icon=""; (( paused )) && pause_icon=" ${_e}[33m⏸${reset}"

        # Terminal width
        local cols=$(tput cols 2>/dev/null || echo 80)

        # Calculate available space for title
        local fixed_len=$(( 12 + ${#name} + 2 + 8 + ${#vol_int} + 4 + ${#pos_fmt} + 1 + bar_size + 1 + ${#dur_fmt} + 4 ))
        local max_title=$(( cols - fixed_len ))
        local disp_title="${last_title:-...}"
        if (( max_title < 4 )); then
            disp_title=""
        elif (( ${#disp_title} > max_title )); then
            disp_title="${disp_title:0:$((max_title-3))}..."
        fi

        # ═══ BUILD FRAME ═══
        local frame=""

        # ── Track list section ──
        if (( tracklist_open && _tl_count > 0 )); then
            local tl_cur=${_tl_pos:-0}

            local tl_start=$tl_cur
            if (( tl_cur > 0 )); then
                tl_start=$(( tl_cur - 3 ))
                (( tl_start < 0 )) && tl_start=0
            fi

            local tl_end=$tl_cur
            if (( tl_cur < _tl_count - 1 )); then
                tl_end=$(( tl_cur + 3 ))
                (( tl_end >= _tl_count )) && tl_end=$(( _tl_count - 1 ))
            fi

            local tl_i tl_title tl_num tl_max=$(( cols - 12 ))
            for (( tl_i = tl_start; tl_i <= tl_end; tl_i++ )); do
                tl_title="${_tl_titles[$((tl_i+1))]:-Track $((tl_i+1))}"
                if (( ${#tl_title} > tl_max )); then
                    tl_title="${tl_title:0:$((tl_max-3))}..."
                fi
                if (( tl_i == tl_cur )); then
                    frame+="  ${bold_purple}${_e}[7m ► ${tl_title} ◄ ${_e}[27m${reset}${clr}${_n}"
                else
                    tl_num=$(( tl_i + 1 ))
                    frame+="  ${dim}   ${tl_num}. ${tl_title}${reset}${clr}${_n}"
                fi
            done
        fi

        # ── Visualizer section ──
        if (( vis_enabled )); then
            local vis_data="$cava_data"
            if [[ -z "$vis_data" ]]; then
                vis_data="2"
                local _vi
                for (( _vi = 1; _vi < cava_bars; _vi++ )); do vis_data+=";2"; done
            fi
            _music_bars_build "$vis_data" 50 $cols
            frame+="$_VIS_FRAME"
        fi

        # ── Status line ──
        frame+="${icon} ${plat_label} ${dim}·${reset} ${white}${name}${pause_icon}${reset}  ${purple}${disp_title}${reset}  ${cyan}Vol: ${vol_int:-100}%${reset}  ${white}${pos_fmt} ${bar} ${dur_fmt}${reset}${clr}"

        # ═══ RENDER FRAME ═══
        printf "\e[H"          # cursor home (top-left)
        printf "%s" "$frame"
        printf "\e[J"          # clear everything below

        # ── input ──
        local key=""
        if (( vis_enabled || tracklist_open )); then
            read -sk1 -t0.04 key 2>/dev/null
        else
            read -sk1 -t1 key 2>/dev/null
        fi

        case "$key" in
            -)  _mpv_cmd '["add","volume",-5]' ;;
            +)  _mpv_cmd '["add","volume",5]' ;;
            " ") _mpv_cmd '["cycle","pause"]'; (( paused = !paused )) ;;
            v)  # Toggle visualizer
                if (( vis_enabled )); then
                    vis_enabled=0
                    if (( cava_pid > 0 )); then
                        kill $cava_pid 2>/dev/null
                        wait $cava_pid 2>/dev/null
                        exec 3<&- 2>/dev/null
                        cava_pid=0
                    fi
                    cava_data=""
                elif command -v cava &>/dev/null; then
                    vis_enabled=1
                    rm -f "$cava_fifo"
                    mkfifo "$cava_fifo" 2>/dev/null
                    cava -p "$cava_conf" &>/dev/null &
                    cava_pid=$!
                    exec 3<>"$cava_fifo"
                    cava_data=""
                fi
                ;;
            t)  # Toggle track list
                if (( tracklist_open )); then
                    tracklist_open=0
                else
                    tracklist_open=1
                    _tl_last_refresh=-1
                    _tl_pos=$(_mpv_get playlist-pos)
                fi
                ;;
            q)  kill $mpv_pid 2>/dev/null; break ;;
            $'\e')
                local seq=""
                read -sk2 -t0.1 seq 2>/dev/null
                case "$seq" in
                    "[A") _mpv_cmd '["playlist-prev"]' ;;
                    "[B") _mpv_cmd '["playlist-next"]' ;;
                    "[C") _mpv_cmd '["seek",5]' ;;
                    "[D") _mpv_cmd '["seek",-5]' ;;
                esac
                ;;
        esac

        (( frame_n++ ))
    done

    _music_cleanup
    trap - INT
}
