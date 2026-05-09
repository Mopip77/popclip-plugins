# Mermaid Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect Mermaid diagram source in the PopClip selection and pin a rendered PNG via Snipaste, instead of pinning the raw text.

**Architecture:** Two new shell helpers — `is_mermaid_first_line` (pure detection, side-effect free) and `try_render_mermaid` (renders via `mmdc`, pins via Snipaste, returns 0/1) — added to `SnipasteFloat.popclipext/snipaste-float.sh`. The mermaid branch is inserted as the first dispatch step in `main()`; on any failure (missing binary, render error, timeout, empty output), the function returns 1 and `main()` falls through to the existing HTML → image-file → image-URL → plain-text chain. No Config changes.

**Tech Stack:** Bash 3.2 (macOS default, same as existing script), `mmdc` (`@mermaid-js/mermaid-cli`) for rendering, `/usr/bin/perl alarm` for the 15s timeout (macOS has no `timeout(1)`).

**Spec:** `docs/superpowers/specs/2026-05-09-mermaid-detection-design.md`

**Note on TDD:** This repo has no test framework. Detection logic gets a small standalone bash test script (run with `bash`, not pytest); rendering and end-to-end behaviour are verified manually against the matrix at the end of this plan. Each task still follows the test-or-verify-then-commit rhythm.

---

## File Structure

Files this plan creates or modifies:

- **Modify** `SnipasteFloat.popclipext/snipaste-float.sh` — add two helpers and one branch in `main()`. No restructuring of existing code.
- **Create** `SnipasteFloat.popclipext/test-detect.sh` — standalone, self-contained test for `is_mermaid_first_line`. Runnable with `bash SnipasteFloat.popclipext/test-detect.sh`. Stays in the repo as a regression check.
- **Modify** `README.md` — append a one-bullet mermaid line to the SnipasteFloat sections (EN + ZH); note `mmdc` as an optional dependency.

No new directories. No Config changes.

---

## Task 1: Add and test `is_mermaid_first_line` helper

This is the only piece worth automated testing — pure string logic, no side effects.

**Files:**
- Create: `SnipasteFloat.popclipext/test-detect.sh`
- Modify: `SnipasteFloat.popclipext/snipaste-float.sh` (add helper near the other helpers, before `main()`)

- [ ] **Step 1: Write the failing test script**

Create `SnipasteFloat.popclipext/test-detect.sh` with this exact content:

```bash
#!/bin/bash
# Standalone test for is_mermaid_first_line. Source the script under test.
set -u

# Source-only mode: prevent main() from running when we source the script.
SNIPASTE_FLOAT_TEST_MODE=1 source "$(dirname "$0")/snipaste-float.sh"

pass=0
fail=0

assert_match() {
    local label="$1" input="$2"
    if is_mermaid_first_line "$input"; then
        printf 'PASS: %s\n' "$label"; pass=$((pass+1))
    else
        printf 'FAIL: %s (expected match)\n' "$label"; fail=$((fail+1))
    fi
}

assert_no_match() {
    local label="$1" input="$2"
    if is_mermaid_first_line "$input"; then
        printf 'FAIL: %s (expected no match)\n' "$label"; fail=$((fail+1))
    else
        printf 'PASS: %s\n' "$label"; pass=$((pass+1))
    fi
}

# Positive cases.
assert_match "flowchart with direction"  $'flowchart TD\nA --> B'
assert_match "graph LR"                  $'graph LR\nA --> B'
assert_match "sequenceDiagram"           $'sequenceDiagram\nAlice->>Bob: hi'
assert_match "classDiagram"              $'classDiagram\nclass Foo'
assert_match "stateDiagram"              $'stateDiagram\n[*] --> S1'
assert_match "stateDiagram-v2"           $'stateDiagram-v2\n[*] --> S1'
assert_match "erDiagram"                 $'erDiagram\nCUSTOMER ||--o{ ORDER : places'
assert_match "gantt"                     $'gantt\ntitle My Plan'
assert_match "pie"                       $'pie\n"A" : 50\n"B" : 50'
assert_match "leading whitespace"        $'   flowchart TD\nA --> B'
assert_match "uppercase keyword"         $'FLOWCHART TD\nA --> B'
assert_match "trailing whitespace on kw" $'flowchart   \nA --> B'

# Negative cases.
assert_no_match "java class"             $'class Foo {\n}'
assert_no_match "empty"                  ""
assert_no_match "mindmap (not in list)"  $'mindmap\nroot((x))'
assert_no_match "fenced block"           $'```mermaid\nflowchart TD\nA --> B\n```'
assert_no_match "leading text"           $'Some preamble\nflowchart TD'

# Note: english prose starting with "graph " (e.g. "graph theory is the
# study of graphs") will match here. That is by design — the rule is
# strictly "first-line starts with keyword". Such selections fail mmdc
# render and fall through to plain-text pinning, so the user-visible
# behaviour is correct, just with a small extra mmdc-startup latency.

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `bash SnipasteFloat.popclipext/test-detect.sh`
Expected: fails immediately with something like `is_mermaid_first_line: command not found` (helper does not exist yet) or — if the source line itself errors because `SNIPASTE_FLOAT_TEST_MODE` is not yet honoured — a stack of dispatch noise. Either failure mode is acceptable; we are about to fix both.

- [ ] **Step 3: Add the helper to `snipaste-float.sh`**

> **Important:** Do **not** call the existing `trim()` helper from this code. `trim()` is buggy (it eats whole tokens for inputs without surrounding whitespace) and the bug is out of scope for this plan. The new helper does its own first-line extraction and whitespace stripping inline.

Open `SnipasteFloat.popclipext/snipaste-float.sh`. Insert this helper **after** the `trim()` function (around line 67, before `main()`):

```bash
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
```

The leading-whitespace strip uses `${var#pattern}` where `pattern` is the longest prefix of `$first_line` that is purely space-or-tab — `${first_line%%[^ $'\t']*}` returns everything up to the first non-whitespace character. The trailing strip is the symmetric form. The pattern `keyword|keyword\ *|keyword$'\t'*` covers (a) keyword alone, (b) keyword followed by space and args, (c) keyword followed by tab and args.

- [ ] **Step 4: Make the script source-able for tests**

Still in `snipaste-float.sh`, find the very bottom of the file. Currently it ends with:

```bash
# Clean up old tmp files (>1 day) opportunistically; ignore errors.
find /tmp -name 'snipaste-float-*' -type f -mtime +1 -delete 2>/dev/null || true

main "$@"
```

Wrap the last two effectful actions so sourcing skips them. Replace those final lines with:

```bash
if [[ -z "${SNIPASTE_FLOAT_TEST_MODE:-}" ]]; then
    # Clean up old tmp files (>1 day) opportunistically; ignore errors.
    find /tmp -name 'snipaste-float-*' -type f -mtime +1 -delete 2>/dev/null || true
    main "$@"
fi
```

This is the minimum change to make `source` safe; production behaviour (no env var set) is identical.

- [ ] **Step 5: Run the test and confirm it passes**

Run: `bash SnipasteFloat.popclipext/test-detect.sh`
Expected: every line says `PASS:` and the final summary reads `17 passed, 0 failed`. Exit code 0.

If any case fails, the most likely culprit is the `case` arm spacing (the `\ ` is a literal space — make sure the editor did not strip it).

- [ ] **Step 6: Commit**

```bash
git add SnipasteFloat.popclipext/snipaste-float.sh SnipasteFloat.popclipext/test-detect.sh
git commit -m "feat(snipaste-float): add mermaid first-line detection

Pure-detection helper plus a standalone bash test script. No dispatch
wiring yet — that comes next."
```

---

## Task 2: Add `try_render_mermaid` helper (no wiring yet)

Renders a Mermaid string to PNG and pins it via Snipaste. Returns 0 on success, 1 on any failure. We add the helper but do not wire it into `main()` until the next task — keeps the diff small and the rollback obvious.

**Files:**
- Modify: `SnipasteFloat.popclipext/snipaste-float.sh`

- [ ] **Step 1: Add the helper**

In `snipaste-float.sh`, immediately after `is_mermaid_first_line` (still before `main()`), insert:

```bash
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
```

Notes for the implementer:
- `command -v mmdc` is the very first check — we don't want to create a `.mmd` temp file if the binary is missing.
- The `perl alarm` pattern is intentional. Do **not** substitute `timeout 15 mmdc …` — `timeout(1)` is not on stock macOS.
- The `trap` is set only on the success path. The failure paths clean up inline because we don't want to leave a trap that would later try to delete files we already removed. (`rm -f` on missing files is harmless, so the duplication is benign — but the clearer intent is "trap is for the post-success exit".)

- [ ] **Step 2: Sanity-check it parses**

Run: `bash -n SnipasteFloat.popclipext/snipaste-float.sh`
Expected: no output, exit code 0. (Bash parse-only check; no execution.)

- [ ] **Step 3: Re-run the detection test**

Run: `bash SnipasteFloat.popclipext/test-detect.sh`
Expected: still `17 passed, 0 failed`. The new helper should not have disturbed `is_mermaid_first_line`.

- [ ] **Step 4: Commit**

```bash
git add SnipasteFloat.popclipext/snipaste-float.sh
git commit -m "feat(snipaste-float): add mermaid render helper

Renders Mermaid source to PNG via mmdc with a perl-alarm timeout, then
pins via Snipaste. Not wired into main() yet — that's the next commit."
```

---

## Task 3: Wire the mermaid branch into `main()`

**Files:**
- Modify: `SnipasteFloat.popclipext/snipaste-float.sh`

- [ ] **Step 1: Insert the branch as the first dispatch step**

In `main()`, find this block (around line 76-82):

```bash
    # --- 1. HTML branch -------------------------------------------------
    if [[ -n "$html" ]]; then
        log "decision: html"
        run_snipaste paste --html "$html"
        log "done"
        return 0
    fi
```

Insert this **before** that block (so it becomes the new step 1; renumber the existing comments by hand):

```bash
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

```

Then renumber the existing comment headers:
- `# --- 1. HTML branch ---` → `# --- 2. HTML branch ---`
- `# --- 2. Local image file branch ---` → `# --- 3. Local image file branch ---`
- `# --- 3. Image URL branch ---` → `# --- 4. Image URL branch ---`
- `# --- 4. Plain text fallback ---` → `# --- 5. Plain text fallback ---`

Also update the file-level header comment on line 3 (currently
`# Detection priority: HTML → local image file → image URL → plain text.`) to:

```
# Detection priority: Mermaid → HTML → local image file → image URL → plain text.
```

These are comment-only changes but worth doing so future readers see an accurate dispatch order at the top of the file.

- [ ] **Step 2: Parse-check**

Run: `bash -n SnipasteFloat.popclipext/snipaste-float.sh`
Expected: no output, exit code 0.

- [ ] **Step 3: Run detection test again**

Run: `bash SnipasteFloat.popclipext/test-detect.sh`
Expected: `17 passed, 0 failed`.

- [ ] **Step 4: Smoke-test the end-to-end happy path**

You need Snipaste running for this. From the repo root:

```bash
POPCLIP_TEXT=$'flowchart TD\nA --> B\nB --> C' \
POPCLIP_FULL_TEXT=$'flowchart TD\nA --> B\nB --> C' \
bash SnipasteFloat.popclipext/snipaste-float.sh
```

Expected:
- A floating PNG appears on the desktop showing the rendered flowchart.
- `/tmp/snipaste-float.log` ends with lines mentioning `decision: mermaid`, `mermaid: rendering`, `mermaid: pinning`, and `done`.
- After the script exits, `/tmp/snipaste-float-*.mmd` and `/tmp/snipaste-float-*.png` from this run are gone (the `trap` cleaned them up).

If Snipaste pins the raw text instead of an image, check that:
- `mmdc` is on PATH (`command -v mmdc`).
- The log shows `decision: mermaid (attempting render)` — if not, detection didn't fire and the fix belongs in Task 1.

- [ ] **Step 5: Smoke-test silent fallback (render failure)**

```bash
POPCLIP_TEXT=$'flowchart TD\nA --> [bad syntax' \
POPCLIP_FULL_TEXT=$'flowchart TD\nA --> [bad syntax' \
bash SnipasteFloat.popclipext/snipaste-float.sh
```

Expected:
- A floating **text** pin appears (the broken Mermaid source as plain text).
- Log shows `decision: mermaid (attempting render)`, then `mermaid: mmdc failed or timed out`, then `mermaid render failed; falling through`, then `decision: text`, then `done`.
- No osascript dialog popped up.

- [ ] **Step 6: Smoke-test missing dependency**

Temporarily hide `mmdc`:

```bash
PATH="/usr/bin:/bin" \
POPCLIP_TEXT=$'flowchart TD\nA --> B' \
POPCLIP_FULL_TEXT=$'flowchart TD\nA --> B' \
bash SnipasteFloat.popclipext/snipaste-float.sh
```

Expected:
- Floating text pin (the Mermaid source as plain text).
- Log shows `mermaid: mmdc not found on PATH, skipping render` followed by the fallback chain.

- [ ] **Step 7: Smoke-test that an unrelated selection is unaffected**

```bash
POPCLIP_TEXT="just some words" \
POPCLIP_FULL_TEXT="just some words" \
bash SnipasteFloat.popclipext/snipaste-float.sh
```

Expected:
- Floating text pin "just some words".
- Log shows `decision: text` directly (no mermaid lines).

- [ ] **Step 8: Commit**

```bash
git add SnipasteFloat.popclipext/snipaste-float.sh
git commit -m "feat(snipaste-float): dispatch mermaid before plain text

Mermaid source now renders to PNG and floats as an image. Any failure
silently falls through to the existing chain."
```

---

## Task 4: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Locate the SnipasteFloat sections**

Open `README.md`. There are two SnipasteFloat blocks: one under `## English`, one under `## 中文说明` (search for "Snipaste Float" and you'll find both).

- [ ] **Step 2: Add mermaid bullet to the English section**

In the English `Features:` list (currently four bullets: plain text, rich text, local image, image URL), add a fifth bullet **before** the `Detection priority:` line:

```markdown
  - Mermaid source (lines starting with `flowchart`, `graph`, `sequenceDiagram`, etc.) → rendered PNG pin
```

Then update `Detection priority:` to:

```markdown
- **Detection priority:** Mermaid → HTML → local image file → image URL → plain text (fallback)
```

Add to the `Dependency:` line so it now reads:

```markdown
- **Dependencies:** [Snipaste](https://www.snipaste.com/) installed at `/Applications/Snipaste.app`. Optional: [`mmdc`](https://github.com/mermaid-js/mermaid-cli) (`@mermaid-js/mermaid-cli`) on `PATH` for Mermaid rendering — without it, Mermaid selections silently fall back to plain-text float.
```

- [ ] **Step 3: Mirror in the 中文 section**

In the 中文 SnipasteFloat block, do the same three edits using natural Chinese — match the tone of the surrounding bullets. Suggested phrasing:

- New feature bullet: `Mermaid 源码（以 \`flowchart\`、\`graph\`、\`sequenceDiagram\` 等开头）→ 渲染为 PNG 后悬浮`
- Detection-priority line: `检测优先级： Mermaid → HTML → 本地图片 → 图片 URL → 纯文本（兜底）`
- Dependency line: `依赖： [Snipaste](https://www.snipaste.com/) 安装在 \`/Applications/Snipaste.app\`。可选：[\`mmdc\`](https://github.com/mermaid-js/mermaid-cli)（\`@mermaid-js/mermaid-cli\`）在 \`PATH\` 上 — 缺失时 Mermaid 选区会静默回退为纯文本悬浮。`

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document mermaid auto-rendering in Snipaste Float"
```

---

## Manual verification matrix (run before declaring done)

These are the spec's testing checklist, run end-to-end with Snipaste actually open. Tick each one:

- [ ] **1. Positive — flowchart:** Select `flowchart TD\nA --> B` in any app, click the PopClip Snipaste Float button → floating PNG of the diagram appears.
- [ ] **2. Positive — sequence:** Select `sequenceDiagram\nAlice->>Bob: hi` → floating PNG.
- [ ] **3. Negative — Java code:** Select `class Foo {\n}` (real Java) → floating **text** pin (not an image).
- [ ] **4. Render-then-fallback — english prose starting with "graph ":** Select `graph theory is the study of graphs` → floating **text** pin (the keyword whitelist matches, but mmdc fails to render and we fall through silently). This is expected; verify there is no error dialog and the user-visible result is a text pin.
- [ ] **5. Render failure:** Select `flowchart TD\nA --> [bad` → floating text pin (silent fallback). No error dialog.
- [ ] **6. Missing dep:** Temporarily `chmod -x $(command -v mmdc)` (or rename it), select `flowchart TD\nA --> B`, restore mmdc afterward → floating text pin during the test.
- [ ] **7. Regression — HTML:** In a browser, select rich text (a paragraph with bold/links) → floating HTML render. Unchanged.
- [ ] **8. Regression — local image:** In Finder column-view-as-text or a path-string-only context, select `/path/to/some.png` → floating image pin.
- [ ] **9. Regression — image URL:** Select a single `https://…/foo.png` URL → floating image pin (downloaded).
- [ ] **10. Regression — plain text:** Select arbitrary text → floating text pin.

If any of #1–#10 fails, log the failure mode against the relevant task and re-open it before reporting done.
