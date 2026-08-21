import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { publishAtomically } from "../../scripts/phase7b/atomic_publish.mjs";

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
  assert.deepEqual(order, ["save", "validate", "normalize", "replace"]);
  assert.equal(await fs.readFile(finalPath, "utf8"), "candidate");
  assert.deepEqual(await ownedTemps(directory), []);
  await fs.rm(directory, { recursive: true, force: true });
});
