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
