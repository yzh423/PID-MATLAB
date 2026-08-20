from __future__ import annotations

import math
from pathlib import Path
import unittest

from scripts.reporting.evidence import (
    EvidenceError,
    load_evidence,
    resolve_tokens,
)


PROJECT_ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_PATH = PROJECT_ROOT / "results/report/report_evidence.json"


class EvidenceTests(unittest.TestCase):
    def test_formal_manifest_has_frozen_shape(self) -> None:
        evidence = load_evidence(EVIDENCE_PATH)

        self.assertEqual(evidence["schemaVersion"], 1)
        self.assertEqual(evidence["deterministic"]["runCount"], 39)
        self.assertEqual(evidence["stochastic"]["trialCount"], 360)
        self.assertEqual(evidence["cartesian"]["runCount"], 6)

    def test_resolves_named_numeric_token(self) -> None:
        text, used = resolve_tokens(
            "Worst EE difference: "
            "{{multibody.endEffectorMaxWorst|.4e}} m.",
            load_evidence(EVIDENCE_PATH),
        )

        self.assertIn("3.3422e-16", text)
        self.assertEqual(used, {"multibody.endEffectorMaxWorst"})

    def test_unknown_token_is_rejected(self) -> None:
        with self.assertRaisesRegex(EvidenceError, "unknown evidence token"):
            resolve_tokens(
                "{{nominal.missing|.3f}}", load_evidence(EVIDENCE_PATH)
            )

    def test_resolves_zero_based_list_index(self) -> None:
        text, used = resolve_tokens(
            "Link lengths: {{system.linkLengthsM.0|.2f}} and "
            "{{system.linkLengthsM.1|.2f}} m.",
            load_evidence(EVIDENCE_PATH),
        )

        self.assertEqual(text, "Link lengths: 0.45 and 0.35 m.")
        self.assertEqual(
            used, {"system.linkLengthsM.0", "system.linkLengthsM.1"}
        )

    def test_unsupported_format_is_rejected(self) -> None:
        with self.assertRaisesRegex(EvidenceError, "unsupported token format"):
            resolve_tokens("{{value|.2x}}", {"value": 1.0})

    def test_non_finite_numeric_token_is_rejected(self) -> None:
        for value in (math.inf, -math.inf, math.nan):
            with self.subTest(value=value):
                with self.assertRaisesRegex(
                    EvidenceError, "finite numeric value"
                ):
                    resolve_tokens("{{value|.2f}}", {"value": value})

    def test_list_cannot_be_rendered_as_a_scalar(self) -> None:
        with self.assertRaisesRegex(EvidenceError, "scalar evidence value"):
            resolve_tokens("{{value|.2f}}", {"value": [1.0, 2.0]})

    def test_unresolved_braces_are_rejected(self) -> None:
        with self.assertRaisesRegex(EvidenceError, "unresolved evidence token"):
            resolve_tokens("Value: {{value|.2f}} and {{broken", {"value": 1.0})

    def test_resolution_is_deterministic(self) -> None:
        template = "{{first|d}}, {{second|.1f}}, {{first|d}}"
        evidence = {"first": 2, "second": 3.25}

        first = resolve_tokens(template, evidence)
        second = resolve_tokens(template, evidence)

        self.assertEqual(first, second)
        self.assertEqual(first, ("2, 3.2, 2", {"first", "second"}))


if __name__ == "__main__":
    unittest.main()
