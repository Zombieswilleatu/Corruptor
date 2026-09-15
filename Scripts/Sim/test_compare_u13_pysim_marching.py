"""Reference and comparison prerequisites must fail closed."""

from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

import compare_u13_pysim_marching as comparison


class ComparisonTests(unittest.TestCase):
    def test_failed_or_different_control_cannot_authorize_comparison(self):
        evidence = json.loads(comparison.EVIDENCE.read_text())
        comparison.validate_control(evidence)
        for key, value in (("accepted", False), ("source_revision", "wrong"), ("source_sha256", "wrong")):
            bad = dict(evidence, **{key: value})
            with self.assertRaises(ValueError):
                comparison.validate_control(bad)
        bad = deepcopy(evidence)
        bad["runtimes"]["pypy"]["timing"]["worker_sha256"] = "different timed workload"
        with self.assertRaisesRegex(ValueError, "control.worker"):
            comparison.validate_control(bad)

    def test_altered_timed_workload_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sources = {}
            for name in ("benchmark_full_match.py", "full_match_inputs.json"):
                key = "Scripts/Sim/u13_pysim/" + name
                sources[key] = b"unchanged\n"
                path = root / key
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"unchanged\r\n")
            comparison.check_workload(root, sources)
            path.write_bytes(b"changed\n")
            with self.assertRaisesRegex(ValueError, "shared_workload"):
                comparison.check_workload(root, sources)

    def test_wrong_marching_reference_and_changed_control_source_fail(self):
        with self.assertRaisesRegex(ValueError, "reference_trace_sha256"):
            comparison.check_phase_bytes(b"wrong reference")
        before = {"Scripts/Sim/Native.gd": b"extends RefCounted\n",
                  "Scripts/Sim/u13_pysim/rules.py": b"VALUE = 1\n"}
        self.assertEqual(comparison.fingerprint(before), comparison.fingerprint(
            {k: v.replace(b"\n", b"\r\n") for k, v in reversed(list(before.items()))}))
        after = dict(before, **{"Scripts/Sim/u13_pysim/added.py": b"VALUE = 1\n"})
        self.assertNotEqual(comparison.fingerprint(before), comparison.fingerprint(after))


if __name__ == "__main__":
    unittest.main(verbosity=2)
