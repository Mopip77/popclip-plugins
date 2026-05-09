#!/bin/bash
# Snipaste Float — classify the selection and float it on the desktop via Snipaste CLI.
# Detection priority: Mermaid → HTML → local image file → image URL → plain text.

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

# Returns 0 if the first line of $1 starts with a known Mermaid diagram
# keyword (case-insensitive, leading/trailing whitespace ignored). Trailing
# args after the keyword on the same line are allowed (e.g. "flowchart TD").
# The whitelist is intentionally narrow.
#
# We extract and strip the first line ourselves rather than going through the
# repo's existing trim() helper, which has a separate pre-existing bug.
is_mermaid_first_line() {
    local input first_line stripped lower
    input="$1"
    # First line up to the first newline.
    first_line="${input%%$'\n'*}"
    # Strip leading whitespace (spaces and tabs).
    stripped="${first_line#"${first_line%%[^ $'\t']*}"}"
    # Strip trailing whitespace.
    stripped="${stripped%"${stripped##*[^ $'\t']}"}"
    lower="$(printf '%s' "$stripped" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        flowchart|flowchart\ *|flowchart$'\t'*) return 0 ;;
        graph|graph\ *|graph$'\t'*) return 0 ;;
        sequencediagram|sequencediagram\ *|sequencediagram$'\t'*) return 0 ;;
        classdiagram|classdiagram\ *|classdiagram$'\t'*) return 0 ;;
        statediagram|statediagram\ *|statediagram$'\t'*) return 0 ;;
        statediagram-v2|statediagram-v2\ *|statediagram-v2$'\t'*) return 0 ;;
        erdiagram|erdiagram\ *|erdiagram$'\t'*) return 0 ;;
        gantt|gantt\ *|gantt$'\t'*) return 0 ;;
        pie|pie\ *|pie$'\t'*) return 0 ;;
    esac
    return 1
}

# Render Mermaid source ($1) to PNG and pin it via Snipaste.
# Returns 0 on success, 1 on any failure (silent fallback path).
try_render_mermaid() {
    local source="$1"

    if ! command -v mmdc >/dev/null 2>&1; then
        log "mermaid: mmdc not found on PATH, skipping render"
        return 1
    fi

    local ts input output
    ts="$(date +%s%N 2>/dev/null || date +%s)"
    input="/tmp/snipaste-float-${ts}.mmd"
    output="/tmp/snipaste-float-${ts}.png"

    if ! printf '%s' "$source" > "$input" 2>>"$LOG_FILE"; then
        log "mermaid: failed to write input file $input"
        rm -f "$input"
        return 1
    fi

    log "mermaid: rendering $input -> $output"
    # macOS lacks timeout(1); use the system Perl's alarm() to bound mmdc.
    if ! /usr/bin/perl -e 'alarm shift; exec @ARGV' 15 \
            mmdc -i "$input" -o "$output" -t default -b white -s 2 --quiet \
            >>"$LOG_FILE" 2>&1; then
        log "mermaid: mmdc failed or timed out"
        rm -f "$input" "$output"
        return 1
    fi

    if [[ ! -s "$output" ]]; then
        log "mermaid: output file missing or empty"
        rm -f "$input" "$output"
        return 1
    fi

    # Clean up both temp files when the script exits, regardless of outcome.
    trap 'rm -f "$input" "$output"' EXIT

    log "mermaid: pinning $output"
    run_snipaste paste --files "$output"
    return 0
}

main() {
    log "========== start =========="
    local text="${POPCLIP_TEXT:-}"
    local full_text="${POPCLIP_FULL_TEXT:-$text}"
    local html="${POPCLIP_HTML:-}"
    local urls="${POPCLIP_URLS:-}"
    log "text_len=${#text} html_len=${#html} urls_lines=$(printf '%s' "$urls" | grep -c . || true)"

    # --- 1. Mermaid branch ---------------------------------------------
    # First-line keyword whitelist. On any render failure, fall through
    # silently to the existing chain (HTML → imageFile → imageUrl → text).
    if is_mermaid_first_line "$full_text"; then
        log "decision: mermaid (attempting render)"
        if try_render_mermaid "$full_text"; then
            log "done"
            return 0
        fi
        log "mermaid render failed; falling through"
    fi

    # --- 2. HTML branch -------------------------------------------------
    if [[ -n "$html" ]]; then
        log "decision: html"
        run_snipaste paste --html "$html"
        log "done"
        return 0
    fi

    local trimmed
    trimmed="$(trim "$full_text")"

    # --- 3. Local image file branch ------------------------------------
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

    # --- 4. Image URL branch -------------------------------------------
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

    # --- 5. Plain text fallback ----------------------------------------
    log "decision: text"
    run_snipaste paste --plain "$text"
    log "done"
}

if [[ -z "${SNIPASTE_FLOAT_TEST_MODE:-}" ]]; then
    # Clean up old tmp files (>1 day) opportunistically; ignore errors.
    find /tmp -name 'snipaste-float-*' -type f -mtime +1 -delete 2>/dev/null || true
    main "$@"
fi
