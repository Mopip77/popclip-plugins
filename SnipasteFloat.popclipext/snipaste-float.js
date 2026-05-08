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

function normalizePath(p) {
  if (typeof p !== "string") return "";
  let out = p.trim();
  if (out.startsWith("file://")) out = out.slice("file://".length);
  if (out.startsWith("localhost/")) out = out.slice("localhost".length);
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

function urlPathExt(url) {
  // Strip query and fragment, then take the extension of the path.
  let s = url;
  const hashIdx = s.indexOf("#");
  if (hashIdx >= 0) s = s.slice(0, hashIdx);
  const queryIdx = s.indexOf("?");
  if (queryIdx >= 0) s = s.slice(0, queryIdx);
  return extOf(s);
}

// classify: pure function. Decides what kind of paste to perform.
// deps.fileExists(path) -> boolean — injected so self-test can stub.
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

  if (input && input.isUrl === true) {
    const urls = (input.data && Array.isArray(input.data.urls)) ? input.data.urls : [];
    const url = urls.length > 0 ? urls[0] : (typeof input.text === "string" ? input.text.trim() : "");
    const ext = urlPathExt(url);
    if (url && isImageExt(ext)) {
      return { kind: "imageUrl", payload: { url, ext } };
    }
  }

  const text = input && typeof input.text === "string" ? input.text : "";
  return { kind: "text", payload: { text } };
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
    {
      name: "file:// URL path normalizes and resolves -> imageFile",
      input: {
        text: "file://localhost/x/a.png",
        data: { paths: ["file://localhost/x/a.png"] },
      },
      fileExists: (p) => p === "/x/a.png",
      expectKind: "imageFile",
    },
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
