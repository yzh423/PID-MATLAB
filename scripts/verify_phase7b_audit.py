"""CLI for the fail-closed canonical Phase 7B audit gate."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.phase7b.audit import Phase7BAuditError, validate_phase7b_audit


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--audit", required=True, type=Path)
    args = parser.parse_args()
    root = args.project_root.resolve(strict=True)
    audit = args.audit if args.audit.is_absolute() else root / args.audit

    def is_ancestor(commit: str) -> bool:
        return subprocess.run(
            ["git", "merge-base", "--is-ancestor", commit, "HEAD"],
            cwd=root,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode == 0

    try:
        validate_phase7b_audit(root, audit, is_ancestor=is_ancestor)
    except Phase7BAuditError as exception:
        print(f"Phase 7B audit verification failed: {exception}", file=sys.stderr)
        return 2
    print("PHASE7B_AUDIT_VERIFIED claims=11 findings=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
