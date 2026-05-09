# Mermaid Detection & Rendering for Snipaste Float

Date: 2026-05-09
Scope: `SnipasteFloat.popclipext/snipaste-float.sh`

## Summary

Extend Snipaste Float so that when the selected text looks like a Mermaid diagram,
the script renders it to a PNG via `mmdc` and pins the PNG via Snipaste — instead
of pinning the raw source as plain text.

## Detection

A new branch runs **before** the existing HTML branch, at the top of `main()`'s
dispatch chain.

It is a first-line keyword whitelist match against `$full_text`:

1. `trim` the input.
2. Take everything up to the first newline.
3. Lowercase the result.
4. Match against the alternation:

   ```
   flowchart | graph | sequencediagram | classdiagram |
   statediagram | statediagram-v2 | erdiagram | gantt | pie
   ```

   Trailing arguments are allowed (`flowchart TD`, `graph LR`, `gantt`).

If the first line does not match, the dispatch falls through unchanged to the
existing HTML / image-file / image-URL / plain-text chain.

The whitelist is intentionally narrow. It excludes less-common diagram types
(journey, mindmap, timeline, gitGraph, quadrantChart, requirementDiagram,
C4Context, sankey-beta, xychart-beta) to keep false-positives low. Adding more
keywords later is a one-line change.

We do **not** strip surrounding ` ```mermaid ` code fences. Users selecting from
a markdown source typically select the inner block; supporting the fenced form
adds complexity for a niche case.

## Rendering pipeline

On a positive detection, `try_render_mermaid` runs:

1. Generate a timestamped pair of temp paths under `/tmp/`:
   - input: `/tmp/snipaste-float-${ts}.mmd` (the full selection)
   - output: `/tmp/snipaste-float-${ts}.png`
2. Write `$full_text` to the input file.
3. Invoke `mmdc` with hardcoded defaults:
   ```
   mmdc -i <input> -o <output> -t default -b white -s 2 --quiet
   ```
   Wrap the call in a 15-second timeout. mmdc 11.x launches puppeteer/Chromium
   on every invocation, which can take 5–8s on a cold start; 15s gives
   reasonable headroom while still bounding hangs.
4. If `mmdc` exits non-zero, times out, or the output file is empty, return 1.
5. On success, register a cleanup `trap` for both temp files and call
   `run_snipaste paste --files <output>`. Return 0.

`main()` becomes:

```bash
if is_mermaid_first_line "$full_text"; then
    if try_render_mermaid "$full_text"; then
        return 0
    fi
    log "mermaid render failed; falling back"
    # fall through to the existing chain
fi
```

## Hardcoded render defaults

No `Config.popclipext` changes — the plugin stays zero-config.

| Knob          | Value      | Why                                                                 |
| ------------- | ---------- | ------------------------------------------------------------------- |
| theme         | `default`  | Mermaid's standard look, neutral on light backgrounds.              |
| background    | `white`    | Snipaste preview/pin uses a checkerboard; transparent looks messy.  |
| output format | `png`      | Snipaste's image pin handles PNG reliably; SVG support is uneven.   |
| scale         | `2`        | Hi-DPI sharpness on Retina displays.                                |

If users later ask for control, we expose them as Config keys then.

## Failure handling

Every failure mode is silent and falls through to the existing dispatch:

- `mmdc` not on `PATH` → `command -v mmdc` returns 1 → return 1.
- `mmdc` exits non-zero (bad syntax, network for icon packs, etc.) → return 1.
- `mmdc` times out (15s) → return 1.
- Output file missing or empty → return 1.

In each case, `try_render_mermaid` logs the reason to
`/tmp/snipaste-float.log` and returns 1. Control returns to `main`, which
proceeds with the existing HTML → image-file → image-URL → plain-text chain.
Since HTML is empty for plain-text selections (the most common path that
reaches mermaid), this almost always lands on `paste --plain`.

No `osascript display dialog` here — the user gets a working text float,
not an error popup.

## Cleanup

The existing opportunistic cleanup at the bottom of the script
(`find /tmp -name 'snipaste-float-*' -type f -mtime +1 -delete`) already
covers `.mmd` and `.png` files because they share the prefix.

## File changes

- `SnipasteFloat.popclipext/snipaste-float.sh`:
  - Add `is_mermaid_first_line` helper.
  - Add `try_render_mermaid` helper.
  - Insert the mermaid branch as the first dispatch step in `main`.
- `README.md`:
  - Append mermaid auto-rendering to the SnipasteFloat feature list (EN + ZH).
  - Note that `mmdc` (`@mermaid-js/mermaid-cli`) is an optional dependency;
    if absent, the plugin silently falls back to plain-text float.

No changes to `Config.popclipext`.

## Testing

Manual on macOS, since the repo has no test framework:

1. Positive: select `flowchart TD\nA --> B` → expect a floating PNG.
2. Negative (real code): select `class Foo {}` (Java) → expect plain-text float.
3. Render failure: select `flowchart TD\nA --> [bad` → expect plain-text float
   (silent fallback).
4. Missing dep: temporarily rename `mmdc` on PATH → expect plain-text float.
5. Regression: existing HTML / image-path / image-URL / plain-text flows
   unchanged.
