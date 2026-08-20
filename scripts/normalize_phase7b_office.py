"""Normalize one final Phase 7B PPTX or DOCX package in place."""

from __future__ import annotations

import argparse
from collections.abc import Sequence
from pathlib import Path
import sys
from xml.etree import ElementTree
from zipfile import BadZipFile

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.phase7b.office import normalize_openxml_package


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", type=Path, required=True)
    parser.add_argument("--suffix", choices=(".pptx", ".docx"), required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        normalize_openxml_package(args.path, args.suffix)
    except (BadZipFile, OSError, ValueError, ElementTree.ParseError) as exception:
        print(f"Phase 7B Office normalization failed: {exception}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
