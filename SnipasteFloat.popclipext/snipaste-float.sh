#!/bin/bash
# Snipaste Float — classify the selection and float it on the desktop via Snipaste CLI.
# Detection priority: HTML → local image file → image URL → plain text.

set -u

LOG_FILE="/tmp/snipaste-float.log"
SNIPASTE_BIN="/Applications/Snipaste.app/Contents/MacOS/Snipaste"
DOWNLOAD_TIMEOUT_SECONDS=10

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

show_error() {
    local msg="$1"
    log "error: $msg"
    /usr/bin/osascript -e "display dialog \"Snipaste Float 失败：${msg//\"/\\\"}\n\n日志：$LOG_FILE\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1
}

run_snipaste() {
    if [[ ! -x "$SNIPASTE_BIN" ]]; then
        show_error "Snipaste 未安装或路径不对"
        exit 1
    fi
    log "snipaste args: $*"
    if ! "$SNIPASTE_BIN" "$@" 2>>"$LOG_FILE"; then
        show_error "Snipaste 调用失败"
        exit 1
    fi
}

is_image_ext() {
    # macOS ships bash 3.2; ${1,,} (bash 4 lowercase) is unavailable, so use tr.
    local lower
    lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        png|jpg|jpeg|gif|webp|bmp|tiff|heic|svg) return 0 ;;
        *) return 1 ;;
    esac
}

ext_of() {
    local path="$1"
    local base="${path##*/}"
    [[ "$base" == *.* ]] || { echo ""; return; }
    local ext="${base##*.}"
    [[ -z "$ext" ]] && { echo ""; return; }
    echo "$ext"
}

normalize_path() {
    local p="$1"
    p="${p#file://}"
    p="${p#localhost}"
    [[ "$p" == "~/"* ]] && p="$HOME/${p#\~/}"
    echo "$p"
}

# Strip the surrounding whitespace using parameter expansion / sed (POSIX-portable enough).
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    echo "$s"
}

main() {
    log "========== start =========="
    local text="${POPCLIP_TEXT:-}"
    local full_text="${POPCLIP_FULL_TEXT:-$text}"
    local html="${POPCLIP_HTML:-}"
    local urls="${POPCLIP_URLS:-}"
    log "text_len=${#text} html_len=${#html} urls_lines=$(printf '%s' "$urls" | grep -c . || true)"

    # --- 1. HTML branch -------------------------------------------------
    if [[ -n "$html" ]]; then
        log "decision: html"
        run_snipaste paste --html "$html"
        log "done"
        return 0
    fi

    local trimmed
    trimmed="$(trim "$full_text")"

    # --- 2. Local image file branch ------------------------------------
    # Heuristic: if the entire selection is a path-shaped string ending in an image ext
    # and the file exists, treat as imageFile.
    if [[ "$trimmed" == /* || "$trimmed" == "~/"* || "$trimmed" == file://* ]]; then
        local candidate
        candidate="$(normalize_path "$trimmed")"
        local ext
        ext="$(ext_of "$candidate")"
        if [[ -n "$ext" ]] && is_image_ext "$ext" && [[ -f "$candidate" ]]; then
            log "decision: imageFile path=$candidate"
            run_snipaste paste --files "$candidate"
            log "done"
            return 0
        fi
    fi

    # --- 3. Image URL branch -------------------------------------------
    # POPCLIP_URLS is newline-separated. Use the first URL only, and only if the
    # selection is just that URL (avoid false positives in mixed text).
    if [[ -n "$urls" ]]; then
        local first_url
        first_url="$(printf '%s\n' "$urls" | head -n 1)"
        if [[ "$trimmed" == "$first_url" ]]; then
            # Strip query/fragment for ext detection.
            local url_path="${first_url%%\#*}"
            url_path="${url_path%%\?*}"
            local url_ext
            url_ext="$(ext_of "$url_path")"
            if [[ -n "$url_ext" ]] && is_image_ext "$url_ext"; then
                local ts safe_ext tmp_path
                ts="$(date +%s%N 2>/dev/null || date +%s)"
                if [[ "$url_ext" =~ ^[A-Za-z0-9]+$ ]]; then
                    safe_ext="$(echo "$url_ext" | tr '[:upper:]' '[:lower:]')"
                else
                    safe_ext="img"
                fi
                tmp_path="/tmp/snipaste-float-${ts}.${safe_ext}"
                log "decision: imageUrl url=$first_url tmp=$tmp_path"
                if ! /usr/bin/curl -fsSL --max-time "$DOWNLOAD_TIMEOUT_SECONDS" -o "$tmp_path" "$first_url" 2>>"$LOG_FILE"; then
                    show_error "图片下载失败"
                    exit 1
                fi
                if [[ ! -s "$tmp_path" ]]; then
                    show_error "图片下载失败 (空文件)"
                    rm -f "$tmp_path"
                    exit 1
                fi
                # Always clean up the temp file, success or fail.
                trap 'rm -f "$tmp_path"' EXIT
                run_snipaste paste --files "$tmp_path"
                log "done"
                return 0
            fi
        fi
    fi

    # --- 4. Plain text fallback ----------------------------------------
    log "decision: text"
    run_snipaste paste --plain "$text"
    log "done"
}

# Clean up old tmp files (>1 day) opportunistically; ignore errors.
find /tmp -name 'snipaste-float-*' -type f -mtime +1 -delete 2>/dev/null || true

main "$@"
