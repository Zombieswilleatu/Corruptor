
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

from repo_guardrails import all_static_checks, godot_sensitive_paths, repo_root

GODOT_SUMMARY_RE = re.compile(
    r"Golden checks complete:\s*(\d+)\s+passed,\s*(\d+)\s+failed\.",
    re.IGNORECASE,
)


def run_command(root: Path, label: str, cmd: list[str]) -> bool:
    print(f"\n== {label} ==")
    completed = subprocess.run(cmd, cwd=root)
    if completed.returncode != 0:
        print(f"FAIL: {label} exited {completed.returncode}")
        return False
    print(f"PASS: {label}")
    return True


def parse_godot_log(path: Path) -> tuple[int, int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    matches = list(GODOT_SUMMARY_RE.finditer(text))
    if not matches:
        raise RuntimeError(
            "Godot log has no 'Golden checks complete: N passed, N failed.' summary"
        )
    match = matches[-1]
    return int(match.group(1)), int(match.group(2))


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Corruptor precommit verification: Python tests, static parity/golden "
            "guards, Git whitespace checks, temporary-artifact checks, and optional "
            "Godot F2 log validation."
        )
    )
    parser.add_argument(
        "--quick",
        action="store_true",
        help="skip the Python unittest suite; static/git checks only",
    )
    parser.add_argument(
        "--godot-log",
        type=Path,
        help=(
            "path to a text copy of the Godot F2 output. If supplied, the latest "
            "golden summary must report 0 failures and the log must be newer than "
            "all changed Godot-sensitive files."
        ),
    )
    args = parser.parse_args()

    root = repo_root()
    print(f"Corruptor verify root: {root}")

    ok = True

    print("\n== repository guardrails ==")
    checks = all_static_checks(root)
    for label, errors in checks.items():
        if errors:
            ok = False
            print(f"FAIL: {label}")
            for error in errors:
                print(f"  - {error}")
        else:
            print(f"PASS: {label}")

    if not args.quick:
        ok &= run_command(
            root,
            "Python unit suite",
            [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"],
        )

    ok &= run_command(root, "git diff --check", ["git", "diff", "--check"])
    ok &= run_command(
        root,
        "git diff --cached --check",
        ["git", "diff", "--cached", "--check"],
    )

    sensitive = godot_sensitive_paths(root)
    if sensitive:
        print("\nGodot-sensitive changed paths:")
        for path in sensitive:
            print(f"  {path.relative_to(root)}")

    if args.godot_log:
        log_path = args.godot_log
        if not log_path.is_absolute():
            log_path = (root / log_path).resolve()

        print("\n== Godot F2 evidence ==")
        if not log_path.is_file():
            ok = False
            print(f"FAIL: Godot log does not exist: {log_path}")
        else:
            try:
                passed, failed = parse_godot_log(log_path)
            except Exception as exc:
                ok = False
                print(f"FAIL: {exc}")
            else:
                if failed != 0:
                    ok = False
                    print(f"FAIL: Godot golden suite reports {passed} passed, {failed} failed")
                else:
                    print(f"PASS: Godot golden suite reports {passed} passed, 0 failed")

                existing = [path for path in sensitive if path.exists()]
                if existing:
                    latest_change = max(path.stat().st_mtime for path in existing)
                    if log_path.stat().st_mtime < latest_change:
                        ok = False
                        print(
                            "FAIL: Godot log is older than at least one changed "
                            "Godot-sensitive file; rerun F2 after the latest edit."
                        )
                    else:
                        print("PASS: Godot log is newer than changed engine/golden files")
    elif sensitive:
        print(
            "\nNOTE: source/static checks can pass without Godot, but these changes "
            "touch engine/golden state. Run F2 after the latest edit, save/copy the "
            "output to a text file, then rerun:\n"
            "  py tools/verify.py --godot-log <that-file>"
        )

    print("\n== result ==")
    if not ok:
        print("NOT READY — fix the failures above.")
        return 1

    if sensitive and not args.godot_log:
        print("SOURCE CHECKS PASS — GODOT F2 EVIDENCE STILL REQUIRED.")
        return 0

    print("READY TO COMMIT.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
