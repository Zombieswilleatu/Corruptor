
from __future__ import annotations

import argparse
import re
import shutil
from datetime import datetime
from pathlib import Path

from repo_guardrails import policy_id, repo_root

VALID_ID = re.compile(r"^softmax-\d{4}\.\d{2}-[A-Za-z0-9._-]+$")

POLICY_SOURCE_PATHS = (
    "corruptor_softmax_policy.py",
    "Scripts/Sim/GoldenTests.gd",
    "Scripts/Sim/BotRoundEngineTests.gd",
    "Scripts/Sim/SeededGameSetupTests.gd",
    "Scripts/Sim/LordMatrixTests.gd",
    "Scripts/Sim/LordMatrixSoakRunner.gd",
)


def canonical_policy_files(root: Path, old_id: str) -> list[Path]:
    candidates = [root / rel for rel in POLICY_SOURCE_PATHS]
    candidates.extend(sorted((root / "golden").glob("*.json")))
    result: list[Path] = []
    old_bytes = old_id.encode("ascii")
    for path in candidates:
        if not path.is_file():
            if path.suffix == ".gd" or path.name == "corruptor_softmax_policy.py":
                raise RuntimeError(f"REFUSED: missing canonical policy file: {path}")
            continue
        if old_bytes in path.read_bytes():
            result.append(path)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Deliberately bump Corruptor's pinned golden/softmax AI policy id in "
            "the canonical policy-bearing source files and golden metadata. "
            "Dry-run by default; --apply creates a timestamped backup."
        )
    )
    parser.add_argument("new_id")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    root = repo_root()
    old_id = policy_id(root)
    new_id = args.new_id.strip()

    if not VALID_ID.fullmatch(new_id):
        raise RuntimeError(
            "REFUSED: policy id must look like "
            "softmax-YYYY.MM-description"
        )
    if new_id == old_id:
        raise RuntimeError("REFUSED: new policy id is already current")

    files = canonical_policy_files(root, old_id)
    if not files:
        raise RuntimeError(f"REFUSED: no canonical files contain {old_id!r}")

    print(f"AI policy bump: {old_id} -> {new_id}")
    print("Canonical files that will be relabeled:")
    for path in files:
        print(f"  {path.relative_to(root)}")

    # Safety: policy-bearing files may not contain a third softmax policy id.
    softmax_re = re.compile(rb"softmax-\d{4}\.\d{2}-[A-Za-z0-9._-]+")
    stray: dict[str, set[str]] = {}
    for path in files:
        values = {
            match.decode("ascii")
            for match in softmax_re.findall(path.read_bytes())
        }
        bad = values - {old_id, new_id}
        if bad:
            stray[str(path.relative_to(root))] = bad
    if stray:
        raise RuntimeError(f"REFUSED: mixed unexpected policy ids: {stray}")

    if not args.apply:
        print("\nDRY RUN PASS — no files were changed.")
        print("Rerun with --apply after reviewing this file list.")
        return 0

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = root / ".corruptor_backups" / f"{stamp}_before_policy_id_bump"
    backup.mkdir(parents=True, exist_ok=False)

    old_bytes = old_id.encode("ascii")
    new_bytes = new_id.encode("ascii")

    for path in files:
        rel = path.relative_to(root)
        destination = backup / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)

    try:
        for path in files:
            data = path.read_bytes()
            count = data.count(old_bytes)
            if count < 1:
                raise RuntimeError(
                    f"REFUSED: {path.relative_to(root)} lost expected old policy id"
                )
            path.write_bytes(data.replace(old_bytes, new_bytes))
    except Exception:
        for path in files:
            saved = backup / path.relative_to(root)
            if saved.exists():
                shutil.copy2(saved, path)
        raise

    print(f"\nPASS: bumped policy id in {len(files)} canonical files.")
    print(f"Backup: {backup}")
    print(
        "Next: run py tools/verify.py --quick. Behavior-changing policy bumps "
        "still require deliberate selective golden rebaseline + Godot F2."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc))
        raise SystemExit(1)
