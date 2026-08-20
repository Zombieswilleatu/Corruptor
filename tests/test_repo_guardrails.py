
from __future__ import annotations

import unittest

from tools import repo_guardrails


class RepositoryGuardrailTests(unittest.TestCase):
    def _assert_clean(self, label, errors):
        self.assertEqual(
            errors,
            [],
            msg=label + ":\n  " + "\n  ".join(errors),
        )

    def test_ai_policy_identity_is_consistent(self):
        self._assert_clean(
            "AI policy identity drift",
            repo_guardrails.check_policy_identity(),
        )

    def test_bastion_uses_one_canonical_live_switch(self):
        self._assert_clean(
            "Bastion alias drift",
            repo_guardrails.check_bastion_alias(),
        )

    def test_golden_files_are_structurally_self_consistent(self):
        self._assert_clean(
            "Golden integrity/provenance drift",
            repo_guardrails.check_golden_integrity(),
        )


if __name__ == "__main__":
    unittest.main()
