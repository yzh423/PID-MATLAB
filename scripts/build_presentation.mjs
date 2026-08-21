import fs from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";
import { Presentation, PresentationFile } from "@oai/artifact-tool";
import { publishAtomically, validatePptxStructure } from "./phase7b/atomic_publish.mjs";

const SIZE = { width: 1280, height: 720 };
const COLORS = {
  ink: "#000000",
  panel: "#EDEDED",
  rule: "#B8BCC4",
  accent: "#3D8DFF",
  pale: "#D0EDFA",
};

async function imageBytes(filePath) {
  const bytes = await fs.readFile(filePath);
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
}

function setNotes(slide, slideSpec) {
  const lines = [
    slideSpec.presenterNote ?? "",
    "",
    "[Sources]",
    ...slideSpec.sources.map((source) => `- ${source}`),
  ];
  slide.speakerNotes.textFrame.setText(
    lines.filter((line, index) => line || index > 0).join("\n"),
  );
  slide.speakerNotes.setVisible(true);
}

function addTitle(slide, title, number) {
  const isConclusion = number === 9;
  const box = slide.shapes.add({
    geometry: "textbox",
    name: `slide-${number}-title`,
    position: isConclusion
      ? { left: 52, top: 24, width: 1168, height: 112 }
      : { left: 52, top: 34, width: 1168, height: 72 },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  box.text = title;
  box.text.style = {
    fontSize: 48,
    bold: true,
    color: COLORS.ink,
    typeface: "Arial",
    autoFit: "shrinkText",
  };
}

function addText(slide, name, text, position, fontSize = 24, options = {}) {
  const box = slide.shapes.add({
    geometry: "textbox",
    name,
    position,
    fill: options.fill ?? "none",
    line: options.line ?? { style: "solid", fill: "none", width: 0 },
  });
  box.text = text;
  box.text.style = {
    fontSize,
    bold: options.bold ?? false,
    color: options.color ?? COLORS.ink,
    typeface: "Arial",
    alignment: options.alignment ?? "left",
    verticalAlignment: options.verticalAlignment ?? "top",
    autoFit: "shrinkText",
  };
  return box;
}

function buildCover(slide, spec) {
  addText(
    slide,
    "cover-title",
    spec.title,
    { left: 52, top: 170, width: 560, height: 210 },
    68,
    { bold: true },
  );
  addText(
    slide,
    "cover-subtitle",
    spec.subtitle,
    { left: 52, top: 410, width: 560, height: 110 },
    28,
  );
}

function buildEvidenceSplit(slide, spec) {
  addText(
    slide,
    `${spec.id}-claim`,
    spec.claim,
    { left: 52, top: 180, width: 540, height: 160 },
    32,
    { bold: true },
  );
  addText(
    slide,
    `${spec.id}-body`,
    spec.body.join("\n\n"),
    { left: 52, top: 360, width: 540, height: 248 },
    24,
  );
}

function buildMetricSlide(slide, spec) {
  const lefts = [52, 454, 856];
  for (const [index, metric] of spec.metrics.entries()) {
    addText(
      slide,
      `${spec.id}-metric-${index + 1}`,
      metric.value,
      { left: lefts[index], top: 250, width: 350, height: 120 },
      54,
      { bold: true, color: COLORS.accent },
    );
    addText(
      slide,
      `${spec.id}-metric-label-${index + 1}`,
      metric.label,
      { left: lefts[index], top: 392, width: 350, height: 100 },
      24,
    );
  }
  addText(
    slide,
    `${spec.id}-interpretation`,
    spec.interpretation,
    { left: 52, top: 540, width: 1150, height: 80 },
    24,
  );
}

function buildConclusion(slide, spec) {
  addText(
    slide,
    `${spec.id}-lead`,
    spec.claim,
    { left: 52, top: 160, width: 1120, height: 140 },
    42,
    { bold: true },
  );
  addText(
    slide,
    `${spec.id}-steps`,
    spec.body.join("\n\n"),
    { left: 52, top: 340, width: 1120, height: 270 },
    28,
  );
}

function addSlideContent(slide, spec, number) {
  if (number === 1) return buildCover(slide, spec);
  if (spec.layout === "metrics") return buildMetricSlide(slide, spec);
  if (number >= 9) return buildConclusion(slide, spec);
  return buildEvidenceSplit(slide, spec);
}

async function writeBlob(output, blob) {
  await fs.writeFile(output, new Uint8Array(await blob.arrayBuffer()));
}

async function writePreviews(presentation, outputDirectory) {
  await fs.mkdir(outputDirectory, { recursive: true });
  for (const [index, slide] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    await writeBlob(
      path.join(outputDirectory, `${stem}.png`),
      await presentation.export({ slide, format: "png", scale: 1 }),
    );
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(outputDirectory, `${stem}.layout.json`), await layout.text(), "utf8");
  }
  await writeBlob(
    path.join(outputDirectory, "montage.webp"),
    await presentation.export({ format: "webp", montage: true, scale: 1 }),
  );
}

async function writeSourceNotes(root, slides) {
  const lines = slides.flatMap((slide, index) => [
    `Slide ${index + 1}: ${slide.title}`,
    ...slide.sources.map((source) => `- ${source}`),
    "",
  ]);
  await fs.writeFile(path.join(root, "tmp/phase7b/source-notes.txt"), lines.join("\n"), "utf8");
}

async function runChecked(executable, args, label) {
  await new Promise((resolve, reject) => {
    const child = spawn(executable, args, { stdio: "inherit", windowsHide: true });
    child.once("error", reject);
    child.once("exit", (code, signal) => {
      if (code === 0 && signal === null) resolve();
      else reject(new Error(`${label} failed with exit=${code} signal=${signal}`));
    });
  });
}

async function normalizePptx(root, python, temporary) {
  await runChecked(
    python,
    [path.join(root, "scripts/normalize_phase7b_office.py"), "--path", temporary, "--suffix", ".pptx"],
    "Phase 7B PPTX normalization",
  );
}

async function main() {
  const rootIndex = process.argv.indexOf("--project-root");
  if (rootIndex === -1 || !process.argv[rootIndex + 1]) {
    throw new Error("Usage: build_presentation.mjs --project-root <path>");
  }
  const root = path.resolve(process.argv[rootIndex + 1]);
  const pythonIndex = process.argv.indexOf("--python");
  if (pythonIndex === -1 || !process.argv[pythonIndex + 1]) {
    throw new Error("Usage: build_presentation.mjs --project-root <path> --python <bundled-python>");
  }
  const python = path.resolve(process.argv[pythonIndex + 1]);
  const packageData = JSON.parse(
    await fs.readFile(path.join(root, "results/presentation/phase7b_package.json"), "utf8"),
  );
  const outputDirectory = path.join(root, "tmp/phase7b/slides");
  const presentation = Presentation.create({ slideSize: SIZE });
  for (const [index, spec] of packageData.deck.slides.entries()) {
    const slide = presentation.slides.add();
    slide.background.fill = "#FFFFFF";
    if (index > 0) addTitle(slide, spec.title, index + 1);
    if (spec.figure) {
      slide.images.add({
        blob: await imageBytes(path.join(root, spec.figure)),
        contentType: "image/png",
        alt: spec.figureAlt,
        fit: "contain",
        position: spec.figureFrame,
      });
    }
    addSlideContent(slide, spec, index + 1);
    setNotes(slide, spec);
  }
  await writePreviews(presentation, outputDirectory);
  await writeSourceNotes(root, packageData.deck.slides);
  const output = path.join(root, "presentation/final_presentation.pptx");
  const exported = await PresentationFile.exportPptx(presentation);
  await publishAtomically(output, {
    save: async (temporary) => exported.save(temporary),
    validate: validatePptxStructure,
    normalize: async (temporary) => normalizePptx(root, python, temporary),
  });
  await runChecked(
    python,
    [path.join(root, "scripts/generate_phase7b_layout_report.py"), "--project-root", root],
    "Phase 7B layout report generation",
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
