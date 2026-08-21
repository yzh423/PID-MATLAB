import { randomUUID } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { inflateRawSync } from "node:zlib";


export function ownedSiblingTemporary(finalPath) {
  const parsed = path.parse(finalPath);
  return path.join(
    parsed.dir,
    `.${parsed.base}.phase7b-${process.pid}-${randomUUID().replaceAll("-", "")}.tmp${parsed.ext}`,
  );
}


export async function replaceFileAtomically(temporary, finalPath) {
  await fs.rename(temporary, finalPath);
}


export async function publishAtomically(finalPath, callbacks) {
  for (const name of ["save", "validate", "normalize"]) {
    if (typeof callbacks[name] !== "function") {
      throw new TypeError(`publishAtomically requires a ${name} callback`);
    }
  }
  const replace = callbacks.replace ?? replaceFileAtomically;
  const temporary = ownedSiblingTemporary(finalPath);
  await fs.mkdir(path.dirname(finalPath), { recursive: true });
  try {
    await callbacks.save(temporary);
    await callbacks.validate(temporary);
    await callbacks.normalize(temporary);
    await callbacks.validate(temporary);
    await replace(temporary, finalPath);
  } finally {
    await fs.rm(temporary, { force: true });
  }
}


function zipEntries(buffer) {
  const minimum = Math.max(0, buffer.length - 65_557);
  let end = -1;
  for (let offset = buffer.length - 22; offset >= minimum; offset -= 1) {
    if (buffer.readUInt32LE(offset) === 0x06054b50) {
      end = offset;
      break;
    }
  }
  if (end < 0) throw new Error("PPTX ZIP end record is missing");
  const entries = buffer.readUInt16LE(end + 10);
  let cursor = buffer.readUInt32LE(end + 16);
  const records = [];
  for (let index = 0; index < entries; index += 1) {
    if (cursor + 46 > buffer.length || buffer.readUInt32LE(cursor) !== 0x02014b50) {
      throw new Error("PPTX ZIP central directory is invalid");
    }
    const nameLength = buffer.readUInt16LE(cursor + 28);
    const extraLength = buffer.readUInt16LE(cursor + 30);
    const commentLength = buffer.readUInt16LE(cursor + 32);
    const nameStart = cursor + 46;
    const name = buffer.subarray(nameStart, nameStart + nameLength).toString("utf8");
    const compression = buffer.readUInt16LE(cursor + 10);
    const compressedSize = buffer.readUInt32LE(cursor + 20);
    const uncompressedSize = buffer.readUInt32LE(cursor + 24);
    const localOffset = buffer.readUInt32LE(cursor + 42);
    if (buffer.readUInt32LE(localOffset) !== 0x04034b50) throw new Error(`PPTX ZIP local record is invalid: ${name}`);
    const localNameLength = buffer.readUInt16LE(localOffset + 26);
    const localExtraLength = buffer.readUInt16LE(localOffset + 28);
    const dataStart = localOffset + 30 + localNameLength + localExtraLength;
    const compressed = buffer.subarray(dataStart, dataStart + compressedSize);
    let payload;
    if (compression === 0) payload = compressed;
    else if (compression === 8) payload = inflateRawSync(compressed);
    else throw new Error(`PPTX ZIP uses unsupported compression ${compression}: ${name}`);
    if (payload.length !== uncompressedSize) throw new Error(`PPTX ZIP size mismatch: ${name}`);
    records.push({ name, payload });
    cursor = nameStart + nameLength + extraLength + commentLength;
  }
  return records;
}


export async function validatePptxStructure(pptxPath) {
  const records = zipEntries(await fs.readFile(pptxPath));
  const entries = new Map(records.map(({ name, payload }) => [name, payload]));
  const names = [...entries.keys()];
  for (const required of ["[Content_Types].xml", "ppt/presentation.xml"]) {
    if (!names.includes(required)) throw new Error(`PPTX structure is missing ${required}`);
  }
  const byNumber = (left, right) => Number(left.match(/\d+/)[0]) - Number(right.match(/\d+/)[0]);
  const slides = names.filter((name) => /^ppt\/slides\/slide\d+\.xml$/.test(name)).sort(byNumber);
  const notes = names.filter((name) => /^ppt\/notesSlides\/notesSlide\d+\.xml$/.test(name)).sort(byNumber);
  if (slides.length !== 10 || notes.length !== 10) {
    throw new Error(`PPTX structure requires 10 slides and 10 notes; got ${slides.length}/${notes.length}`);
  }
  for (let index = 0; index < 10; index += 1) {
    const expectedSlide = `ppt/slides/slide${index + 1}.xml`;
    const expectedNote = `ppt/notesSlides/notesSlide${index + 1}.xml`;
    if (slides[index] !== expectedSlide || notes[index] !== expectedNote) {
      throw new Error("PPTX structure requires contiguous slide and notes parts");
    }
    const slideXml = entries.get(expectedSlide).toString("utf8");
    const noteXml = entries.get(expectedNote).toString("utf8");
    if (!/^\s*<\?xml[^>]*>\s*<p:sld\b/.test(slideXml) || !slideXml.includes("http://schemas.openxmlformats.org/presentationml/2006/main")) {
      throw new Error(`PPTX slide root is not a presentation slide: slide${index + 1}`);
    }
    if (!/^\s*<\?xml[^>]*>\s*<p:notes\b/.test(noteXml) || !noteXml.includes("[Sources]")) {
      throw new Error(`PPTX notes root/content is invalid: notesSlide${index + 1}`);
    }
  }
}


export async function publishArtifactSetAtomically(artifacts, options = {}) {
  if (!Array.isArray(artifacts) || artifacts.length === 0) throw new TypeError("artifact set is required");
  const validate = options.validate ?? (async () => {});
  const replace = options.replace ?? replaceFileAtomically;
  const staged = artifacts.map((artifact) => ({
    ...artifact,
    temporary: ownedSiblingTemporary(artifact.finalPath),
    backup: `${ownedSiblingTemporary(artifact.finalPath)}.bak`,
    backedUp: false,
    replaced: false,
  }));
  try {
    for (const artifact of staged) {
      if (typeof artifact.save !== "function") throw new TypeError("each artifact requires a save callback");
      await fs.mkdir(path.dirname(artifact.finalPath), { recursive: true });
      await artifact.save(artifact.temporary);
    }
    await validate(staged);
    for (const artifact of staged) {
      try {
        await fs.rename(artifact.finalPath, artifact.backup);
        artifact.backedUp = true;
      } catch (error) {
        if (error?.code !== "ENOENT") throw error;
      }
      await replace(artifact.temporary, artifact.finalPath);
      artifact.replaced = true;
    }
  } catch (error) {
    for (const artifact of [...staged].reverse()) {
      if (artifact.replaced) await fs.rm(artifact.finalPath, { force: true });
      if (artifact.backedUp) await fs.rename(artifact.backup, artifact.finalPath);
    }
    throw error;
  } finally {
    for (const artifact of staged) {
      await fs.rm(artifact.temporary, { force: true });
      await fs.rm(artifact.backup, { force: true });
    }
  }
}
