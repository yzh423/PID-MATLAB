import { randomUUID } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";


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
    await replace(temporary, finalPath);
  } finally {
    await fs.rm(temporary, { force: true });
  }
}


function zipEntryNames(buffer) {
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
  const names = [];
  for (let index = 0; index < entries; index += 1) {
    if (cursor + 46 > buffer.length || buffer.readUInt32LE(cursor) !== 0x02014b50) {
      throw new Error("PPTX ZIP central directory is invalid");
    }
    const nameLength = buffer.readUInt16LE(cursor + 28);
    const extraLength = buffer.readUInt16LE(cursor + 30);
    const commentLength = buffer.readUInt16LE(cursor + 32);
    const nameStart = cursor + 46;
    names.push(buffer.subarray(nameStart, nameStart + nameLength).toString("utf8"));
    cursor = nameStart + nameLength + extraLength + commentLength;
  }
  return names;
}


export async function validatePptxStructure(pptxPath) {
  const names = zipEntryNames(await fs.readFile(pptxPath));
  for (const required of ["[Content_Types].xml", "ppt/presentation.xml"]) {
    if (!names.includes(required)) throw new Error(`PPTX structure is missing ${required}`);
  }
  const slides = names.filter((name) => /^ppt\/slides\/slide\d+\.xml$/.test(name));
  const notes = names.filter((name) => /^ppt\/notesSlides\/notesSlide\d+\.xml$/.test(name));
  if (slides.length !== 10 || notes.length !== 10) {
    throw new Error(`PPTX structure requires 10 slides and 10 notes; got ${slides.length}/${notes.length}`);
  }
}
