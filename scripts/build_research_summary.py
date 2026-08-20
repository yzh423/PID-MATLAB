"""Build the Phase 7B one-page research-summary DOCX."""

from __future__ import annotations

import argparse
from collections.abc import Sequence
from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.phase7b.summary import SummaryBuildError, build_summary


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        root = args.project_root.resolve(strict=True)
        output = args.output or root / "docs/summary/research_summary.docx"
        if not output.is_absolute():
            output = root / output
        build_summary(root, output)
    except (OSError, UnicodeError, ValueError, SummaryBuildError) as exception:
        print(f"Research summary build failed: {exception}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
