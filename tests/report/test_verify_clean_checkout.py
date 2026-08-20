from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "scripts/verify.ps1"


class CleanCheckoutVerificationTests(unittest.TestCase):
    def test_formal_experiments_run_before_artifact_dependent_tests(self) -> None:
        script = VERIFY.read_text(encoding="utf-8")
        test_index = script.index("results = runtests('tests', 'IncludeSubfolders', true);")
        experiments = (
            "run('experiments/run_nominal_pid.m');",
            "run('experiments/run_nominal_pid_vs_fuzzy.m');",
            "run('experiments/run_pid_optimization.m');",
            "run('experiments/run_deterministic_robustness.m');",
            "run('experiments/run_stochastic_robustness.m');",
            "run('experiments/run_cartesian_tasks.m');",
            "run('experiments/run_simulink_cross_validation.m');",
            "run('experiments/run_multibody_cross_validation.m');",
        )
        for experiment in experiments:
            with self.subTest(experiment=experiment):
                self.assertLess(script.index(experiment), test_index)


if __name__ == "__main__":
    unittest.main()
