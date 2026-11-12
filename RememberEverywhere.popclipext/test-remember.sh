#!/bin/bash
# Standalone tests for remember.sh. Uses a fake ov and a stubbed notifier.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "$TMPDIR/test-remember-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export REMEMBER_LOG_FILE="$WORK/remember.log"
export REMEMBER_NOTIFY_CMD="$WORK/fake-notify"
REMEMBER_TEST_MODE=1 source "$DIR/remember.sh"

pass=0
fail=0

check() {
    local label="$1" got="$2" want="$3"
    if [[ "$got" == "$want" ]]; then
        printf 'PASS: %s\n' "$label"; pass=$((pass+1))
    else
        printf 'FAIL: %s\n  want: %s\n  got:  %s\n' "$label" "$want" "$got"; fail=$((fail+1))
    fi
}

# --- json_escape -------------------------------------------------------
check "escape quotes"     "$(json_escape 'say "hi"')"        'say \"hi\"'
check "escape backslash"  "$(json_escape 'a\b')"             'a\\b'
check "escape newline"    "$(json_escape $'a\nb')"           'a\nb'
check "escape tab/cr"     "$(json_escape $'a\tb\rc')"        'a\tb\rc'
check "keep CJK"          "$(json_escape '中文 记忆')"        '中文 记忆'
check "drop control char" "$(json_escape $'a\x01b')"         'ab'

# --- classify ----------------------------------------------------------
touch "$WORK/file with space.md"
check "existing file"        "$(classify "$WORK/file with space.md")"  path
check "existing dir"         "$(classify "$WORK")"                     path
check "file:// path"         "$(classify "file://$WORK")"              path
check "tilde path"           "$(classify "~")"                         path
check "missing path"         "$(classify "/no/such/file.md")"          memory
check "url"                  "$(classify "https://example.com/a?b=1")" url
check "http url"             "$(classify "http://example.com")"        url
check "url inside text"      "$(classify "see https://example.com")"   memory
check "multi-line"           "$(classify $'line1\nline2')"             memory
check "plain text"           "$(classify "我的车牌号是京A12345")"       memory
check "empty"                "$(classify "")"                          empty
check "trim then empty"      "$(classify "$(trim $'  \n\t ')")"        empty

# --- build_context_line ------------------------------------------------
check "context full"  "$(build_context_line Chrome Title https://x.com '2026-11-12 10:00')" \
    '[来源: Chrome · Title · https://x.com · 2026-11-12 10:00]'
check "context no browser" "$(build_context_line Notes '' '' '2026-11-12 10:00')" \
    '[来源: Notes · 2026-11-12 10:00]'

# --- end-to-end with fake ov --------------------------------------------
FAKE_OV="$WORK/fake-ov"
cat > "$FAKE_OV" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$FAKE_OV_ARGS"
if [[ -n "${FAKE_OV_FAIL:-}" ]]; then
    echo '{"ok":false,"error":{"code":"UNAVAILABLE","message":"server down"}}'
    exit 1
fi
echo '{"ok":true,"result":"OK"}'
EOF
cat > "$REMEMBER_NOTIFY_CMD" <<EOF
#!/bin/bash
printf '%s\n' "\$2" > "$WORK/notified"
EOF
chmod +x "$FAKE_OV" "$REMEMBER_NOTIFY_CMD"
export FAKE_OV_ARGS="$WORK/args"

# Run main in a subshell, then wait for the background ov call to finish.
run_main() {
    rm -f "$FAKE_OV_ARGS" "$WORK/notified"
    ( POPCLIP_OPTION_OV_PATH="$FAKE_OV" POPCLIP_TEXT="$1" POPCLIP_APP_NAME="${2:-}" \
      POPCLIP_OPTION_WITH_CONTEXT="${3:-1}" main )
    local rc=$? i
    for i in $(seq 1 50); do
        [[ -f "$FAKE_OV_ARGS" ]] && break
        sleep 0.1
    done
    sleep 0.2
    return $rc
}

run_main "  $WORK/file with space.md  " Terminal
check "e2e path argv" "$(cat "$FAKE_OV_ARGS")" \
    "$(printf '%s\n' add-resource "$WORK/file with space.md" --reason 'Saved via PopClip from Terminal')"

run_main "https://example.com/post" Safari
check "e2e url argv" "$(cat "$FAKE_OV_ARGS")" \
    "$(printf '%s\n' add-resource https://example.com/post --reason 'Saved via PopClip from Safari')"

run_main '{"k": "v"}' Notes 0
check "e2e memory json, no context" "$(cat "$FAKE_OV_ARGS")" \
    "$(printf '%s\n' add-memory '{"role":"user","content":"{\"k\": \"v\"}"}')"

run_main "明天下午三点开会" Lark 1
args="$(cat "$FAKE_OV_ARGS")"
check "e2e memory with context prefix" \
    "$([[ "$args" == 'add-memory'$'\n''{"role":"user","content":"[来源: Lark · '*'\n明天下午三点开会"}' ]] && echo ok)" ok

run_main "   "
check "e2e empty does nothing" "$([[ -f "$FAKE_OV_ARGS" ]] && echo called || echo skipped)" skipped

FAKE_OV_FAIL=1 run_main "something"
check "e2e failure notifies" "$(cat "$WORK/notified" 2>/dev/null)" \
    'display notification "记忆写入失败：server down" with title "Remember Everywhere"'
check "e2e failure logged" "$(grep -c 'fail route=memory' "$REMEMBER_LOG_FILE")" 1

( POPCLIP_OPTION_OV_PATH="$WORK/missing-ov" POPCLIP_TEXT="x" main )
check "missing ov exits 2" "$?" 2

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
