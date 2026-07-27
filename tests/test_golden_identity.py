import contextlib
import copy
import io
import json
import os
import tempfile
import unittest

import corruptor_sim as sim
import golden_master as golden


class CanonicalDefaultsTests(unittest.TestCase):
    def test_standalone_oracle_defaults_to_de_v2(self):
        self.assertEqual(
            sim.DOMINION_TRACK,
            11,
        )
        self.assertEqual(
            sim.DOMINION_REQUIREMENT,
            2,
        )
        self.assertEqual(
            sim.VARIANT,
            sim.DE_V2_VARIANT,
        )


class GoldenIdentityTests(unittest.TestCase):
    def setUp(self):
        self.variant = golden.de_v2_variant()
        self.constants = golden.de_v2_constants()
        golden.apply_config(
            self.variant,
            self.constants,
        )

    def tearDown(self):
        golden.apply_config(
            self.variant,
            self.constants,
        )

    def test_live_identity_refuses_mislabeled_constants(self):
        golden.sim.DOMINION_REQUIREMENT = 3

        with self.assertRaisesRegex(
            RuntimeError,
            "Golden identity refused",
        ):
            golden.assert_live_identity(
                self.variant,
                self.constants,
            )

    def test_trace_identity_refuses_constant_variant_and_policy_drift(self):
        trace = golden.gs.build_trace(
            "identity_probe",
            seed=0,
            variant=self.variant,
            constants=self.constants,
            snapshots=[],
            ai_version=golden.AI_VERSION,
        )
        corrupted = copy.deepcopy(
            trace,
        )
        corrupted["identity"]["constants"][
            "DOMINION_REQUIREMENT"
        ] = 3
        corrupted["identity"]["variant"][
            "kroni_hunger_decay"
        ] = False
        corrupted["ai_version"] = (
            "heuristic-2025.06-doctrine"
        )

        errors = golden.trace_identity_errors(
            corrupted,
            self.variant,
            self.constants,
        )

        self.assertEqual(
            len(errors),
            2,
        )
        self.assertIn(
            "ai_version",
            errors[0],
        )
        self.assertIn(
            "identity block",
            errors[1],
        )

    def test_disk_check_reads_trace_identity_instead_of_only_manifest_hash(self):
        trace = golden.gs.build_trace(
            "identity_probe",
            seed=0,
            variant=self.variant,
            constants=self.constants,
            snapshots=[],
            ai_version=golden.AI_VERSION,
        )
        corrupted = copy.deepcopy(
            trace,
        )
        corrupted["identity"]["constants"][
            "DOMINION_TRACK"
        ] = 12

        with tempfile.TemporaryDirectory() as directory:
            with open(
                os.path.join(
                    directory,
                    "_manifest.json",
                ),
                "w",
                encoding="utf-8",
            ) as file_handle:
                json.dump(
                    {
                        "schema_version": (
                            golden.gs.SCHEMA_VERSION
                        ),
                        "ai_version": golden.AI_VERSION,
                        "traces": {
                            "identity_probe": trace[
                                "trace_hash"
                            ],
                        },
                    },
                    file_handle,
                )

            with open(
                os.path.join(
                    directory,
                    "identity_probe.json",
                ),
                "w",
                encoding="utf-8",
            ) as file_handle:
                json.dump(
                    corrupted,
                    file_handle,
                )

            original_directory = golden.GOLDEN_DIR
            golden.GOLDEN_DIR = directory

            try:
                with contextlib.redirect_stdout(
                    io.StringIO()
                ):
                    failures = golden.check_all({
                        "identity_probe": trace,
                    })
            finally:
                golden.GOLDEN_DIR = (
                    original_directory
                )

        self.assertGreater(
            failures,
            0,
        )


if __name__ == "__main__":
    unittest.main()
