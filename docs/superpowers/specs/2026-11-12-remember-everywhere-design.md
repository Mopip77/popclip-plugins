# Remember Everywhere — Design Spec

**Date:** 2026-11-12
**Status:** Approved, implementing
**Author:** brainstormed with user

## Goal

A PopClip extension: select something, click once, and it lands in OpenViking (OV) via the `ov` CLI. Routing is rule-based (no LLM call in the plugin); semantic categorisation of memories (identity / preferences / entities / events) is left to OV's server-side extraction.

## Non-goals

- Custom intent routing / prompts (OV extraction already classifies)
- Sending todos to TickTick or other systems
- Per-peer routing (work vs. personal)
- Success notifications (PopClip's ✓ is enough)
- Selecting files in Finder (PopClip only triggers on text; a Finder Quick Action would be a separate project)
- Keeping HTML/Markdown formatting (`capture html` is not used)

## Plugin layout

```
RememberEverywhere.popclipext/
├── Config.popclipext      # YAML metadata
├── remember.sh            # Main script
├── remember-icon.svg      # Icon
└── test-remember.sh       # Standalone tests (fake ov)
```

`Config.popclipext`:

```yaml
name: Remember Everywhere
identifier: com.custom.remembereverywhere
icon: remember-icon.svg
language: shell
shell script file: remember.sh
requirements: [text]
options:
  - identifier: ov_path        # absolute path, PopClip's PATH is minimal
    default value: /Users/bjhl/.local/bin/ov
  - identifier: with_context   # boolean, default on
```

One button, routing inside the script — splitting into several actions via `requirements` would show 2–3 buttons for a single URL selection.

## Routing (first match wins)

Input: `POPCLIP_TEXT`, trimmed of surrounding whitespace.

| # | Condition | Command |
|---|---|---|
| 0 | Empty after trim | exit 0, do nothing |
| 1 | Single line, `~`/`file://` normalised, path exists (`-e`) | `ov add-resource <abs path> --reason "<reason>"` |
| 2 | Single line matching `^https?://[^[:space:]]+$` | `ov add-resource <url> --reason "<reason>"` |
| 3 | Anything else | `ov add-memory '<json message>'` |

`<reason>` is `Saved via PopClip from <App>`.

### Memory content (route 3)

When `with_context` is on, prepend one line:

```
[来源: <App> · <browser title> · <browser url> · <YYYY-MM-DD HH:MM>]
```

Empty parts (title/url outside browsers) are omitted.

The content is always sent as a JSON message `{"role":"user","content":"..."}`. `ov add-memory` parses a bare argument starting with `{`/`[` as JSON, so a selected JSON snippet would otherwise be misinterpreted. JSON escaping is done in pure bash (`\\`, `"`, `\n`, `\r`, `\t`; other control chars dropped) so it is testable without external tools.

## Execution & feedback

- `ov` missing / not executable → notification + exit 2 (PopClip opens the options panel).
- Otherwise the `ov` call runs in a detached background subshell; the script exits 0 immediately and PopClip shows ✓.
- Background subshell: on non-zero exit, append the output to the log and post a macOS notification `记忆写入失败：<first line of error>` via `osascript display notification`.
- Log: `~/Library/Logs/remember-everywhere.log`, every invocation logs route + outcome (not the full text).

Measured: `ov add-memory` returns in ~0.6 s; errors come back as `{"ok":false,"error":{...}}` with exit 1.

## Testing

`test-remember.sh` sources `remember.sh` in test mode (`REMEMBER_TEST_MODE=1`, like SnipasteFloat) and checks:

- `json_escape` on quotes, backslashes, newlines, tabs, CJK
- `classify` returns `path` / `url` / `memory` / `empty` for representative inputs (existing file, `~` path, missing path, URL, URL with surrounding text, multi-line, blank)
- `build_context_line` omits empty parts

Then end-to-end with a fake `ov` (records argv, can be told to fail) to verify argv per route and the failure log/notification hook (notification command is stubbed).

Manual: one real `ov add-memory` through the script, confirm via `ov find`, delete the test memory.
