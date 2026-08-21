"""Fail-closed semantic validator for a staged Phase 7B PPTX candidate."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.phase7b.layout import build_layout_report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--pptx", required=True, type=Path)
    parser.add_argument("--package", required=True, type=Path)
    args = parser.parse_args()
    report = build_layout_report(args.project_root, args.pptx, args.package)
    required = (
        "allWithinSlide", "allTextOverflowGuarded", "allTextClippingFree",
        "noCollisions", "minimumFontSizesPass",
    )
    failures = [name for name in required if report["checks"].get(name) is not True]
    if report["checks"].get("slideCount") != 10 or report["checks"].get("notesCount") != 10:
        failures.append("contiguousSlideAndNotesCount")
    if failures:
        raise SystemExit("Phase 7B staged PPTX semantic validation failed: " + ", ".join(failures))
    print("PHASE7B_PPTX_DEEP_VALIDATED slides=10 notes=10 layout=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
