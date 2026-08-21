import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import { execFile } from "node:child_process";
import test from "node:test";

import * as atomic from "../../scripts/phase7b/atomic_publish.mjs";

const { publishAtomically, validatePptxStructure } = atomic;
const execFileAsync = promisify(execFile);
const PYTHON = "C:/Users/14228/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe";
const ROOT = path.resolve(import.meta.dirname, "../..");

async function fixture() {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "phase7b-atomic-"));
  const finalPath = path.join(directory, "final.pptx");
  await fs.writeFile(finalPath, "reviewed-final");
  return { directory, finalPath };
}

async function ownedTemps(directory) {
  return (await fs.readdir(directory)).filter((name) => name.startsWith(".final.pptx.phase7b-") && name.endsWith(".tmp.pptx"));
}

for (const stage of ["save", "validate", "normalize", "replace"]) {
  test(`${stage} failure preserves prior final and removes only owned temp`, async () => {
    const { directory, finalPath } = await fixture();
    const sentinel = path.join(directory, ".final.pptx.phase7b-unowned.tmp.pptx");
    await fs.writeFile(sentinel, "sentinel");
    const callbacks = {
      save: async (temporary) => {
        if (stage === "save") throw new Error("save failed");
        await fs.writeFile(temporary, "candidate");
      },
      validate: async () => { if (stage === "validate") throw new Error("validate failed"); },
      normalize: async () => { if (stage === "normalize") throw new Error("normalize failed"); },
      replace: async (temporary, target) => {
        if (stage === "replace") throw new Error("replace failed");
        await fs.rename(temporary, target);
      },
    };
    await assert.rejects(publishAtomically(finalPath, callbacks), new RegExp(`${stage} failed`));
    assert.equal(await fs.readFile(finalPath, "utf8"), "reviewed-final");
    assert.equal(await fs.readFile(sentinel, "utf8"), "sentinel");
    assert.deepEqual(await ownedTemps(directory), [path.basename(sentinel)]);
    await fs.rm(directory, { recursive: true, force: true });
  });
}

test("successful publication validates and normalizes before atomic replacement", async () => {
  const { directory, finalPath } = await fixture();
  const order = [];
  await publishAtomically(finalPath, {
    save: async (temporary) => { order.push("save"); await fs.writeFile(temporary, "candidate"); },
    validate: async () => { order.push("validate"); },
    normalize: async () => { order.push("normalize"); },
    replace: async (temporary, target) => { order.push("replace"); await fs.rename(temporary, target); },
  });
  assert.deepEqual(order, ["save", "validate", "normalize", "validate", "replace"]);
  assert.equal(await fs.readFile(finalPath, "utf8"), "candidate");
  assert.deepEqual(await ownedTemps(directory), []);
  await fs.rm(directory, { recursive: true, force: true });
});

test("normalizer corruption is rejected before replacement", async () => {
  const { directory, finalPath } = await fixture();
  const sentinel = path.join(directory, ".final.pptx.phase7b-unowned.tmp.pptx");
  await fs.writeFile(sentinel, "sentinel");
  await assert.rejects(
    publishAtomically(finalPath, {
      save: async (temporary) => { await fs.writeFile(temporary, "candidate"); },
      validate: async (temporary) => {
        if (await fs.readFile(temporary, "utf8") !== "candidate") {
          throw new Error("normalized candidate is corrupt");
        }
      },
      normalize: async (temporary) => { await fs.writeFile(temporary, "corrupt"); },
      replace: async (temporary, target) => { await fs.rename(temporary, target); },
    }),
    /normalized candidate is corrupt/,
  );
  assert.equal(await fs.readFile(finalPath, "utf8"), "reviewed-final");
  assert.equal(await fs.readFile(sentinel, "utf8"), "sentinel");
  assert.deepEqual(await ownedTemps(directory), [path.basename(sentinel)]);
  await fs.rm(directory, { recursive: true, force: true });
});

test("deep PPTX validation rejects a valid ZIP with an invalid slide root", async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "phase7b-invalid-slide-"));
  const candidate = path.join(directory, "candidate.pptx");
  const canonical = path.join(ROOT, "presentation/final_presentation.pptx");
  const script = [
    "import sys,zipfile",
    "src,dst=sys.argv[1:3]",
    "with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED) as zout:",
    "  for info in zin.infolist():",
    "    data=b'<not-a-presentation-slide/>' if info.filename=='ppt/slides/slide1.xml' else zin.read(info.filename)",
    "    zout.writestr(info,data)",
  ].join("\n");
  await execFileAsync(PYTHON, ["-c", script, canonical, candidate]);
  await assert.rejects(validatePptxStructure(candidate), /slide1|slide root|presentation slide/i);
  await fs.rm(directory, { recursive: true, force: true });
});

test("artifact-set publication rolls back PPTX layout and manifest on downstream failure", async () => {
  assert.equal(typeof atomic.publishArtifactSetAtomically, "function");
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "phase7b-artifact-set-"));
  const names = ["final.pptx", "layout.json", "manifest.json"];
  const finalPaths = names.map((name) => path.join(directory, name));
  await Promise.all(finalPaths.map((file, index) => fs.writeFile(file, `reviewed-${index}`)));
  const before = await Promise.all(finalPaths.map((file) => fs.readFile(file)));

  await assert.rejects(
    atomic.publishArtifactSetAtomically(
      finalPaths.map((finalPath, index) => ({
        finalPath,
        save: async (temporary) => {
          if (index === 1) throw new Error("downstream layout generation failed");
          await fs.writeFile(temporary, `candidate-${index}`);
        },
      })),
      { validate: async () => {} },
    ),
    /downstream layout generation failed/,
  );
  const after = await Promise.all(finalPaths.map((file) => fs.readFile(file)));
  assert.deepEqual(after, before);
  assert.deepEqual((await fs.readdir(directory)).sort(), names.sort());
  await fs.rm(directory, { recursive: true, force: true });
});
