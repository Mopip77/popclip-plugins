#!/bin/bash
# Remember Everywhere — save the selection into OpenViking via the ov CLI.
# Routing: existing local path → add-resource; single URL → add-resource;
# anything else → add-memory (OV classifies the memory server-side).

set -u

LOG_FILE="${REMEMBER_LOG_FILE:-$HOME/Library/Logs/remember-everywhere.log}"
NOTIFY_CMD="${REMEMBER_NOTIFY_CMD:-/usr/bin/osascript}"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

notify() {
    local msg="$1"
    msg="${msg//\\/\\\\}"
    msg="${msg//\"/\\\"}"
    "$NOTIFY_CMD" -e "display notification \"$msg\" with title \"Remember Everywhere\"" >/dev/null 2>&1
}

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

normalize_path() {
    local p="$1"
    p="${p#file://}"
    [[ "$p" == "~" ]] && p="$HOME"
    [[ "$p" == "~/"* ]] && p="$HOME/${p#\~/}"
    printf '%s' "$p"
}

# Prints one of: empty | path | url | memory. Expects trimmed input.
classify() {
    local s="$1"
    [[ -z "$s" ]] && { echo empty; return; }
    if [[ "$s" != *$'\n'* ]]; then
        local p
        p="$(normalize_path "$s")"
        [[ -e "$p" ]] && { echo path; return; }
        [[ "$s" =~ ^https?://[^[:space:]]+$ ]] && { echo url; return; }
    fi
    echo memory
}

# Escape for a JSON string body. Pure bash so it is testable anywhere.
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    # Drop remaining C0 control characters.
    s="$(printf '%s' "$s" | LC_ALL=C tr -d '\000-\010\013\014\016-\037')"
    printf '%s' "$s"
}

# [来源: App · title · url · time], skipping empty parts.
build_context_line() {
    local app="$1" title="$2" url="$3" ts="$4"
    local out="" part
    for part in "$app" "$title" "$url" "$ts"; do
        [[ -z "$part" ]] && continue
        if [[ -z "$out" ]]; then out="$part"; else out="$out · $part"; fi
    done
    printf '[来源: %s]' "$out"
}

# Run ov detached; report failures via log + notification.
run_ov_background() {
    local route="$1"; shift
    (
        local out
        if out="$("$@" 2>&1)"; then
            log "ok route=$route"
        else
            log "fail route=$route output=$out"
            local first="${out%%$'\n'*}"
            [[ "$first" =~ \"message\":\"([^\"]*)\" ]] && first="${BASH_REMATCH[1]}"
            notify "记忆写入失败：${first:0:120}"
        fi
    ) </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
}

main() {
    # Declare before assign: bash 3.2 + set -u can misfire on combined local/expand.
    local ov with_context app text route
    ov="${POPCLIP_OPTION_OV_PATH:-$HOME/.local/bin/ov}"
    with_context="${POPCLIP_OPTION_WITH_CONTEXT:-1}"
    app="${POPCLIP_APP_NAME:-}"

    mkdir -p "$(dirname "$LOG_FILE")"
    text="$(trim "${POPCLIP_TEXT:-}")"
    route="$(classify "$text")"
    log "route=$route app=$app"

    [[ "$route" == empty ]] && exit 0

    if [[ ! -x "$ov" ]]; then
        log "error: ov not executable at $ov"
        notify "找不到 ov：${ov}，请在插件设置里修改路径"
        exit 2
    fi

    local reason="Saved via PopClip${app:+ from $app}"
    case "$route" in
        path)
            run_ov_background path "$ov" add-resource "$(normalize_path "$text")" --reason "$reason"
            ;;
        url)
            run_ov_background url "$ov" add-resource "$text" --reason "$reason"
            ;;
        memory)
            local content="$text"
            if [[ "$with_context" == 1 ]]; then
                local ctx
                ctx="$(build_context_line "$app" "${POPCLIP_BROWSER_TITLE:-}" "${POPCLIP_BROWSER_URL:-}" "$(date '+%Y-%m-%d %H:%M')")"
                content="$ctx"$'\n'"$text"
            fi
            run_ov_background memory "$ov" add-memory "{\"role\":\"user\",\"content\":\"$(json_escape "$content")\"}"
            ;;
    esac
}

if [[ -z "${REMEMBER_TEST_MODE:-}" ]]; then
    main "$@"
fi
