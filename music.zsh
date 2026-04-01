# --- ZSH MUSIC PLAYER ---
# Terminal YouTube music player with IPC controls
# Dependencies: mpv, yt-dlp, socat, jq

MUSIC_PLAYER_DIR="${0:A:h}"
MUSIC_PLAYLISTS_FILE="${MUSIC_PLAYER_DIR}/playlists.conf"

_music_load_playlists() {
    declare -gA PLAYLISTS
    PLAYLISTS=()
    [[ ! -f "$MUSIC_PLAYLISTS_FILE" ]] && return
    while IFS='=' read -r key val; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        key="${key## }"; key="${key%% }"
        val="${val## }"; val="${val%% }"
        PLAYLISTS[$key]="$val"
    done < "$MUSIC_PLAYLISTS_FILE"
}

music() {
    _music_load_playlists

    if [[ -z "$1" ]]; then
        echo "Available playlists:"
        for key in ${(k)PLAYLISTS}; do
            echo "  music $key"
        done
        echo "\nUsage: music <playlist> [--shuffle|-s]"
        echo "\nControls:"
        echo "  space      pause/play"
        echo "  9/0        volume down/up"
        echo "  ↑/↓        next/previous track"
        echo "  ←/→        seek -5s/+5s"
        echo "  q          quit"
        return 0
    fi

    # check dependencies
    for dep in mpv yt-dlp socat jq; do
        if ! command -v $dep &>/dev/null; then
            echo "Error: $dep is not installed"
            return 1
        fi
    done

    local shuffle=""
    local name=""
    for arg in "$@"; do
        if [[ "$arg" == "--shuffle" || "$arg" == "-s" ]]; then
            shuffle="--shuffle"
        else
            name="$arg"
        fi
    done
    local url="${PLAYLISTS[$name]:-$name}"
    local sock="/tmp/mpv-music-$$"

    # launch mpv in background without terminal
    mpv --no-terminal --no-video --volume=100 \
        --input-ipc-server="$sock" \
        --ytdl-raw-options=format="ba/b" $shuffle "$url" &
    local mpv_pid=$!

    # wait for socket to exist
    for i in {1..30}; do
        [[ -S "$sock" ]] && break
        sleep 0.2
    done

    _mpv_get() {
        echo "{\"command\":[\"get_property\",\"$1\"]}" | socat - "$sock" 2>/dev/null | jq -r '.data // empty' 2>/dev/null
    }

    _mpv_cmd() {
        echo "{\"command\":$1}" | socat - "$sock" 2>/dev/null >/dev/null
    }

    trap "kill $mpv_pid 2>/dev/null; rm -f '$sock'; stty sane 2>/dev/null; trap - INT; return" INT

    local gold=$'\e[38;5;220m'
    local purple=$'\e[38;5;141m'
    local cyan=$'\e[38;5;51m'
    local white=$'\e[38;5;255m'
    local magenta=$'\e[38;5;201m'
    local dim=$'\e[38;5;240m'
    local reset=$'\e[0m'
    local paused=0
    local bar_size=20

    # status loop
    while kill -0 $mpv_pid 2>/dev/null; do
        local title=$(_mpv_get media-title)
        local vol=$(_mpv_get volume)
        local pos=$(_mpv_get time-pos)
        local dur=$(_mpv_get duration)

        # format times
        local pos_fmt="--:--"
        local dur_fmt="--:--"
        if [[ -n "$pos" ]]; then
            local pm=$((${pos%.*} / 60))
            local ps=$((${pos%.*} % 60))
            pos_fmt=$(printf "%02d:%02d" $pm $ps)
        fi
        if [[ -n "$dur" ]]; then
            local dm=$((${dur%.*} / 60))
            local ds=$((${dur%.*} % 60))
            dur_fmt=$(printf "%02d:%02d" $dm $ds)
        fi

        # progress bar
        local bar=""
        if [[ -n "$pos" && -n "$dur" ]]; then
            local pos_s=${pos%.*}
            local dur_s=${dur%.*}
            if (( dur_s > 0 )); then
                local filled=$(( (pos_s * bar_size) / dur_s ))
                local empty=$(( bar_size - filled ))
                bar="${magenta}"
                for ((b=0; b<filled; b++)); do bar+="━"; done
                bar+="${dim}"
                for ((b=0; b<empty; b++)); do bar+="━"; done
                bar+="${reset}"
            fi
        else
            bar="${dim}"
            for ((b=0; b<bar_size; b++)); do bar+="━"; done
            bar+="${reset}"
        fi

        local vol_int=${vol%.*}
        local pause_icon=""
        if (( paused )); then pause_icon=" ⏸"; fi

        # truncate title to fit in one line
        local cols=$(tput cols 2>/dev/null || echo 80)
        local fixed_len=$(( ${#name} + ${#vol_int} + ${#pos_fmt} + ${#dur_fmt} + 30 + bar_size ))
        local max_title=$(( cols - fixed_len ))
        local disp_title="${title:-...}"
        if (( ${#disp_title} > max_title && max_title > 3 )); then
            disp_title="${disp_title:0:$((max_title-3))}..."
        fi

        printf "\r${gold}♪ ${name}${pause_icon}${reset}  ${purple}${disp_title}${reset}  ${cyan}Vol: ${vol_int:-40}%%${reset}  ${white}${pos_fmt} ${bar} ${dur_fmt}${reset}\e[K"

        # read key with timeout
        local key=""
        read -sk1 -t1 key 2>/dev/null
        case "$key" in
            9)  _mpv_cmd '["add","volume",-5]' ;;
            0)  _mpv_cmd '["add","volume",5]' ;;
            " ") _mpv_cmd '["cycle","pause"]'; (( paused = !paused )) ;;
            q)  kill $mpv_pid 2>/dev/null; break ;;
            $'\e')
                local seq=""
                read -sk2 -t0.1 seq 2>/dev/null
                case "$seq" in
                    "[A") _mpv_cmd '["playlist-next"]' ;;
                    "[B") _mpv_cmd '["playlist-prev"]' ;;
                    "[C") _mpv_cmd '["seek",5]' ;;
                    "[D") _mpv_cmd '["seek",-5]' ;;
                esac
                ;;
        esac
    done

    printf "\r\e[K"
    rm -f "$sock"
    stty sane 2>/dev/null
    trap - INT
}
