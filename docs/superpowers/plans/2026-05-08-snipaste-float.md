# Snipaste Float Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new PopClip extension `SnipasteFloat.popclipext` that classifies the current selection (HTML / local image / image URL / plain text) and floats it on the desktop using the Snipaste CLI.

**Architecture:** A single PopClip extension folder at the repo root, mirroring the existing three plugins. JavaScript module with a single exported `action` function. A pure `classify()` function (the only piece worth unit-testing) returns a typed decision; a thin `dispatch()` switches on the decision and calls one of four paste functions; all four go through one `runSnipaste()` helper. Errors are caught at the top level and shown via `popclip.showText`. Optional Node self-test at the bottom of the file, gated so PopClip's runtime never trips it.

**Tech Stack:** PopClip JS extension runtime; `popclip.executeShellCommand` for the Snipaste CLI, `curl`, `test -f`, and `printf`-to-log; Node (host machine) for the self-test only.

**Spec:** `docs/superpowers/specs/2026-05-08-snipaste-float-design.md`

---

## File Structure

Files this plan creates or modifies:

- **Create** `SnipasteFloat.popclipext/Config.popclipext` — PopClip YAML metadata (name, identifier, language, module, requirements, `capture html: true`).
- **Create** `SnipasteFloat.popclipext/snipaste-icon.svg` — plugin icon (text-only placeholder; user can swap later).
- **Create** `SnipasteFloat.popclipext/snipaste-float.js` — single-file JS module: constants, `classify()`, `dispatch()`, four paste functions, `runSnipaste()`, `downloadImage()`, `log()`, `userMessage()`, exported `action`, and a guarded self-test block at the bottom.
- **Modify** `README.md` — add a "Snipaste Float" section to both the English and 中文 plugin lists, mirroring the format used by the other three plugins.

That's the entire surface. No build tooling, no `package.json`, no test framework — the self-test is invoked directly with `node`.

---

## Task 1: Scaffold the plugin folder and Config

**Files:**
- Create: `SnipasteFloat.popclipext/Config.popclipext`
- Create: `SnipasteFloat.popclipext/snipaste-icon.svg`

- [ ] **Step 1: Create the icon file**

Use a tiny placeholder SVG that's recognizable as "pin / float". Keep it simple — user can swap later.

Write `SnipasteFloat.popclipext/snipaste-icon.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <title>Snipaste Float</title>
  <rect x="4" y="3" width="14" height="14" rx="1.5"/>
  <path d="M8 21l-2 0M12 21l-1 0M16 21l-2 0"/>
  <path d="M21 7l-2.5 2.5M21 12l-3.5 0"/>
</svg>
```

- [ ] **Step 2: Create the Config file**

Write `SnipasteFloat.popclipext/Config.popclipext` with PopClip's space-separated YAML keys (matches the existing three plugins):

```yaml
# popclip
name: Snipaste Float
identifier: com.custom.snipastefloat
icon: snipaste-icon.svg
language: javascript
module: snipaste-float.js
requirements: [text]
capture html: true
```

- [ ] **Step 3: Verify the YAML parses and the folder loads**

Run a syntax check. There's no PopClip CLI to validate, but Python's PyYAML is universally available:

```bash
python3 -c "import yaml; yaml.safe_load(open('SnipasteFloat.popclipext/Config.popclipext'))" && echo OK
```

Expected: `OK`. If PyYAML chokes on the comment line, that's expected — strip it for the check or use:

```bash
python3 -c "import yaml,sys; data=yaml.safe_load(open('SnipasteFloat.popclipext/Config.popclipext')); print(data['identifier'])"
```

Expected: `com.custom.snipastefloat`.

- [ ] **Step 4: Commit**

```bash
git add SnipasteFloat.popclipext/
git commit -m "feat: scaffold SnipasteFloat plugin folder and config"
```

---

## Task 2: Skeleton JS module with stubbed action and self-test runner

This task creates the file shape and a working self-test runner that fails. Subsequent tasks fill in `classify` step by step (TDD).

**Files:**
- Create: `SnipasteFloat.popclipext/snipaste-float.js`

- [ ] **Step 1: Create the file with constants, stubs, and the self-test guard**

Write `SnipasteFloat.popclipext/snipaste-float.js`:

```javascript
"use strict";

const SNIPASTE_BIN = "/Applications/Snipaste.app/Contents/MacOS/Snipaste";
const LOG_FILE = "/tmp/snipaste-float.log";
const IMAGE_EXTS = new Set([
  "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic", "svg",
]);
const DOWNLOAD_TIMEOUT_SECONDS = 10;

function isImageExt(ext) {
  if (typeof ext !== "string") return false;
  return IMAGE_EXTS.has(ext.toLowerCase());
}

// classify: pure function. Decides what kind of paste to perform.
// deps.fileExists(path) -> boolean — injected so self-test can stub.
function classify(input, deps) {
  // Filled in by Task 3.
  return { kind: "text", payload: { text: (input && input.text) || "" } };
}

// --- Self-test (Node only; PopClip's JS runtime never enters this block) ---
if (
  typeof require !== "undefined" &&
  typeof module !== "undefined" &&
  require.main === module
) {
  runSelfTest();
}

function runSelfTest() {
  const cases = [
    // Filled in by Task 3.
  ];
  let failed = 0;
  for (const c of cases) {
    const got = classify(c.input, { fileExists: c.fileExists || (() => false) });
    const ok = got.kind === c.expectKind;
    console.log(`${ok ? "PASS" : "FAIL"}  ${c.name}  -> ${got.kind} (expected ${c.expectKind})`);
    if (!ok) failed++;
  }
  console.log(`\n${cases.length - failed}/${cases.length} passed`);
  process.exit(failed === 0 ? 0 : 1);
}
```

- [ ] **Step 2: Run the self-test and verify it executes cleanly**

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: `0/0 passed` (no cases yet) and exit code `0`.

```bash
echo $?
```

Expected: `0`.

- [ ] **Step 3: Commit**

```bash
git add SnipasteFloat.popclipext/snipaste-float.js
git commit -m "feat: snipaste-float.js skeleton with self-test runner"
```

---

## Task 3: Implement and TDD the `classify` function

This is the only non-trivial pure logic in the plugin. Each step adds a failing test, then makes it pass.

**Files:**
- Modify: `SnipasteFloat.popclipext/snipaste-float.js`

The fully populated test cases this task ends with (all eight from the spec):

| # | input shape (abbreviated) | fileExists stub | expected kind |
|---|---|---|---|
| 1 | `{ text: "hello" }` | n/a | `text` |
| 2 | `{ text: "hello", html: "<b>hello</b>" }` | n/a | `html` |
| 3 | `{ text: "/x/a.png", data: { paths: ["/x/a.png"] } }` | true | `imageFile` |
| 4 | `{ text: "/x/missing.png", data: { paths: ["/x/missing.png"] } }` | false | `text` |
| 5 | `{ text: "/x/foo.txt", data: { paths: ["/x/foo.txt"] } }` | true | `text` |
| 6 | `{ text: "https://x.com/a.png", isUrl: true, data: { urls: ["https://x.com/a.png"] } }` | n/a | `imageUrl` |
| 7 | `{ text: "https://example.com", isUrl: true, data: { urls: ["https://example.com"] } }` | n/a | `text` |
| 8 | `{ text: "see <div> tag", html: "" }` | n/a | `text` |

- [ ] **Step 1: Add test cases 1, 2, and 8 (text and HTML branches) — failing**

Replace the empty `cases = []` array in `runSelfTest()` with:

```javascript
const cases = [
  {
    name: "plain text -> text",
    input: { text: "hello", html: "" },
    expectKind: "text",
  },
  {
    name: "rich text with html -> html",
    input: { text: "hello", html: "<b>hello</b>" },
    expectKind: "html",
  },
  {
    name: "plain text mentioning <div> -> text (no false-positive HTML)",
    input: { text: "see <div> tag", html: "" },
    expectKind: "text",
  },
];
```

Run:

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: `2/3 passed` (case 2 fails — current stub always returns `text`).

- [ ] **Step 2: Implement HTML branch in `classify`**

Replace the body of `classify` with:

```javascript
function classify(input, deps) {
  const html = input && typeof input.html === "string" ? input.html : "";
  if (html.length > 0) {
    return { kind: "html", payload: { html } };
  }
  const text = input && typeof input.text === "string" ? input.text : "";
  return { kind: "text", payload: { text } };
}
```

Run:

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: `3/3 passed`.

- [ ] **Step 3: Add test cases 3, 4, 5 (imageFile branches) — failing**

Append to `cases`:

```javascript
{
  name: "image path that exists -> imageFile",
  input: { text: "/x/a.png", data: { paths: ["/x/a.png"] } },
  fileExists: () => true,
  expectKind: "imageFile",
},
{
  name: "image path that does not exist -> text (fallback)",
  input: { text: "/x/missing.png", data: { paths: ["/x/missing.png"] } },
  fileExists: () => false,
  expectKind: "text",
},
{
  name: "non-image path -> text (extension check)",
  input: { text: "/x/foo.txt", data: { paths: ["/x/foo.txt"] } },
  fileExists: () => true,
  expectKind: "text",
},
```

Run:

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: case 3 fails (returned `text`, expected `imageFile`); cases 4 and 5 happen to pass already (fall through). Confirm at least one FAIL line.

- [ ] **Step 4: Implement imageFile branch (with path normalization)**

Add a helper above `classify`:

```javascript
function normalizePath(p) {
  if (typeof p !== "string") return "";
  let out = p.trim();
  if (out.startsWith("file://")) out = out.slice("file://".length);
  if (out.startsWith("~/")) {
    const home = (typeof process !== "undefined" && process.env && process.env.HOME) || "";
    if (home) out = home + out.slice(1);
  }
  return out;
}

function extOf(path) {
  const dot = path.lastIndexOf(".");
  if (dot < 0 || dot === path.length - 1) return "";
  return path.slice(dot + 1).toLowerCase();
}
```

Update `classify` to insert the imageFile branch *between* the html branch and the text fallback:

```javascript
function classify(input, deps) {
  const html = input && typeof input.html === "string" ? input.html : "";
  if (html.length > 0) {
    return { kind: "html", payload: { html } };
  }

  const paths = (input && input.data && Array.isArray(input.data.paths)) ? input.data.paths : [];
  if (paths.length >= 1) {
    const candidate = normalizePath(paths[0]);
    if (isImageExt(extOf(candidate)) && deps && deps.fileExists && deps.fileExists(candidate)) {
      return { kind: "imageFile", payload: { path: candidate } };
    }
  }

  const text = input && typeof input.text === "string" ? input.text : "";
  return { kind: "text", payload: { text } };
}
```

Run:

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: `6/6 passed`.

- [ ] **Step 5: Add test cases 6, 7 (imageUrl branches) — failing**

Append:

```javascript
{
  name: "image URL -> imageUrl",
  input: {
    text: "https://x.com/a.png",
    isUrl: true,
    data: { urls: ["https://x.com/a.png"] },
  },
  expectKind: "imageUrl",
},
{
  name: "non-image URL -> text",
  input: {
    text: "https://example.com",
    isUrl: true,
    data: { urls: ["https://example.com"] },
  },
  expectKind: "text",
},
```

Run:

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: case 6 fails (returned `text`, expected `imageUrl`); case 7 passes (falls through).

- [ ] **Step 6: Implement imageUrl branch**

Add a helper above `classify`:

```javascript
function urlPathExt(url) {
  // Strip query and fragment, then take the extension of the path.
  let s = url;
  const hashIdx = s.indexOf("#");
  if (hashIdx >= 0) s = s.slice(0, hashIdx);
  const queryIdx = s.indexOf("?");
  if (queryIdx >= 0) s = s.slice(0, queryIdx);
  return extOf(s);
}
```

Insert imageUrl branch in `classify` *between* imageFile and text:

```javascript
  if (input && input.isUrl === true) {
    const urls = (input.data && Array.isArray(input.data.urls)) ? input.data.urls : [];
    const url = urls.length > 0 ? urls[0] : (typeof input.text === "string" ? input.text.trim() : "");
    const ext = urlPathExt(url);
    if (url && isImageExt(ext)) {
      return { kind: "imageUrl", payload: { url, ext } };
    }
  }
```

Final `classify` should now have four ordered branches: html → imageFile → imageUrl → text.

Run:

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: `8/8 passed`.

- [ ] **Step 7: Commit**

```bash
git add SnipasteFloat.popclipext/snipaste-float.js
git commit -m "feat: classify() with full priority ladder + self-tests"
```

---

## Task 4: Logging helper and Snipaste runner

Logging and process invocation are the only side-effecting helpers. Implement and lightly verify them via a one-off bash check (not Node — PopClip-only APIs).

**Files:**
- Modify: `SnipasteFloat.popclipext/snipaste-float.js`

- [ ] **Step 1: Add `log()` and `runSnipaste()` near the top, after constants**

Insert (after `isImageExt`, before `classify`):

```javascript
function log(message) {
  if (typeof popclip === "undefined" || !popclip.executeShellCommand) return;
  const line = "[" + new Date().toISOString() + "] " + String(message);
  // Note: the \n in the printf format is interpreted by the shell, not JS.
  // Using double-quoted JS so \\n becomes a literal backslash-n in the shell argv.
  popclip.executeShellCommand(
    "/bin/sh",
    ["-c", "printf '%s\\n' \"$1\" >> " + LOG_FILE, "--", line]
  );
}

class SnipasteNotInstalledError extends Error {}
class SnipasteError extends Error {}
class DownloadError extends Error {}

function runSnipaste(args) {
  const result = popclip.executeShellCommand(SNIPASTE_BIN, args);
  // popclip.executeShellCommand returns { status, stdout, stderr } per the PopClip JS API.
  // Status 127 typically means "not found"; treat any non-zero as failure.
  if (!result || typeof result.status !== "number") {
    throw new SnipasteError("no result from Snipaste");
  }
  if (result.status === 127 || (result.stderr && /No such file or directory/i.test(result.stderr))) {
    throw new SnipasteNotInstalledError(result.stderr || "Snipaste not found");
  }
  if (result.status !== 0) {
    throw new SnipasteError(result.stderr || ("exit " + result.status));
  }
}
```

- [ ] **Step 2: Verify the file still parses as JS**

`classify` and the self-test should still work. Run:

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: `8/8 passed`. (`log` and `runSnipaste` reference `popclip` only inside the function bodies, so they don't fire under Node.)

- [ ] **Step 3: Sanity-check the printf line-break behavior with shell directly**

This is the part most prone to silent breakage. Run:

```bash
rm -f /tmp/snipaste-float-test.log
/bin/sh -c "printf '%s\n' \"\$1\" >> /tmp/snipaste-float-test.log" -- "line one"
/bin/sh -c "printf '%s\n' \"\$1\" >> /tmp/snipaste-float-test.log" -- "line two"
wc -l /tmp/snipaste-float-test.log
```

Expected: `2 /tmp/snipaste-float-test.log`. If you see `0` or `1`, the `\n` is not being interpreted — fix the JS string before continuing. Clean up: `rm /tmp/snipaste-float-test.log`.

- [ ] **Step 4: Commit**

```bash
git add SnipasteFloat.popclipext/snipaste-float.js
git commit -m "feat: log() helper and runSnipaste() runner with typed errors"
```

---

## Task 5: Image download and the four paste functions

**Files:**
- Modify: `SnipasteFloat.popclipext/snipaste-float.js`

- [ ] **Step 1: Add `downloadImage` and the four paste functions after `runSnipaste`**

Insert:

```javascript
function downloadImage(url, ext) {
  const ts = Date.now();
  const safeExt = ext && /^[a-z0-9]+$/i.test(ext) ? ext.toLowerCase() : "img";
  const tmpPath = "/tmp/snipaste-float-" + ts + "." + safeExt;
  const result = popclip.executeShellCommand(
    "/usr/bin/curl",
    [
      "-fsSL",
      "--max-time", String(DOWNLOAD_TIMEOUT_SECONDS),
      "-o", tmpPath,
      url,
    ]
  );
  if (!result || result.status !== 0) {
    throw new DownloadError(
      "curl exit " + (result && result.status) + ": " + (result && result.stderr)
    );
  }
  // Reject zero-byte downloads.
  const sizeRes = popclip.executeShellCommand("/usr/bin/stat", ["-f", "%z", tmpPath]);
  const size = sizeRes && parseInt((sizeRes.stdout || "0").trim(), 10);
  if (!size || size <= 0) {
    throw new DownloadError("downloaded file is empty");
  }
  return tmpPath;
}

function pasteHtml(html)        { runSnipaste(["paste", "--html", html]); }
function pasteImageFile(path)   { runSnipaste(["paste", "--files", path]); }
function pastePlain(text)       { runSnipaste(["paste", "--plain", text]); }
function pasteImageUrl(url, ext) {
  const local = downloadImage(url, ext);
  pasteImageFile(local);
}
```

- [ ] **Step 2: Verify the file still parses**

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: `8/8 passed`.

- [ ] **Step 3: Commit**

```bash
git add SnipasteFloat.popclipext/snipaste-float.js
git commit -m "feat: downloadImage and the four paste functions"
```

---

## Task 6: Wire up `dispatch`, `userMessage`, and exported `action`

**Files:**
- Modify: `SnipasteFloat.popclipext/snipaste-float.js`

- [ ] **Step 1: Add `fileExistsReal`, `dispatch`, `userMessage`, and `action`**

Insert below the paste functions:

```javascript
function fileExistsReal(path) {
  if (typeof popclip === "undefined" || !popclip.executeShellCommand) return false;
  const r = popclip.executeShellCommand("/bin/test", ["-f", path]);
  return !!r && r.status === 0;
}

function dispatch(decision) {
  switch (decision.kind) {
    case "html":      return pasteHtml(decision.payload.html);
    case "imageFile": return pasteImageFile(decision.payload.path);
    case "imageUrl":  return pasteImageUrl(decision.payload.url, decision.payload.ext);
    case "text":      return pastePlain(decision.payload.text);
    default:
      throw new Error("unknown decision kind: " + decision.kind);
  }
}

function userMessage(err) {
  if (err instanceof SnipasteNotInstalledError) return "Snipaste 未安装或路径不对";
  if (err instanceof DownloadError) return "图片下载失败";
  if (err instanceof SnipasteError) return "Snipaste 调用失败";
  return "处理失败";
}

function action(input) {
  const summary =
    "len=" + ((input && input.text && input.text.length) || 0) +
    " html=" + (!!(input && input.html)) +
    " isUrl=" + !!(input && input.isUrl) +
    " paths=" + ((input && input.data && input.data.paths && input.data.paths.length) || 0);
  log("start " + summary);
  try {
    const decision = classify(input, { fileExists: fileExistsReal });
    log("decision: " + decision.kind);
    dispatch(decision);
  } catch (e) {
    log("error: " + e.message + (e.stack ? "\n" + e.stack : ""));
    if (typeof popclip !== "undefined" && popclip.showText) {
      popclip.showText(userMessage(e));
    }
  }
}

exports.action = action;
```

Note the trailing `exports.action = action;` — PopClip's JS module loader picks this up. The existing `fancy-text.js` plugin uses the same pattern; cross-check it if uncertain (`fancy-text.popclipext/fancy-text.js`).

- [ ] **Step 2: Verify the self-test still passes**

```bash
node SnipasteFloat.popclipext/snipaste-float.js
```

Expected: `8/8 passed`. (`exports` exists in Node, so `exports.action = action` is harmless under Node.)

- [ ] **Step 3: Commit**

```bash
git add SnipasteFloat.popclipext/snipaste-float.js
git commit -m "feat: dispatch, userMessage, and action entry point"
```

---

## Task 7: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the English Snipaste Float section**

In `README.md`, find the `#### 3. **Fancy Text**` section under `## English` → `### 📦 Plugins Included`. After its closing list of styles, add a new fourth plugin section:

```markdown
#### 4. **Snipaste Float** 📌
Float the selected content on the desktop using the Snipaste CLI. Auto-classifies the selection.

- **Features:**
  - Plain text → floating text pin
  - Rich text (HTML) → rendered HTML pin
  - Local image path → image pin
  - Image URL → downloaded and pinned as image

- **Detection priority:** HTML → local image file → image URL → plain text (fallback)

- **Configuration:** None
- **Dependency:** [Snipaste](https://www.snipaste.com/) installed at `/Applications/Snipaste.app`
```

Then update the `### 📁 Project Structure` block in the English section. Locate the existing tree (which lists OpenGemini, SendToClaude, fancy-text, README in that order). Insert SnipasteFloat between `fancy-text.popclipext/` and `README.md`:

```
├── SnipasteFloat.popclipext/
│   ├── Config.popclipext
│   ├── snipaste-icon.svg
│   └── snipaste-float.js
```

Make sure `fancy-text.popclipext/`'s prefix is still `├──` (not `└──`) since it's no longer the last entry, and `SnipasteFloat.popclipext/` uses `├──` while only `README.md` keeps the `└──` corner.

- [ ] **Step 2: Add the 中文 Snipaste Float section**

Mirror the English structure under `## 中文说明` → `### 📦 包含的插件`. After Fancy Text:

```markdown
#### 4. **Snipaste Float** 📌
使用 Snipaste CLI 将选中内容悬浮在桌面上。自动识别内容类型。

- **功能特性:**
  - 纯文本 → 文字悬浮贴图
  - 富文本（HTML）→ HTML 渲染贴图
  - 本地图片路径 → 图片贴图
  - 图片 URL → 下载后作为图片贴图

- **识别优先级:** HTML → 本地图片文件 → 图片 URL → 纯文本（兜底）

- **配置选项:** 无
- **依赖:** [Snipaste](https://www.snipaste.com/) 安装在 `/Applications/Snipaste.app`
```

The 中文 `### 📁 项目结构` block also needs the same three lines inserted.

- [ ] **Step 3: Verify the README is well-formed**

Open the file and skim the diff. There should be exactly two new plugin subsections (one English, one 中文), and two updated "Project Structure" / "项目结构" code blocks. No other sections changed.

```bash
git diff README.md | head -100
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document Snipaste Float in README (en + zh)"
```

---

## Task 8: Manual integration verification

This task is not committed — it's a checklist the implementer runs by hand after Task 7. If anything fails, file the failure as a follow-up issue (or fix it inline if it's a small bug in the JS).

**Files:** none (manual verification only)

- [ ] **Step 1: Install the plugin**

```bash
open SnipasteFloat.popclipext
```

PopClip should pop a confirmation dialog. Click Install.

- [ ] **Step 2: Confirm the button appears in PopClip**

Select any text in any app. Look for the Snipaste Float icon in the PopClip popup. If absent, check PopClip → Extensions to see whether installation succeeded.

- [ ] **Step 3: Run the six golden-path checks from the spec**

Execute each, confirming the expected behavior. Watch `/tmp/snipaste-float.log` in another tab:

```bash
tail -f /tmp/snipaste-float.log
```

Checks:

1. Select a paragraph of plain text in any app → click Snipaste Float → expect a text pin to appear on the desktop.
2. Select rich text on a web page (e.g., a Wikipedia paragraph with formatting) → click → expect a rendered HTML pin (formatting visible).
3. In Finder, get a path to a local image (e.g., `~/Pictures/foo.png`); paste the path into Notes; select the path string → click → expect the image to appear as a pin.
4. Select an image URL such as `https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png` → click → expect the image to download and pin within ~1 second.
5. Select `https://example.com` → click → expect a text pin showing the URL string (no download attempt).
6. Edit `snipaste-float.js` and temporarily change `SNIPASTE_BIN` to `/Applications/Snipaste.app/Contents/MacOS/NopeNotReal`. Re-install the plugin (PopClip auto-reloads on save in dev mode, but if not, re-double-click the folder). Repeat check 1 → expect a `popclip.showText("Snipaste 未安装或路径不对")` and a corresponding entry in `/tmp/snipaste-float.log`. Revert the constant.

- [ ] **Step 4: If any check failed, debug and patch**

Read the log. Common failure modes:

- "no result from Snipaste" → `popclip.executeShellCommand` API shape might differ; cross-check by running a one-line PopClip JS that logs `JSON.stringify(popclip.executeShellCommand("/bin/echo", ["hi"]))`.
- HTML pin shows raw markup → `--html` arg is being treated as plain by Snipaste; verify the Snipaste version supports `--html` (`Snipaste --version`).
- Image-URL check stalls → `curl --max-time` may need to be longer for slow connections; bump `DOWNLOAD_TIMEOUT_SECONDS`.

- [ ] **Step 5: Re-uninstall the broken-path test version if not already**

After check 6 passes, ensure `SNIPASTE_BIN` is reverted to the real path and re-installed.

---

## Done criteria

- All seven implementation tasks committed
- `node SnipasteFloat.popclipext/snipaste-float.js` reports `8/8 passed`
- All six manual integration checks pass
- README contains the new plugin in both English and 中文 sections
