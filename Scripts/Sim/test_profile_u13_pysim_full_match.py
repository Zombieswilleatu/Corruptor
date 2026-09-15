"""Observer guards and real cProfile caller-count semantics; no engine changes."""

import copy
import cProfile
import json
import math
import pstats
import unittest

import profile_u13_pysim_full_match as observer


class ProfileObserverTests(unittest.TestCase):
    def test_changed_engine_or_inputs_cannot_reuse_acceptance(self):
        evidence = json.loads(observer.EVIDENCE.read_text(encoding="utf-8"))
        for source, inputs in [("changed", observer.ACCEPTED_INPUTS),
                               (observer.ACCEPTED_SOURCE, "changed")]:
            with self.assertRaises(ValueError):
                observer.validate_accepted(evidence, source, inputs)

    def test_failed_acceptance_cannot_be_presented_as_profile_prerequisite(self):
        original = json.loads(observer.EVIDENCE.read_text(encoding="utf-8"))
        for branch in ("accepted", "tests", "replay"):
            evidence = copy.deepcopy(original)
            if branch == "accepted": evidence["accepted"] = False
            elif branch == "tests": evidence["runtimes"]["pypy"]["unit_tests"]["failed"] = 1
            else: evidence["accepted_reference_verification"]["deliberate_mismatches_rejected"] = 12
            with self.assertRaises(ValueError):
                observer.validate_accepted(evidence, observer.ACCEPTED_SOURCE, observer.ACCEPTED_INPUTS)

    def test_recursive_caller_counts_are_not_swapped_or_collapsed(self):
        def recurse(n):
            if n: recurse(n - 1)
        profile = cProfile.Profile()
        profile.runcall(recurse, 4)
        stats = pstats.Stats(profile)
        rows, modules = observer.read_stats(stats)
        row = next(r for r in rows if r["function"] == "recurse")
        self.assertEqual((1, 5), (row["primitive_calls"], row["total_calls"]))
        caller = next(c for c in row["callers"] if c["function"] == "recurse")
        self.assertEqual((1, 4), (caller["primitive_calls"], caller["total_calls"]))
        self.assertEqual(len(stats.stats), len(rows))
        self.assertTrue(math.isclose(stats.total_tt, sum(modules.values()), rel_tol=1e-12))
        json.dumps(rows)


if __name__ == "__main__":
    unittest.main(verbosity=2)
