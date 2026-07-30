#!/usr/bin/env python3
"""Regenerate the compact Lord matrix after the approved Penitent fix."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

import lord_matrix_master as matrix_master


MATRIX_PATH = Path("golden/lord_matrix.json")
EXPECTED_CHANGED_SCENARIOS = {
    "matrix_orias_vs_kanifous_s1007",
    "matrix_valak_vs_kanifous_s1025",
    "matrix_kroni_vs_kanifous_s1034",
    "matrix_kalligan_vs_kanifous_s1043",
    "matrix_kanifous_vs_orias_s1007",
    "matrix_kanifous_vs_kroni_s1034",
    "matrix_kanifous_vs_kalligan_s1043",
    "matrix_kanifous_vs_odradek_s1061",
    "matrix_humbaba_vs_kanifous_s1071",
}
IMMUTABLE_TOP_LEVEL_KEYS = {
    "matrix_version",
    "schema_version",
    "ai_version",
    "identity",
    "lords",
    "ordered_matchups",
    "scenario_count",
    "unique_seed_count",
    "seed_scheme",
}


def scenario_map(matrix: dict) -> dict[str, dict]:
    raw_scenarios = matrix.get("scenarios", [])

    if not isinstance(raw_scenarios, list):
        raise RuntimeError("REFUSED: matrix scenarios are not a list")

    scenarios: dict[str, dict] = {}

    for scenario in raw_scenarios:
        if not isinstance(scenario, dict):
            raise RuntimeError("REFUSED: matrix has an invalid scenario row")

        name = str(scenario.get("name", ""))

        if not name or name in scenarios:
            raise RuntimeError(
                "REFUSED: matrix has a missing or duplicate scenario name"
            )

        scenarios[name] = scenario

    if len(scenarios) != len(raw_scenarios):
        raise RuntimeError(
            "REFUSED: matrix has a missing, duplicate, or invalid scenario name"
        )

    return scenarios


def encoded_matrix(matrix: dict) -> bytes:
    return (
        json.dumps(
            matrix,
            indent=2,
            sort_keys=True,
        )
        + "\n"
    ).encode("utf-8")


def main() -> int:
    if not MATRIX_PATH.is_file():
        raise RuntimeError(f"REFUSED: missing matrix: {MATRIX_PATH}")

    old_bytes = MATRIX_PATH.read_bytes()

    try:
        old_matrix = json.loads(old_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RuntimeError(
            f"REFUSED: existing matrix is not valid UTF-8 JSON: {exc}"
        ) from exc

    new_matrix = matrix_master.build_matrix()
    old_scenarios = scenario_map(old_matrix)
    new_scenarios = scenario_map(new_matrix)

    if set(old_matrix) != set(new_matrix):
        raise RuntimeError(
            "REFUSED: top-level matrix keys changed; "
            f"old={sorted(old_matrix)} new={sorted(new_matrix)}"
        )

    if set(old_scenarios) != set(new_scenarios):
        missing = sorted(set(old_scenarios) - set(new_scenarios))
        added = sorted(set(new_scenarios) - set(old_scenarios))
        raise RuntimeError(
            "REFUSED: scenario membership changed; "
            f"missing={missing} added={added}"
        )

    changed = {
        name
        for name in old_scenarios
        if old_scenarios[name] != new_scenarios[name]
    }

    if changed != EXPECTED_CHANGED_SCENARIOS:
        raise RuntimeError(
            "REFUSED: unexpected changed scenario set\n"
            f"expected={sorted(EXPECTED_CHANGED_SCENARIOS)}\n"
            f"actual={sorted(changed)}"
        )

    immutable_drift = {
        key: (old_matrix.get(key), new_matrix.get(key))
        for key in IMMUTABLE_TOP_LEVEL_KEYS
        if old_matrix.get(key) != new_matrix.get(key)
    }

    if immutable_drift:
        raise RuntimeError(
            "REFUSED: immutable matrix metadata changed: "
            f"{immutable_drift}"
        )

    old_sha = hashlib.sha256(old_bytes).hexdigest()
    backup_path = (
        Path(tempfile.gettempdir())
        / f"corruptor_lord_matrix_before_penitent_fix_{old_sha[:16]}.json"
    )

    if backup_path.exists():
        if backup_path.read_bytes() != old_bytes:
            raise RuntimeError(
                "REFUSED: backup path exists with different content: "
                f"{backup_path}"
            )
    else:
        backup_path.write_bytes(old_bytes)

    new_bytes = encoded_matrix(new_matrix)
    temporary = MATRIX_PATH.with_name(MATRIX_PATH.name + ".verified_regen.tmp")

    if temporary.exists():
        raise RuntimeError(
            f"REFUSED: temporary path already exists: {temporary}"
        )

    try:
        temporary.write_bytes(new_bytes)

        if json.loads(temporary.read_text(encoding="utf-8")) != new_matrix:
            raise RuntimeError("REFUSED: temporary matrix verification failed")

        os.replace(temporary, MATRIX_PATH)
    finally:
        if temporary.exists():
            temporary.unlink()

    print("Regenerated the compact 81-matchup Lord matrix.")
    print("Changed exactly these nine approved scenarios:")

    for name in sorted(changed):
        print(f"  {name}")

    print(
        "sim_version: "
        f"{old_matrix.get('sim_version')} -> {new_matrix.get('sim_version')}"
    )
    print(f"Preserved previous matrix at: {backup_path}")
    print("No simulation code, soak batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
