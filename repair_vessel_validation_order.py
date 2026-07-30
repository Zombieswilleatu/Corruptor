#!/usr/bin/env python3
"""Restore atomic Vessel validation while keeping post-Consume reevaluation."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys


PATH = Path("Scripts/Sim/ResolutionActionAftermathEngine.gd")
TIMING_MARKER = (
    "Python reevaluates Vessel after action aftermath and Kroni Consume"
)
REPAIR_MARKER = "Validate the cached Vessel decision before aftermath mutation"
PROBE_MARKER = "DEBUG SOAK DEIMOS KRONI R9 VESSEL"


def _indent_block(text: str, indent: str) -> str:
    return "".join(
        indent + line if line.strip() else line
        for line in text.splitlines(keepends=True)
    )


def patch(text: str) -> str:
    if REPAIR_MARKER in text:
        raise RuntimeError(
            "REFUSED: Vessel validation-order repair is already installed"
        )

    if text.count(TIMING_MARKER) != 1:
        raise RuntimeError(
            "REFUSED: expected the post-Consume timing marker once, "
            f"found {text.count(TIMING_MARKER)}"
        )

    if PROBE_MARKER in text:
        raise RuntimeError(
            "REFUSED: temporary Deimos-vs-Kroni Vessel probe still exists"
        )

    destruction_pattern = re.compile(
        r"^(?P<indent>[ \t]+)var destruction_recorded: bool = \($",
        re.MULTILINE,
    )
    destruction_matches = list(destruction_pattern.finditer(text))

    if len(destruction_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the destruction boundary once, "
            f"found {len(destruction_matches)}"
        )

    indent = destruction_matches[0].group("indent")
    deep = indent + indent

    validation_start_pattern = re.compile(
        rf"^{re.escape(indent)}var vessel_validation: Dictionary = \($",
        re.MULTILINE,
    )
    validation_starts = list(validation_start_pattern.finditer(text))

    if len(validation_starts) != 1:
        raise RuntimeError(
            "REFUSED: expected the late Vessel validation block once, "
            f"found {len(validation_starts)}"
        )

    vessel_pattern = re.compile(
        rf"^{re.escape(indent)}var vessel_event: Dictionary = \($",
        re.MULTILINE,
    )
    vessel_matches = list(vessel_pattern.finditer(text))

    if len(vessel_matches) != 1:
        raise RuntimeError(
            "REFUSED: expected the Vessel resolution boundary once, "
            f"found {len(vessel_matches)}"
        )

    validation_start = validation_starts[0].start()
    validation_end = vessel_matches[0].start()

    if validation_start >= validation_end:
        raise RuntimeError(
            "REFUSED: late validation does not precede Vessel resolution"
        )

    validation_block = text[validation_start:validation_end]
    expected_fragments = [
        "var vessel_validation: Dictionary = (",
        "_validate_vessel_decision(",
        "effective_vessel_decision",
        '"invalid_vessel_decision"',
    ]

    for fragment in expected_fragments:
        if validation_block.count(fragment) != 1:
            raise RuntimeError(
                "REFUSED: unexpected late validation block; "
                f"expected {fragment!r} once, found "
                f"{validation_block.count(fragment)}"
            )

    early_validation = validation_block.replace(
        "effective_vessel_decision",
        "vessel_decision",
        1,
    )
    early_validation = (
        f"{indent}# {REPAIR_MARKER}.\n"
        + early_validation
    )

    refreshed_validation = validation_block.replace(
        f"{indent}var vessel_validation: Dictionary = (",
        f"{indent}vessel_validation = (",
        1,
    )
    refreshed_validation = _indent_block(
        refreshed_validation,
        indent,
    )
    refreshed_validation = (
        f"{deep}# Revalidate the refreshed doctrine result before resolving it.\n"
        + refreshed_validation
    )

    without_late = (
        text[:validation_start]
        + refreshed_validation
        + text[validation_end:]
    )

    destruction_matches = list(
        destruction_pattern.finditer(without_late)
    )

    if len(destruction_matches) != 1:
        raise RuntimeError(
            "REFUSED: destruction boundary changed unexpectedly during repair"
        )

    insert_at = destruction_matches[0].start()
    return (
        without_late[:insert_at]
        + early_validation
        + without_late[insert_at:]
    )


def main() -> int:
    if not PATH.is_file():
        raise RuntimeError(f"REFUSED: missing required file: {PATH}")

    data = PATH.read_bytes()
    newline = "\r\n" if b"\r\n" in data else "\n"
    text = data.decode("utf-8").replace("\r\n", "\n")
    updated = patch(text)
    temporary = PATH.with_name(PATH.name + ".validation_repair.tmp")

    if temporary.exists():
        raise RuntimeError(
            f"REFUSED: temporary path already exists: {temporary}"
        )

    try:
        temporary.write_bytes(
            updated.replace("\n", newline).encode("utf-8")
        )
        os.replace(temporary, PATH)
    finally:
        if temporary.exists():
            temporary.unlink()

    print("Restored atomic cached Vessel validation.")
    print("Kept doctrine reevaluation after Kroni Consume.")
    print(
        "Python oracle, golden data, retained batch, and Git refs "
        "were unchanged."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
