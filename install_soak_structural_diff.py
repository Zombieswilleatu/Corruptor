#!/usr/bin/env python3
"""Add concise terminal-round structural diffs to the parity soak."""

from __future__ import annotations

import os
from pathlib import Path
import sys


def read(path: Path) -> tuple[str, str]:
    data = path.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    return data.decode("utf-8").replace("\r\n", "\n"), newline


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"REFUSED: expected {label} exactly once, found {count}"
        )
    return text.replace(old, new, 1)


def patch_matrix(text: str) -> str:
    if 'hash_failure["actual_snapshot"]' in text:
        raise RuntimeError("REFUSED: actual-snapshot reporting already installed")

    old = '''                if expected_hash != actual_hash:
                        return _fail(
                                scenario_name,
                                "State hash divergence at %s: want=%s got=%s"
                                % [
                                        actual_checkpoint,
                                        expected_hash.left(
                                                16
                                        ),
                                        actual_hash.left(
                                                16
                                        ),
                                ]
                        )
'''

    new = '''                if expected_hash != actual_hash:
                        var hash_failure: Dictionary = _fail(
                                scenario_name,
                                "State hash divergence at %s: want=%s got=%s"
                                % [
                                        actual_checkpoint,
                                        expected_hash.left(
                                                16
                                        ),
                                        actual_hash.left(
                                                16
                                        ),
                                ]
                        )

                        hash_failure["checkpoint"] = actual_checkpoint
                        hash_failure["actual_snapshot"] = actual_snapshot

                        return hash_failure
'''
    return replace_once(text, old, new, "matrix hash-failure block")


def patch_runner(text: str) -> str:
    if "terminal-round structural differences:" in text:
        raise RuntimeError("REFUSED: soak structural diff already installed")

    marker = '''        print(
                "expected terminal snapshot: %s"
                % JSON.stringify(
                        scenario.get(
                                "terminal_snapshot",
                                {}
                        ),
                        "",
                        true
                )
        )
'''

    replacement = '''        var expected_terminal_raw = scenario.get(
                "terminal_snapshot",
                {}
        )
        var actual_snapshot_raw = result.get(
                "actual_snapshot",
                {}
        )

        if (
                typeof(expected_terminal_raw) == TYPE_DICTIONARY
                and typeof(actual_snapshot_raw) == TYPE_DICTIONARY
        ):
                var expected_terminal: Dictionary = expected_terminal_raw
                var actual_snapshot: Dictionary = actual_snapshot_raw

                if (
                        int(actual_snapshot.get("round", -1))
                        == int(scenario.get("round", -2))
                ):
                        var expected_checkpoint: Dictionary = (
                                expected_terminal.duplicate(true)
                        )
                        expected_checkpoint["checkpoint"] = String(
                                actual_snapshot.get(
                                        "checkpoint",
                                        ""
                                )
                        )

                        var divergences: Array[Dictionary] = (
                                GoldenMasterData._all_divergences(
                                        [expected_checkpoint],
                                        [actual_snapshot],
                                        32
                                )
                        )

                        print("terminal-round structural differences:")

                        if divergences.is_empty():
                                print("  none (hash-only serialization difference)")
                        else:
                                for divergence: Dictionary in divergences:
                                        print(
                                                "  %s expected=%s actual=%s"
                                                % [
                                                        String(
                                                                divergence.get(
                                                                        "field",
                                                                        "?"
                                                                )
                                                        ),
                                                        str(
                                                                divergence.get(
                                                                        "want",
                                                                        "<missing>"
                                                                )
                                                        ),
                                                        str(
                                                                divergence.get(
                                                                        "got",
                                                                        "<missing>"
                                                                )
                                                        ),
                                                ]
                                        )
                else:
                        print(
                                "actual checkpoint snapshot: %s"
                                % JSON.stringify(
                                        actual_snapshot,
                                        "",
                                        true
                                )
                        )

        print(
                "expected terminal snapshot: %s"
                % JSON.stringify(
                        expected_terminal_raw,
                        "",
                        true
                )
        )
'''
    return replace_once(text, marker, replacement, "soak expected-state block")


def main() -> int:
    matrix_path = Path("Scripts/Sim/LordMatrixTests.gd")
    runner_path = Path("Scripts/Sim/LordMatrixSoakRunner.gd")

    for path in (matrix_path, runner_path):
        if not path.is_file():
            raise RuntimeError(f"REFUSED: missing required file: {path}")

    matrix, matrix_newline = read(matrix_path)
    runner, runner_newline = read(runner_path)

    updates = {
        matrix_path: (patch_matrix(matrix), matrix_newline),
        runner_path: (patch_runner(runner), runner_newline),
    }
    temporaries: dict[Path, Path] = {}

    try:
        for path, (content, newline) in updates.items():
            temporary = path.with_name(path.name + ".structural_diff.tmp")
            if temporary.exists():
                raise RuntimeError(
                    f"REFUSED: temporary path already exists: {temporary}"
                )
            temporary.write_bytes(
                content.replace("\n", newline).encode("utf-8")
            )
            temporaries[path] = temporary

        for path, temporary in temporaries.items():
            os.replace(temporary, path)
    finally:
        for temporary in temporaries.values():
            if temporary.exists():
                temporary.unlink()

    print("Installed concise soak structural-diff reporting.")
    print("No oracle, golden file, retained batch, or Git ref was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
