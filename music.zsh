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

# ── Theme System ─────────────────────────────────────────────────

MUSIC_THEMES_DIR="${MUSIC_PLAYER_DIR}/themes"

_music_load_themes() {
    typeset -ga _music_themes=()
    local _tf
    for _tf in "${MUSIC_THEMES_DIR}"/*.json(N); do
        local _tn=$(jq -r '.name // empty' "$_tf" 2>/dev/null)
        [[ -n "$_tn" ]] && _music_themes+=("$_tn")
    done
    (( ${#_music_themes[@]} == 0 )) && _music_themes=(summer)
}

_music_set_theme() {
    local theme="${1:-summer}"
    typeset -g _th_name="$theme"
    local _e=$'\e'
    typeset -g _th_reset="${_e}[0m"

    local _tf="${MUSIC_THEMES_DIR}/${theme}.json"
    if [[ -f "$_tf" ]]; then
        local _j
        _j=$(< "$_tf")
        local _r _g _b

        _r=$(echo "$_j" | jq '.colors.primary[0]') _g=$(echo "$_j" | jq '.colors.primary[1]') _b=$(echo "$_j" | jq '.colors.primary[2]')
        typeset -g _th_primary="${_e}[38;2;${_r};${_g};${_b}m"
        _r=$(echo "$_j" | jq '.colors.secondary[0]') _g=$(echo "$_j" | jq '.colors.secondary[1]') _b=$(echo "$_j" | jq '.colors.secondary[2]')
        typeset -g _th_secondary="${_e}[38;2;${_r};${_g};${_b}m"
        _r=$(echo "$_j" | jq '.colors.accent[0]') _g=$(echo "$_j" | jq '.colors.accent[1]') _b=$(echo "$_j" | jq '.colors.accent[2]')
        typeset -g _th_accent="${_e}[38;2;${_r};${_g};${_b}m"
        _r=$(echo "$_j" | jq '.colors.dim[0]') _g=$(echo "$_j" | jq '.colors.dim[1]') _b=$(echo "$_j" | jq '.colors.dim[2]')
        typeset -g _th_dim="${_e}[38;2;${_r};${_g};${_b}m"
        _r=$(echo "$_j" | jq '.colors.highlight[0]') _g=$(echo "$_j" | jq '.colors.highlight[1]') _b=$(echo "$_j" | jq '.colors.highlight[2]')
        typeset -g _th_highlight="${_e}[1;38;2;${_r};${_g};${_b}m"
        _r=$(echo "$_j" | jq '.colors.bar[0]') _g=$(echo "$_j" | jq '.colors.bar[1]') _b=$(echo "$_j" | jq '.colors.bar[2]')
        typeset -g _th_bar="${_e}[38;2;${_r};${_g};${_b}m"
        _r=$(echo "$_j" | jq '.colors.bar_dim[0]') _g=$(echo "$_j" | jq '.colors.bar_dim[1]') _b=$(echo "$_j" | jq '.colors.bar_dim[2]')
        typeset -g _th_bar_dim="${_e}[38;2;${_r};${_g};${_b}m"

        typeset -ga _th_vr=( $(echo "$_j" | jq -r '.visualizer.stops | map(.[0]) | join(" ")') )
        typeset -ga _th_vg=( $(echo "$_j" | jq -r '.visualizer.stops | map(.[1]) | join(" ")') )
        typeset -ga _th_vb=( $(echo "$_j" | jq -r '.visualizer.stops | map(.[2]) | join(" ")') )
    else
        # Fallback to summer if JSON not found
        typeset -g _th_primary="${_e}[38;2;255;200;50m"
        typeset -g _th_secondary="${_e}[38;2;255;150;50m"
        typeset -g _th_accent="${_e}[38;2;255;100;80m"
        typeset -g _th_dim="${_e}[38;2;180;140;60m"
        typeset -g _th_highlight="${_e}[1;38;2;255;220;80m"
        typeset -g _th_bar="${_e}[38;2;255;140;50m"
        typeset -g _th_bar_dim="${_e}[38;2;120;90;30m"
        typeset -ga _th_vr=(255 255 255 255 200)
        typeset -ga _th_vg=(220 150 80 50 30)
        typeset -ga _th_vb=(50 30 30 100 150)
    fi
}

# ── RGB Bar Visualizer ───────────────────────────────────────────

_music_bars_build() {
    local data="$1" max_val=$2 target_cols=$3 bar_rows=${4:-5}
    local -a vals=("${(@s/;/)data}")
    local n=${#vals}
    local _e=$'\e' _n=$'\n'
    local -a blocks=("█" "▇" "▆" "▅" "▄" "▃" "▂" "▁")

    _VIS_FRAME=""
    _VIS_LINES=0
    (( n == 0 )) && return

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

    # Theme-aware gradient with 5 color stops
    local -a _br _bg _bb
    local i t seg frac stops=5
    for (( i = 1; i <= display_bars; i++ )); do
        t=$(( ((i - 1) * (stops - 1) * 256) / (display_bars > 1 ? display_bars - 1 : 1) ))
        seg=$(( t / 256 ))
        (( seg >= stops - 1 )) && seg=$(( stops - 2 ))
        frac=$(( t - seg * 256 ))
        local s1=$(( seg + 1 )) s2=$(( seg + 2 ))
        _br[$i]=$(( (_th_vr[$s1] * (256 - frac) + _th_vr[$s2] * frac) / 256 ))
        _bg[$i]=$(( (_th_vg[$s1] * (256 - frac) + _th_vg[$s2] * frac) / 256 ))
        _bb[$i]=$(( (_th_vb[$s1] * (256 - frac) + _th_vb[$s2] * frac) / 256 ))
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

    # G────A frequency indicator
    local lw=$(( display_bars * 3 - 1 - 2 ))
    (( lw < 1 )) && lw=1
    local dashes=""
    for (( i = 0; i < lw; i++ )); do dashes+="─"; done
    _VIS_FRAME+="  ${_th_accent}G${_th_dim}${dashes}${_th_primary}A${_e}[0m${_e}[K${_n}"
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
                # Ensure YouTube profile URLs end in /playlists
                channel_url="${source%/}"
                if [[ "$channel_url" == *youtube.com/@* && "$channel_url" != */playlists ]]; then
                    channel_url="${channel_url}/playlists"
                fi
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
    _music_load_themes

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
        # Group playlists by platform
        local -A _plat_lists
        local _pkey _purl _pplat
        for _pkey in ${(k)PLAYLISTS}; do
            _purl="${PLAYLISTS[$_pkey]}"
            _pplat=$(_music_detect_platform "$_purl")
            _plat_lists[$_pplat]+="${_pkey}"$'\n'
        done
        local _plat_order=(youtube soundcloud bandcamp spotify generic)
        local _shown=0
        for _pplat in "${_plat_order[@]}"; do
            [[ -z "${_plat_lists[$_pplat]}" ]] && continue
            local _plabel=$(_music_platform_label "$_pplat")
            local _picon=$(_music_platform_icon "$_pplat")
            echo "\n  ${_picon} ${_plabel}"
            while IFS= read -r _pkey; do
                [[ -z "$_pkey" ]] && continue
                echo "     music ${_pkey}"
            done <<< "${_plat_lists[$_pplat]}"
            (( _shown++ ))
        done
        (( _shown == 0 )) && echo "  No playlists configured. See: music fetch <source>"
        echo "\nUsage:"
        echo "  music <playlist>       [--shuffle|-s] [--no-vis] [--theme=THEME]"
        echo "  music <url>            play any URL directly"
        echo "  music fetch <source>   import playlists"
        echo "\nThemes: ${_music_themes[*]}"
        echo "\nPlatforms: YouTube, SoundCloud, Bandcamp, Spotify (needs spotdl)"
        echo "\nControls:"
        echo "  space      pause/play       -/+   volume down/up"
        echo "  ↑/↓        prev/next track  ←/→   seek -5s/+5s"
        echo "  v          toggle visualizer s     cycle speed (1x-3x)"
        echo "  t          toggle track list f     search tracks"
        echo "  c          cycle color theme"
        echo "  q          quit"
        return 0
    fi

    # ── dependency check ──
    local _pkg_mgr=""
    if command -v apt &>/dev/null; then _pkg_mgr="sudo apt install"
    elif command -v pacman &>/dev/null; then _pkg_mgr="sudo pacman -S"
    elif command -v dnf &>/dev/null; then _pkg_mgr="sudo dnf install"
    elif command -v brew &>/dev/null; then _pkg_mgr="brew install"
    fi
    local _missing=()
    for dep in mpv yt-dlp socat jq; do
        command -v $dep &>/dev/null || _missing+=($dep)
    done
    if (( ${#_missing[@]} > 0 )); then
        echo "Missing dependencies: ${_missing[*]}"
        if [[ -n "$_pkg_mgr" ]]; then
            echo "Install with:  $_pkg_mgr ${_missing[*]}"
        fi
        return 1
    fi

    # ── --theme without value: show themes and return ──
    local _only_theme=0
    if [[ "$1" == "--theme" && ( -z "$2" || "$2" == --* ) ]]; then
        _only_theme=1
    fi
    # --theme <name> as two separate args (not playing, just setting)
    if [[ "$1" == "--theme" && -n "$2" && "$2" != --* && -z "$3" ]]; then
        local _valid=0
        for _t in "${_music_themes[@]}"; do
            [[ "$_t" == "$2" ]] && _valid=1
        done
        if (( _valid )); then
            echo "$2" > "${MUSIC_PLAYER_DIR}/.theme"
            echo "Theme set: $2"
        else
            echo "Unknown theme '$2'."
            echo "Available themes: ${_music_themes[*]}"
        fi
        return 0
    fi
    if (( _only_theme )); then
        echo "Available themes:"
        local _saved_theme=""
        [[ -f "${MUSIC_PLAYER_DIR}/.theme" ]] && _saved_theme=$(<"${MUSIC_PLAYER_DIR}/.theme")
        for _t in "${_music_themes[@]}"; do
            if [[ "$_t" == "$_saved_theme" ]]; then
                echo "  ${_t}  ← active"
            else
                echo "  ${_t}"
            fi
        done
        echo "\nUsage: music --theme <name>"
        return 0
    fi

    # ── parse args ──
    local shuffle="" name="" no_vis=0 theme=""
    local _theme_from_arg=""
    for arg in "$@"; do
        case "$arg" in
            --shuffle|-s) shuffle="--shuffle" ;;
            --no-vis)     no_vis=1 ;;
            --theme=*)    _theme_from_arg="${arg#--theme=}" ;;
            --theme)      ;; # handled above
            *)            name="$arg" ;;
        esac
    done

    # Theme priority: --theme=X flag > saved config > default
    if [[ -n "$_theme_from_arg" ]]; then
        theme="$_theme_from_arg"
        # Save theme persistently
        echo "$theme" > "${MUSIC_PLAYER_DIR}/.theme"
    elif [[ -f "${MUSIC_PLAYER_DIR}/.theme" ]]; then
        theme=$(<"${MUSIC_PLAYER_DIR}/.theme")
    else
        theme="summer"
    fi

    _music_set_theme "$theme"

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

    # ── Clean up orphans from previous crashes ──
    # Kill any leftover mpv instances using our socket pattern
    local _had_orphans=0
    local _old_sock
    for _old_sock in /tmp/mpv-music-*(N); do
        if [[ -S "$_old_sock" ]]; then
            echo '{"command":["set_property","volume",0]}' | socat - "$_old_sock" 2>/dev/null >/dev/null
            echo '{"command":["set_property","pause",true]}' | socat - "$_old_sock" 2>/dev/null >/dev/null
            echo '{"command":["quit"]}' | socat - "$_old_sock" 2>/dev/null >/dev/null
            _had_orphans=1
        fi
        rm -f "$_old_sock"
    done
    # Wait for orphaned mpv to fully stop before touching PulseAudio
    (( _had_orphans )) && sleep 0.3
    # Remove orphaned PulseAudio modules (suspend sinks first to flush buffers)
    if command -v pactl &>/dev/null; then
        local _orphan _orphan_name
        # First suspend any orphaned null-sinks to flush their buffers
        for _orphan_name in $(pactl list short sinks 2>/dev/null | grep music_player_vis | awk '{print $2}'); do
            pactl suspend-sink "$_orphan_name" 1 2>/dev/null
        done
        sleep 0.08
        # Then unload all orphaned modules (loopbacks + null-sinks)
        for _orphan in $(pactl list short modules 2>/dev/null | grep music_player_vis | awk '{print $1}'); do
            pactl unload-module "$_orphan" 2>/dev/null
        done
    fi

    # ── PulseAudio: isolated sink for visualizer ──
    # Loopback is created later, after mpv is stable, to avoid audio pops
    local _pa_null_id="" _pa_loopback_id="" _pa_sink_name="music_player_vis_$$"
    if (( ! no_vis )) && command -v pactl &>/dev/null; then
        _pa_null_id=$(pactl load-module module-null-sink \
            sink_name="$_pa_sink_name" \
            sink_properties=device.description="MusicPlayerVis" 2>/dev/null)
    fi

    # ── build mpv command ──
    local -a mpv_args=(
        --no-terminal --no-video --volume=0 --pause
        --input-ipc-server="$sock"
        --prefetch-playlist=yes
        --cache=yes
        --cache-secs=30
        --demuxer-max-bytes=150MiB
        --demuxer-readahead-secs=10
        --audio-buffer=0.2
        --pulse-buffer=250
        --ytdl-raw-options=format="ba/b",extractor-args="youtube:player_client=android_music",no-warnings=
    )
    # Route mpv audio to the isolated sink if available
    if [[ -n "$_pa_null_id" ]]; then
        mpv_args+=(--audio-device="pulse/${_pa_sink_name}")
    fi
    [[ -n "$shuffle" ]] && mpv_args+=("$shuffle")

    if [[ -n "$mpv_playlist_file" ]]; then
        mpv_args+=("--playlist=$mpv_playlist_file")
    elif [[ -f "$url" ]]; then
        mpv_args+=("--playlist=$url")
    else
        mpv_args+=("$url")
    fi

    # ── loading message ──
    printf "\e[?1049h\e[?25l\e[H\e[2J"
    printf "\n\n"
    printf "  ${_th_highlight}♪  Loading player...${_th_reset}\n\n"
    printf "  ${_th_dim}Preparing ${_th_reset}%s ${_th_dim}· ${_th_secondary}%s${_th_reset}\n" "$plat_label" "$name"

    # Launch mpv in its own process group so Ctrl+C doesn't kill it directly
    # This lets our cleanup do a graceful fade-out before quitting mpv via IPC
    setopt LOCAL_OPTIONS NO_MONITOR
    mpv "${mpv_args[@]}" &
    local mpv_pid=$!

    # Wait for IPC socket
    for i in {1..30}; do
        [[ -S "$sock" ]] && break
        sleep 0.2
    done
    if [[ ! -S "$sock" ]]; then
        printf "\e[?1049l\e[?25h"
        echo "Could not start the player. Check your connection or the URL."
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

    # Now that mpv is stable on the null-sink, create loopback to speakers
    if [[ -n "$_pa_null_id" ]] && command -v pactl &>/dev/null; then
        _pa_loopback_id=$(pactl load-module module-loopback \
            source="${_pa_sink_name}.monitor" \
            latency_msec=30 2>/dev/null)
        sleep 0.15
    fi
    # Unpause and fade in volume
    _mpv_cmd '["set_property","volume",100]'
    _mpv_cmd '["set_property","pause",false]'

    # ── cava setup for bar visualizer ──
    local cava_pid=0
    local cava_fifo="/tmp/cava-music-$$"
    local cava_conf="/tmp/cava-conf-$$"
    local vis_enabled=0
    local cava_bars=64

    if (( ! no_vis )) && command -v cava &>/dev/null; then
        vis_enabled=1
        mkfifo "$cava_fifo" 2>/dev/null

        # Use isolated sink monitor if available, otherwise system default
        local _cava_source="auto"
        [[ -n "$_pa_null_id" ]] && _cava_source="${_pa_sink_name}.monitor"

        cat > "$cava_conf" << CAVAEOF
[general]
bars = $cava_bars
framerate = 30
sensitivity = 200
autosens = 1
noise_reduction = 0.2

[input]
method = pulse
source = $_cava_source

[output]
method = raw
raw_target = $cava_fifo
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
CAVAEOF

        cava -p "$cava_conf" &>/dev/null &!
        cava_pid=$!
        exec 3<>"$cava_fifo"
    elif (( ! no_vis )); then
        printf "  ${_th_dim}(install cava for RGB bar visualizer)${_th_reset}\n"
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

    _music_is_unavailable() {
        local t="${1:l}"
        [[ "$t" == *"private video"* || "$t" == *"deleted video"* || \
           "$t" == *"video privado"* || "$t" == *"video eliminado"* || \
           "$t" == *"unavailable"* || "$t" == *"no disponible"* ]] && return 0
        return 1
    }

    _music_tl_refresh() {
        local raw=$(echo '{"command":["get_property","playlist"]}' | socat - "$sock" 2>/dev/null)
        _tl_count=$(echo "$raw" | jq '.data | length' 2>/dev/null)
        [[ "$_tl_count" == "null" || -z "$_tl_count" ]] && _tl_count=0
        (( _tl_count == 0 )) && return
        _tl_titles=()
        local _line _idx=1 _remove_indices=()
        while IFS= read -r _line; do
            if [[ -n "$_line" ]] && _music_is_unavailable "$_line"; then
                _remove_indices+=( $(( _idx - 1 )) )
            elif [[ -n "$_line" ]]; then
                _tl_titles[$_idx]="$_line"
            fi
            (( _idx++ ))
        done <<< "$(echo "$raw" | jq -r '.data | to_entries[] | .value.title // "Track \(.key + 1)"' 2>/dev/null)"
        # Remove unavailable tracks (reverse order to keep indices valid)
        local _ri
        for (( _ri = ${#_remove_indices[@]}; _ri >= 1; _ri-- )); do
            _mpv_cmd "[\"playlist-remove\",${_remove_indices[$_ri]}]"
        done
        if (( ${#_remove_indices[@]} > 0 )); then
            raw=$(echo '{"command":["get_property","playlist"]}' | socat - "$sock" 2>/dev/null)
            _tl_count=$(echo "$raw" | jq '.data | length' 2>/dev/null)
            [[ "$_tl_count" == "null" || -z "$_tl_count" ]] && _tl_count=0
            _tl_titles=()
            _idx=1
            while IFS= read -r _line; do
                [[ -n "$_line" ]] && _tl_titles[$_idx]="$_line"
                (( _idx++ ))
            done <<< "$(echo "$raw" | jq -r '.data | to_entries[] | .value.title // "Track \(.key + 1)"' 2>/dev/null)"
        fi
    }

    # ── prefetch next tracks ──
    local _pf_cache_dir="/tmp/mpv-prefetch-$$"
    mkdir -p "$_pf_cache_dir"
    typeset -gA _pf_done
    _pf_done=()

    _music_prefetch() {
        local raw=$(echo '{"command":["get_property","playlist"]}' | socat - "$sock" 2>/dev/null)
        local cur=$(_mpv_get playlist-pos)
        [[ -z "$cur" ]] && return
        local total=$(echo "$raw" | jq '.data | length' 2>/dev/null)
        [[ "$total" == "null" || -z "$total" ]] && return
        local pf_i pf_url
        for (( pf_i = 1; pf_i <= 3; pf_i++ )); do
            local next=$(( cur + pf_i ))
            (( next >= total )) && continue
            pf_url=$(echo "$raw" | jq -r ".data[$next].filename // empty" 2>/dev/null)
            [[ -z "$pf_url" || "$pf_url" == /tmp/* ]] && continue
            [[ -n "${_pf_done[$pf_url]}" ]] && continue
            _pf_done[$pf_url]=1
            # Resolve + download first seconds of audio in background
            {
                local _stream_url
                _stream_url=$(yt-dlp -f "ba/b" -g --extractor-args "youtube:player_client=android_music" "$pf_url" 2>/dev/null | head -1)
                if [[ -n "$_stream_url" ]]; then
                    # Download first 512KB to warm CDN + OS cache
                    curl -s -r 0-524287 -o /dev/null "$_stream_url" 2>/dev/null
                fi
            } &!
        done
    }

    # ── cleanup ──
    _music_cleanup() {
        # Block further INT signals during cleanup to prevent partial teardown
        trap '' INT
        printf "\e[?1049l\e[?25h"
        exec 3<&- 2>/dev/null
        if (( cava_pid > 0 )); then
            kill $cava_pid 2>/dev/null
            wait $cava_pid 2>/dev/null
            cava_pid=0
        fi
        # Step 1: Stop audio production — mute + pause mpv FIRST (before touching PA modules)
        # This prevents new audio from entering the loopback buffer
        if [[ -S "$sock" ]]; then
            echo '{"command":["set_property","volume",0]}' | socat - "$sock" 2>/dev/null >/dev/null
            echo '{"command":["set_property","pause",true]}' | socat - "$sock" 2>/dev/null >/dev/null
        fi
        # Step 2: Suspend the null-sink to flush its buffer and stop feeding the monitor
        [[ -n "$_pa_null_id" ]] && pactl suspend-sink "$_pa_sink_name" 1 2>/dev/null
        # Step 3: Wait for the loopback buffer to drain (latency_msec=30 + margin)
        sleep 0.08
        # Step 4: Now safe to unload loopback — its buffer should be empty/silent
        [[ -n "$_pa_loopback_id" ]] && pactl unload-module "$_pa_loopback_id" 2>/dev/null
        # Step 5: Quit mpv (audio was already muted+paused, going to suspended null-sink)
        if [[ -S "$sock" ]]; then
            echo '{"command":["quit"]}' | socat - "$sock" 2>/dev/null >/dev/null
            sleep 0.1
        fi
        # Wait for mpv to exit, then fallback kill if still running
        wait $mpv_pid 2>/dev/null
        kill -0 $mpv_pid 2>/dev/null && kill $mpv_pid 2>/dev/null
        wait $mpv_pid 2>/dev/null
        # Step 6: Remove null-sink after mpv is fully stopped
        [[ -n "$_pa_null_id" ]] && pactl unload-module "$_pa_null_id" 2>/dev/null
        rm -rf "$sock" "$cava_fifo" "$cava_conf" "$mpv_playlist_file" "$_pf_cache_dir"
        stty sane 2>/dev/null
        printf "\n  ${_th_highlight}♪  Player closed${_th_reset}\n"
        printf "  ${_th_dim}See you next time.${_th_reset}\n\n"
    }

    trap "_music_cleanup; trap - INT; return" INT

    # ── initial cleanup of unavailable tracks + prefetch ──
    sleep 1
    _music_tl_refresh
    _music_prefetch

    # ── loading complete ──
    printf "\e[H\e[2J"
    printf "\n\n"
    printf "  ${_th_highlight}♪  Now playing${_th_reset}\n\n"
    printf "  %s ${_th_dim}·${_th_reset} ${_th_secondary}%s${_th_reset}" "$plat_label" "$name"
    if (( _tl_count > 0 )); then
        printf "  ${_th_dim}(%d tracks)${_th_reset}" "$_tl_count"
    fi
    printf "\n"
    sleep 1

    # ── state ──
    local _e=$'\e' _n=$'\n'
    local reset="${_e}[0m"
    local clr="${_e}[K"
    local paused=0 frame_n=0
    local last_title="" last_vol="" cava_data=""
    local _prefetch_pos=-1
    local _last_title_pos=""
    local tl_cur=0 tl_start=0 tl_end=0 tl_i=0 tl_title="" tl_num=0 tl_max=0
    local cur_pl_pos="" _new_title="" _cline=""
    local pos="" dur="" pos_fmt="" dur_fmt=""
    local vol_int="" pause_icon="" disp_title=""
    local cols=80 term_rows=24
    local time_overhead=0 bar_size=0 bar="" pos_s=0 dur_s=0 filled=0 empty_b=0
    local frame="" dt=""
    local vis_rows=0 reserved=0 max_vis=0 vis_data="" _vi=0
    local _vol_icon="" key="" seq=""
    local _ci=0 _th_idx=0 _next_idx=0
    local _speed_idx=1 _speed_label="" _speed_arrows=""
    local -a _speeds=(1 1.25 1.5 2 3)
    local _search_mode=0 _search_query="" _search_sel=0 _sr_lim=0
    local -a _search_results=() _search_indices=()

    printf "\e[H\e[2J"
    stty -echo 2>/dev/null

    # ── main loop ──
    while kill -0 $mpv_pid 2>/dev/null; do

        # Drain cava FIFO
        if (( vis_enabled && cava_pid > 0 )); then
            _cline=""
            while read -t 0.005 -u 3 _cline 2>/dev/null; do
                cava_data="$_cline"
            done
        fi

        # Query mpv
        cur_pl_pos=$(_mpv_get playlist-pos)
        if (( frame_n % 8 == 0 )); then
            _new_title=$(_mpv_get media-title)
            last_vol=$(_mpv_get volume)
            if [[ "$cur_pl_pos" != "$_last_title_pos" ]]; then
                # Track changed — accept whatever title mpv gives
                last_title="$_new_title"
                _last_title_pos="$cur_pl_pos"
            elif [[ -n "$_new_title" && ( -z "$last_title" || "$last_title" == *"youtube.com"* || "$last_title" == *"playlist?"* || "$last_title" == *"youtu.be"* || "$last_title" == *"soundcloud.com"* || "$last_title" == "http"* ) ]]; then
                # Same track but current title is a URL — upgrade to real title
                last_title="$_new_title"
            fi
            # Otherwise: same pos, title already good — ignore (prevents prefetch flicker)
        fi
        pos=$(_mpv_get time-pos)
        dur=$(_mpv_get duration)

        # Prefetch when track changes
        if [[ -n "$cur_pl_pos" && "$cur_pl_pos" != "$_prefetch_pos" ]]; then
            _prefetch_pos=$cur_pl_pos
            _music_prefetch
        fi

        # Refresh track list
        if (( tracklist_open )); then
            if [[ -n "$cur_pl_pos" && "$cur_pl_pos" != "$_tl_pos" ]] || (( _tl_last_refresh < 0 )) || (( frame_n % 60 == 0 )); then
                _music_tl_refresh
                _tl_last_refresh=$frame_n
            fi
            [[ -n "$cur_pl_pos" ]] && _tl_pos=$cur_pl_pos
        fi

        # Format times
        pos_fmt="--:--"; dur_fmt="--:--"
        if [[ -n "$pos" ]]; then
            pos_fmt=$(printf "%02d:%02d" $((${pos%.*} / 60)) $((${pos%.*} % 60)))
        fi
        if [[ -n "$dur" ]]; then
            dur_fmt=$(printf "%02d:%02d" $((${dur%.*} / 60)) $((${dur%.*} % 60)))
        fi

        vol_int=${last_vol%.*}
        pause_icon=""; (( paused )) && pause_icon=" ${_e}[33m⏸${reset}"
        disp_title="${last_title:-...}"

        # Terminal dimensions
        cols=$(tput cols 2>/dev/null || echo 80)
        term_rows=$(tput lines 2>/dev/null || echo 24)

        # ═══ RESPONSIVE PROGRESS BAR ═══
        time_overhead=$(( ${#pos_fmt} + 1 + ${#dur_fmt} + 2 ))
        bar_size=$(( cols - time_overhead ))
        (( bar_size < 8 )) && bar_size=8
        (( bar_size > 60 )) && bar_size=60

        bar=""
        if [[ -n "$pos" && -n "$dur" ]]; then
            pos_s=${pos%.*}; dur_s=${dur%.*}
            if (( dur_s > 0 )); then
                filled=$(( (pos_s * bar_size) / dur_s ))
                empty_b=$(( bar_size - filled ))
                bar="${_th_bar}"
                for ((b=0; b<filled; b++)); do bar+="━"; done
                bar+="${_th_bar_dim}"
                for ((b=0; b<empty_b; b++)); do bar+="━"; done
                bar+="${reset}"
            fi
        fi
        if [[ -z "$bar" ]]; then
            bar="${_th_bar_dim}"
            for ((b=0; b<bar_size; b++)); do bar+="━"; done
            bar+="${reset}"
        fi

        # ═══ BUILD FRAME ═══
        frame=""

        # ── Search mode ──
        if (( _search_mode )); then
            frame+="  ${_th_accent}/${reset} ${_th_primary}${_search_query}${reset}█${clr}${_n}"
            if (( ${#_search_results[@]} > 0 )); then
                local _sr_max=8 _sr_i
                (( _sr_max > ${#_search_results[@]} )) && _sr_max=${#_search_results[@]}
                for (( _sr_i = 1; _sr_i <= _sr_max; _sr_i++ )); do
                    if (( _sr_i - 1 == _search_sel )); then
                        frame+="  ${_th_highlight}${_e}[7m ► ${_search_results[$_sr_i]} ${_e}[27m${reset}${clr}${_n}"
                    else
                        frame+="  ${_th_dim}   ${_search_results[$_sr_i]}${reset}${clr}${_n}"
                    fi
                done
            elif [[ -n "$_search_query" ]]; then
                frame+="  ${_th_dim}No results${reset}${clr}${_n}"
            fi
            frame+="${clr}${_n}"
        fi

        # ── Track list ──
        if (( tracklist_open && _tl_count > 0 )); then
            tl_cur=${_tl_pos:-0}
            tl_start=$tl_cur
            if (( tl_cur > 0 )); then
                tl_start=$(( tl_cur - 3 ))
                (( tl_start < 0 )) && tl_start=0
            fi
            tl_end=$tl_cur
            if (( tl_cur < _tl_count - 1 )); then
                tl_end=$(( tl_cur + 3 ))
                (( tl_end >= _tl_count )) && tl_end=$(( _tl_count - 1 ))
            fi
            tl_max=$(( cols - 12 ))
            for (( tl_i = tl_start; tl_i <= tl_end; tl_i++ )); do
                tl_title="${_tl_titles[$((tl_i+1))]:-Track $((tl_i+1))}"
                if (( ${#tl_title} > tl_max )); then
                    tl_title="${tl_title:0:$((tl_max-3))}..."
                fi
                if (( tl_i == tl_cur )); then
                    frame+="  ${_th_highlight}${_e}[7m ► ${tl_title} ◄ ${_e}[27m${reset}${clr}${_n}"
                else
                    tl_num=$(( tl_i + 1 ))
                    frame+="  ${_th_dim}   ${tl_num}. ${tl_title}${reset}${clr}${_n}"
                fi
            done
        fi

        # ── Visualizer ──
        if (( vis_enabled )); then
            vis_rows=5
            reserved=4
            (( tracklist_open && _tl_count > 0 )) && reserved=11
            max_vis=$(( term_rows - reserved ))
            (( max_vis < 2 )) && max_vis=2
            (( vis_rows > max_vis )) && vis_rows=$max_vis

            vis_data="$cava_data"
            if [[ -z "$vis_data" ]]; then
                vis_data="1"
                for (( _vi = 1; _vi < cava_bars; _vi++ )); do vis_data+=";1"; done
            fi
            _music_bars_build "$vis_data" 100 $cols $vis_rows
            frame+="$_VIS_FRAME"
        fi

        # ── RESPONSIVE STATUS (3 lines) ──
        # Line 1: platform + name + vol + speed
        if [[ -n "$vol_int" ]] && (( vol_int == 0 )); then
            _vol_icon="♪̸"
        elif [[ -n "$vol_int" ]] && (( vol_int <= 40 )); then
            _vol_icon="♩"
        else
            _vol_icon="♫"
        fi
        # Speed arrows: themed color, more arrows = faster
        case "$_speed_idx" in
            1) _speed_label="" ;;
            2) _speed_label=" ${_th_accent}▸${reset} ${_th_dim}1.25x${reset}" ;;
            3) _speed_label=" ${_th_accent}▸▸${reset} ${_th_dim}1.5x${reset}" ;;
            4) _speed_label=" ${_th_accent}▸▸▸${reset} ${_th_dim}2x${reset}" ;;
            5) _speed_label=" ${_th_accent}▸▸▸▸${reset} ${_th_dim}3x${reset}" ;;
        esac
        frame+="${icon} ${plat_label} ${_th_dim}·${reset} ${_th_secondary}${name}${pause_icon}${reset}  ${_th_accent}${_vol_icon} ${vol_int:-100}%${reset}${_speed_label}${clr}${_n}"
        # Line 2: title (full width available)
        dt="$disp_title"
        if (( ${#dt} > cols - 1 )); then
            dt="${dt:0:$((cols-4))}..."
        fi
        frame+="${_th_primary}${dt}${reset}${clr}${_n}"
        # Line 3: progress
        frame+="${_th_secondary}${pos_fmt} ${bar} ${dur_fmt}${reset}${clr}"

        # ═══ RENDER ═══
        printf "\e[H"
        printf "%s" "$frame"
        printf "\e[J"

        # ── input ──
        key=""
        if (( _search_mode || vis_enabled || tracklist_open )); then
            read -sk1 -t0.04 key 2>/dev/null
        else
            read -sk1 -t1 key 2>/dev/null
        fi

        if (( _search_mode )); then
            # Search mode input handling
            case "$key" in
                $'\e')
                    seq=""
                    read -sk2 -t0.1 seq 2>/dev/null
                    case "$seq" in
                        "[A") # Up
                            (( _search_sel > 0 )) && (( _search_sel-- ))
                            ;;
                        "[B") # Down (clamp to visible results, max 8)
                            _sr_lim=${#_search_results[@]}
                            (( _sr_lim > 8 )) && _sr_lim=8
                            (( _search_sel < _sr_lim - 1 )) && (( _search_sel++ ))
                            ;;
                        *) # Escape alone — cancel search
                            if [[ -z "$seq" ]]; then
                                _search_mode=0
                                _search_query=""
                                _search_results=()
                                _search_indices=()
                            fi
                            ;;
                    esac
                    ;;
                $'\n'|$'\r') # Enter — jump to selected track
                    if (( ${#_search_indices[@]} > 0 && _search_sel < ${#_search_indices[@]} )); then
                        _mpv_cmd "[\"set_property\",\"playlist-pos\",${_search_indices[$((_search_sel+1))]}]"
                    fi
                    _search_mode=0
                    _search_query=""
                    _search_results=()
                    _search_indices=()
                    ;;
                $'\x7f'|$'\b') # Backspace
                    if [[ -n "$_search_query" ]]; then
                        _search_query="${_search_query[1,-2]}"
                    fi
                    # Re-filter
                    _search_results=()
                    _search_indices=()
                    _search_sel=0
                    if [[ -n "$_search_query" ]]; then
                        local _sq="${_search_query:l}" _si
                        for (( _si = 1; _si <= ${#_tl_titles[@]}; _si++ )); do
                            if [[ "${_tl_titles[$_si]:l}" == *"$_sq"* ]]; then
                                _search_results+=("${_tl_titles[$_si]}")
                                _search_indices+=($(( _si - 1 )))
                            fi
                        done
                    fi
                    ;;
                [[:print:]]) # Regular character — append to query
                    _search_query+="$key"
                    _search_results=()
                    _search_indices=()
                    _search_sel=0
                    local _sq="${_search_query:l}" _si
                    for (( _si = 1; _si <= ${#_tl_titles[@]}; _si++ )); do
                        if [[ "${_tl_titles[$_si]:l}" == *"$_sq"* ]]; then
                            _search_results+=("${_tl_titles[$_si]}")
                            _search_indices+=($(( _si - 1 )))
                        fi
                    done
                    ;;
            esac
        else
            # Normal mode input
            case "$key" in
                -)  _mpv_cmd '["add","volume",-5]' ;;
                +)  _mpv_cmd '["add","volume",5]' ;;
                " ") _mpv_cmd '["cycle","pause"]'; (( paused = !paused )) ;;
                f)  # Enter search mode (close tracklist if open)
                    tracklist_open=0
                    _search_mode=1
                    _search_query=""
                    _search_results=()
                    _search_indices=()
                    _search_sel=0
                    # Always refresh tracklist for search
                    _music_tl_refresh
                    ;;
                v)  if (( vis_enabled )); then
                        vis_enabled=0
                        if (( cava_pid > 0 )); then
                            kill $cava_pid 2>/dev/null
                            exec 3<&- 2>/dev/null
                            cava_pid=0
                        fi
                        cava_data=""
                    elif command -v cava &>/dev/null; then
                        vis_enabled=1
                        rm -f "$cava_fifo"
                        mkfifo "$cava_fifo" 2>/dev/null
                        cava -p "$cava_conf" &>/dev/null &!
                        cava_pid=$!
                        exec 3<>"$cava_fifo"
                        cava_data=""
                    fi
                    ;;
                t)  if (( tracklist_open )); then
                        tracklist_open=0
                    else
                        tracklist_open=1
                        _tl_last_refresh=-1
                        _tl_pos=$(_mpv_get playlist-pos)
                    fi
                    ;;
                s)  # Cycle playback speed
                    _speed_idx=$(( _speed_idx % ${#_speeds[@]} + 1 ))
                    _mpv_cmd "[\"set_property\",\"speed\",${_speeds[$_speed_idx]}]"
                    ;;
                c)  # Cycle color theme
                    _ci=1; _th_idx=0
                    for _cth in "${_music_themes[@]}"; do
                        if [[ "$_cth" == "$_th_name" ]]; then
                            _th_idx=$_ci; break
                        fi
                        (( _ci++ ))
                    done
                    _next_idx=$(( _th_idx % ${#_music_themes[@]} + 1 ))
                    _music_set_theme "${_music_themes[$_next_idx]}"
                    ;;
                q)  break ;;
                $'\e')
                    seq=""
                    read -sk2 -t0.1 seq 2>/dev/null
                    case "$seq" in
                        "[A") _mpv_cmd '["playlist-prev"]' ;;
                        "[B") _mpv_cmd '["playlist-next"]' ;;
                        "[C") _mpv_cmd '["seek",5]' ;;
                        "[D") _mpv_cmd '["seek",-5]' ;;
                    esac
                    ;;
            esac
        fi

        (( frame_n++ ))
    done

    _music_cleanup
    trap - INT
}
