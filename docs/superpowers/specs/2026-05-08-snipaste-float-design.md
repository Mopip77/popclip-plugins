# Snipaste Float — Design Spec

**Date:** 2026-05-08
**Status:** Draft, awaiting implementation
**Author:** brainstormed with user

## Goal

Add a new PopClip extension named **Snipaste Float**. When the user selects content and clicks the button, the plugin classifies the selection (HTML / local image file / image URL / plain text) and pins it as a floating image on the desktop using the Snipaste CLI, picking the appropriate `Snipaste paste` argument for the detected type.

## Non-goals

- Configurable pin position (we let Snipaste pick)
- Configurable Snipaste path (hardcoded; future change is one-line)
- HTML detection from raw plain-text source (we rely on PopClip's captured `input.html` field, not regex sniffing)
- Recognizing non-image local files (PDFs, folders, etc. fall through to plain text)
- Automatic log rotation (defer; YAGNI)

## Plugin layout

```
SnipasteFloat.popclipext/
├── Config.popclipext        # YAML metadata
├── snipaste-icon.svg        # Plugin icon
└── snipaste-float.js        # Main module (PopClip JS runtime)
```

`Config.popclipext` fields:

```yaml
name: Snipaste Float
identifier: com.custom.snipastefloat
icon: snipaste-icon.svg
language: javascript
module: snipaste-float.js
requirements: [text]
options: []
# capture rich-text representations so classify() can read input.html
capture html: true
```

The YAML key is `capture html` (space-separated, not camelCase) — matches PopClip's documented convention and the existing plugins in this repo (`shell script file`, `default value`).

No user-facing options. The Snipaste binary path is a constant inside the JS file.

## Content classification

Uses PopClip's built-in input fields rather than regex parsing of raw text. Reference: <https://pilotmoon.github.io/popclip-types/interfaces/Input.html>.

Inputs we read:

- `popclip.input.text` — plain text fallback
- `popclip.input.html` — present only when the selection is rich-text and `captureHtml: true`
- `popclip.input.isUrl` — true when the entire selection is a URL (whitespace allowed)
- `popclip.input.data.paths` — PopClip-detected file paths in the selection
- `popclip.input.data.urls` — PopClip-detected http/https URLs

### Priority (first match wins)

1. **HTML fragment** — `popclip.input.html` is a non-empty string
   → `Snipaste paste --html <html>`

2. **Local image file** — `data.paths.length >= 1`, first path's extension is in the image set, and the file exists on disk
   → `Snipaste paste --files <path>`

3. **Image URL** — `isUrl === true` and the URL's path (query/fragment stripped) ends in an image extension
   → download with `curl -fsSL --max-time 10 -o /tmp/snipaste-float-<ts>.<ext> <url>`, then `Snipaste paste --files <tmpPath>`. Download failure is a hard error (no fallback to plain text).
   The URL string fed to `curl` comes from `popclip.input.data.urls[0]` if present, otherwise falls back to `popclip.input.text.trim()`. Picking one field consistently — don't read both.
   `<ext>` is the URL path's final extension, lowercased, used to keep the temp filename predictable.
   If `isUrl === true` but the URL does **not** end in an image extension, fall through to step 4 (the URL string is floated as plain text).

4. **Plain text fallback** — everything else
   → `Snipaste paste --plain <text>`

Image extension set (case-insensitive): `png, jpg, jpeg, gif, webp, bmp, tiff, heic, svg`.

Path normalization before the file-exists check:
- Strip a leading `file://` prefix
- Expand a leading `~/` to `$HOME/`

### Why this is robust

- HTML detection: we never false-positive on plain text that happens to mention `<div>` — `input.html` is only populated when the selection source is genuinely rich text.
- Local-image detection: PopClip's data detector only reports `data.paths` when the selection is *just* a path, so we don't false-positive on a sentence containing `/foo/bar.png`.
- Image-URL detection: same — `isUrl` requires the whole selection to be a URL.

## Module structure

`snipaste-float.js` exports a single `action` function. Internal layout:

```
action(input)
  ├── log("start ...")
  ├── try
  │     const decision = classify(input, deps)
  │     log("decision: " + decision.kind)
  │     dispatch(decision)
  └── catch (e)
        popclip.showText(userMessage(e))
        log("error: " + e.message + "\n" + e.stack)
```

### Functions

- **`classify(input, { fileExists, isImageExt })` → `{ kind, payload }`**
  Pure function. `kind` is one of `"html" | "imageFile" | "imageUrl" | "text"`. Payload shapes:
  - `html`: `{ html: string }`
  - `imageFile`: `{ path: string }` (already normalized)
  - `imageUrl`: `{ url: string, ext: string }`
  - `text`: `{ text: string }`
  Dependencies (`fileExists`, `isImageExt`) injected so self-test can stub them.

- **`dispatch({ kind, payload })`** — switches on `kind`, calls the matching paste function.

- **`pasteHtml(html)`** → `runSnipaste(["paste", "--html", html])`
- **`pasteImageFile(path)`** → `runSnipaste(["paste", "--files", path])`
- **`pasteImageUrl(url, ext)`** → calls `downloadImage(url, ext)`, then `pasteImageFile(tmpPath)`
- **`pastePlain(text)`** → `runSnipaste(["paste", "--plain", text])`

- **`downloadImage(url, ext)` → `string` (path)**
  Calls `curl -fsSL --max-time 10 -o <tmpPath> <url>` via `popclip.executeShellCommand`. Throws `DownloadError` on non-zero exit or zero-byte file.

- **`runSnipaste(args)` → `void`**
  Calls `popclip.executeShellCommand(SNIPASTE_BIN, args)`. Argv-form (no shell), so user content cannot inject commands. Non-zero exit → throws `SnipasteError` with stderr.

- **`isImageExt(ext)` → `boolean`** — pure function over the image extension set.

- **`fileExists(path)` → `boolean`** — `executeShellCommand("test", ["-f", path])`, exit 0 means yes.

- **`log(message)`** — appends `[ISO-timestamp] <message>` (one per line) to `/tmp/snipaste-float.log` via `executeShellCommand("/bin/sh", ["-c", "printf '%s\\n' \"$1\" >> /tmp/snipaste-float.log", "--", line])`. Note the literal `\n` in the printf format string must survive into shell — use double-quoted JS with `\\n`, or single-quoted JS that contains the unescaped `\n` for shell to interpret. Implementer: verify the resulting log file actually has line breaks.

- **`userMessage(error)`** — maps internal error types to short user-facing strings shown via `popclip.showText`:
  - `SnipasteNotInstalledError` → `"Snipaste 未安装或路径不对"`
  - `SnipasteError` → `"Snipaste 调用失败"`
  - `DownloadError` → `"图片下载失败"`
  - other → `"处理失败"`

### Constants

```js
const SNIPASTE_BIN = "/Applications/Snipaste.app/Contents/MacOS/Snipaste";
const LOG_FILE = "/tmp/snipaste-float.log";
const IMAGE_EXTS = new Set(["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic", "svg"]);
const DOWNLOAD_TIMEOUT_SECONDS = 10;
```

### Why JS over shell

Selected by user for future extensibility. Concrete benefits over a shell version:

- `popclip.executeShellCommand(bin, argv)` takes argv as an array → no shell quoting, no command injection on user content (which can contain quotes, backticks, `$`, newlines).
- Direct access to `popclip.input.html`, `input.data.*`, `input.isUrl` without re-parsing.
- `popclip.showText` for native lightweight feedback (vs. spawning `osascript`).
- Cleaner branching for the four content types.

## Error handling

| Source | Action |
|---|---|
| Snipaste binary missing (ENOENT-class) | `showText("Snipaste 未安装或路径不对")`, log |
| `runSnipaste` non-zero exit | `showText("Snipaste 调用失败")`, log stderr |
| Image download fails (curl non-zero or zero-byte file) | `showText("图片下载失败")`, log |
| Path detected but `test -f` fails | **Not an error** — fall through to plain text in classify() |
| `classify` throws (shouldn't happen in practice) | `showText("处理失败")`, log stack |

All errors are caught in `action`'s top-level try/catch. Inner functions throw typed errors; `userMessage` translates to user-facing strings. No silent failures.

## Logging

- File: `/tmp/snipaste-float.log`
- Format: `[ISO-timestamp] <message>` per line
- Written at: entry (input summary), classify decision, error
- **Not** written on success (reduces IO; on failure we still see the prior trace lines)

No rotation. Future enhancement if needed.

## Testing strategy

### Unit (self-test)

`classify` is a pure function and can be exercised in Node directly. Add a guard:

```js
if (typeof require !== "undefined" && typeof module !== "undefined" && require.main === module) {
  runSelfTest();
}
```

PopClip's JS runtime is a custom sandbox (not Node) and does not define a Node-style `require` / `module`, so this block stays dormant in production. Implementer: during first install, verify by checking `/tmp/snipaste-float.log` shows the action ran and **not** the self-test output.

`runSelfTest()` covers:

| Input | Expected `kind` |
|---|---|
| `{ text: "hello", html: "" }` | `text` |
| `{ text: "hello", html: "<b>hello</b>" }` | `html` |
| `{ text: "/x/a.png", data: { paths: ["/x/a.png"] } }` + fake fileExists=true | `imageFile` |
| `{ text: "/x/missing.png", data: { paths: ["/x/missing.png"] } }` + fake fileExists=false | `text` |
| `{ text: "/x/foo.txt", data: { paths: ["/x/foo.txt"] } }` | `text` |
| `{ text: "https://x.com/a.png", isUrl: true, data: { urls: ["https://x.com/a.png"] } }` | `imageUrl` |
| `{ text: "https://example.com", isUrl: true, data: { urls: ["https://example.com"] } }` | `text` |
| `{ text: "see <div>", html: "" }` | `text` |

Run via `node SnipasteFloat.popclipext/snipaste-float.js --self-test`. Failure prints diff and exits non-zero.

### Manual integration checklist

After installing the plugin, verify each of the following selects correctly:

1. Plain paragraph → text float
2. Rich text from a webpage → HTML-rendered float
3. A path to a local image file in plain text → image float
4. An image URL like `https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png` → downloaded and floated
5. A non-image URL (e.g. `https://example.com`) → text float (the URL string)
6. Temporarily break `SNIPASTE_BIN` constant → expect `popclip.showText("Snipaste 未安装...")` and a log entry

### Out of scope

- No jest/vitest. Single file, dependency-injected pure function — overhead not worth it.
- No mocked PopClip sandbox. The action entry uses real `popclip.executeShellCommand` in production; self-test exercises `classify` only.

## README updates

Add a new section to `README.md` (English + Chinese) describing Snipaste Float alongside the existing three plugins:

- What it does (selection → floating pin via Snipaste)
- Type detection summary (HTML / image file / image URL / plain text)
- Dependency: Snipaste installed at `/Applications/Snipaste.app`
- No configuration options

## Open questions / future work

None blocking. Possible future extensions explicitly noted as out-of-scope right now:

- Position control (`--pos X Y` config option)
- Configurable Snipaste path
- Configurable download timeout
- Markdown rendering (`input.markdown` exists when `captureHtml: true`; could become a 5th branch)
- Log rotation
