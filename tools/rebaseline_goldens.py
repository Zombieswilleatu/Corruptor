
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

from repo_guardrails import all_static_checks, policy_id, repo_root, trace_hash

MATRIX_PATH = Path("golden/lord_matrix.json")
MANIFEST_PATH = Path("golden/_manifest.json")
PROVENANCE_PATH = Path("golden/_provenance.json")
PRESERVED_CHECKPOINTS = ("game:deal", "round:01:end")


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise RuntimeError(f"REFUSED: {path} is not a JSON object")
    return data


def write_json_atomic(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".rebaseline.tmp")
    if temp.exists():
        raise RuntimeError(f"REFUSED: temporary path already exists: {temp}")
    payload = (
        json.dumps(data, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
    ).encode("utf-8")
    try:
        temp.write_bytes(payload)
        check = json.loads(temp.read_text(encoding="utf-8"))
        if check != data:
            raise RuntimeError(f"REFUSED: temporary JSON verification failed: {path}")
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()


def scenario_map(matrix: dict) -> dict[str, dict]:
    rows = matrix.get("scenarios")
    if not isinstance(rows, list):
        raise RuntimeError("REFUSED: matrix scenarios is not a list")
    result: dict[str, dict] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise RuntimeError("REFUSED: matrix has a non-object scenario")
        name = str(row.get("name", ""))
        if not name or name in result:
            raise RuntimeError("REFUSED: matrix has missing/duplicate scenario name")
        result[name] = row
    return result


def checkpoint_map(row: dict) -> dict[str, dict]:
    checkpoints = row.get("checkpoints", [])
    if not isinstance(checkpoints, list):
        raise RuntimeError(f"REFUSED: {row.get('name')} checkpoints is not a list")
    result: dict[str, dict] = {}
    for checkpoint in checkpoints:
        if not isinstance(checkpoint, dict):
            raise RuntimeError(f"REFUSED: {row.get('name')} has invalid checkpoint")
        name = str(checkpoint.get("checkpoint", ""))
        if not name or name in result:
            raise RuntimeError(
                f"REFUSED: {row.get('name')} has missing/duplicate checkpoint"
            )
        result[name] = checkpoint
    return result


def snapshot_map(trace: dict) -> dict[str, dict]:
    snapshots = trace.get("snapshots")
    if not isinstance(snapshots, list):
        raise RuntimeError(f"REFUSED: {trace.get('name')} snapshots is not a list")
    result: dict[str, dict] = {}
    for snapshot in snapshots:
        if not isinstance(snapshot, dict):
            raise RuntimeError(f"REFUSED: {trace.get('name')} has invalid snapshot")
        name = str(snapshot.get("checkpoint", ""))
        if not name or name in result:
            raise RuntimeError(
                f"REFUSED: {trace.get('name')} has missing/duplicate snapshot checkpoint"
            )
        result[name] = snapshot
    return result


def validate_matrix(
    current: dict,
    candidate: dict,
    expected_changed: set[str] | None,
    allow_metadata: set[str],
    allow_round1_change: bool,
) -> set[str]:
    current_rows = scenario_map(current)
    candidate_rows = scenario_map(candidate)

    current_order = [row["name"] for row in current["scenarios"]]
    candidate_order = [row["name"] for row in candidate["scenarios"]]
    if current_order != candidate_order:
        raise RuntimeError("REFUSED: matrix scenario membership/order changed")

    all_keys = set(current) | set(candidate)
    metadata_drift = {}
    for key in sorted(all_keys - {"scenarios"}):
        if current.get(key) != candidate.get(key) and key not in allow_metadata:
            metadata_drift[key] = (current.get(key), candidate.get(key))
    if metadata_drift:
        raise RuntimeError(
            "REFUSED: matrix metadata drift outside --allow-metadata: "
            f"{metadata_drift}"
        )

    changed = {
        name
        for name in current_rows
        if current_rows[name] != candidate_rows[name]
    }

    if expected_changed is not None and changed != expected_changed:
        raise RuntimeError(
            "REFUSED: changed matrix scenario set is not exactly approved\n"
            f"expected={sorted(expected_changed)}\n"
            f"actual={sorted(changed)}"
        )

    if not allow_round1_change:
        for name in sorted(changed):
            before = checkpoint_map(current_rows[name])
            after = checkpoint_map(candidate_rows[name])
            for checkpoint in PRESERVED_CHECKPOINTS:
                if checkpoint not in before or checkpoint not in after:
                    raise RuntimeError(
                        f"REFUSED: {name} is missing preserved checkpoint {checkpoint}"
                    )
                if before[checkpoint] != after[checkpoint]:
                    raise RuntimeError(
                        f"REFUSED: {name} changed preserved checkpoint {checkpoint}"
                    )

    return changed


def validate_trace(
    current: dict,
    candidate: dict,
    allow_metadata: set[str],
    allow_round1_change: bool,
) -> None:
    current_name = str(current.get("name", ""))
    candidate_name = str(candidate.get("name", ""))
    if not current_name or current_name != candidate_name:
        raise RuntimeError(
            f"REFUSED: trace name mismatch current={current_name!r} "
            f"candidate={candidate_name!r}"
        )

    all_keys = set(current) | set(candidate)
    metadata_drift = {}
    for key in sorted(all_keys - {"snapshots", "trace_hash"}):
        if current.get(key) != candidate.get(key) and key not in allow_metadata:
            metadata_drift[key] = (current.get(key), candidate.get(key))
    if metadata_drift:
        raise RuntimeError(
            f"REFUSED: {current_name} metadata drift outside --allow-metadata: "
            f"{metadata_drift}"
        )

    snapshots = candidate.get("snapshots")
    if not isinstance(snapshots, list):
        raise RuntimeError(f"REFUSED: candidate {current_name} snapshots is not a list")
    computed = trace_hash(snapshots)
    if candidate.get("trace_hash") != computed:
        raise RuntimeError(
            f"REFUSED: candidate {current_name} trace_hash is corrupt: "
            f"recorded={candidate.get('trace_hash')} computed={computed}"
        )

    if current_name.startswith("game_") and not allow_round1_change:
        before = snapshot_map(current)
        after = snapshot_map(candidate)
        for checkpoint in PRESERVED_CHECKPOINTS:
            if checkpoint not in before or checkpoint not in after:
                raise RuntimeError(
                    f"REFUSED: {current_name} is missing preserved checkpoint {checkpoint}"
                )
            if before[checkpoint] != after[checkpoint]:
                raise RuntimeError(
                    f"REFUSED: {current_name} changed preserved checkpoint {checkpoint}"
                )


def parse_trace_specs(values: list[str], root: Path) -> dict[str, Path]:
    result: dict[str, Path] = {}
    for value in values:
        if "=" not in value:
            raise RuntimeError(
                f"REFUSED: --trace must be NAME=PATH, got {value!r}"
            )
        name, raw_path = value.split("=", 1)
        name = name.strip()
        if not name or name in result:
            raise RuntimeError(f"REFUSED: duplicate/empty trace name: {name!r}")
        path = Path(raw_path)
        if not path.is_absolute():
            path = (root / path).resolve()
        if not path.is_file():
            raise RuntimeError(f"REFUSED: trace candidate missing: {path}")
        result[name] = path
    return result


def read_expected(args, root: Path) -> set[str] | None:
    names = set(args.expect or [])
    if args.expect_file:
        path = args.expect_file
        if not path.is_absolute():
            path = (root / path).resolve()
        if not path.is_file():
            raise RuntimeError(f"REFUSED: expected-change file missing: {path}")
        for line in path.read_text(encoding="utf-8").splitlines():
            clean = line.strip()
            if clean and not clean.startswith("#"):
                names.add(clean)
    return names if names else None


def default_provenance() -> dict:
    return {
        "schema_version": 1,
        "notes": [
            (
                "The Lord matrix is curated/mixed provenance. Never replace it "
                "wholesale from a single simulator run."
            ),
            (
                "Use tools/rebaseline_goldens.py for exact-set selective installs "
                "with preserved early checkpoints."
            ),
        ],
        "artifacts": {
            "lord_matrix.json": {
                "authority": "mixed-curated",
                "replacement_policy": "selective-only",
            },
            "game_deimos_valak_s1.json": {
                "authority": "godot",
                "replacement_policy": "selective-only",
            },
        },
        "events": [],
    }


def backup_paths(root: Path, paths: list[Path], label: str) -> Path:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = root / ".corruptor_backups" / f"{stamp}_{label}"
    backup.mkdir(parents=True, exist_ok=False)
    for path in paths:
        if not path.exists():
            continue
        rel = path.relative_to(root)
        destination = backup / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    return backup


def restore_backup(root: Path, backup: Path, paths: list[Path]) -> None:
    for path in paths:
        rel = path.relative_to(root)
        saved = backup / rel
        if saved.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(saved, path)
        elif path.exists():
            path.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Deliberate selective golden installer. Dry-run is the default. "
            "Matrix replacement requires an exact approved changed-scenario set."
        )
    )
    parser.add_argument("--matrix-candidate", type=Path)
    parser.add_argument(
        "--trace",
        action="append",
        default=[],
        metavar="NAME=PATH",
        help="selectively install a full trace candidate; repeatable",
    )
    parser.add_argument(
        "--expect",
        action="append",
        default=[],
        help="approved changed matrix scenario name; repeatable",
    )
    parser.add_argument(
        "--expect-file",
        type=Path,
        help="text file with one approved changed matrix scenario per line",
    )
    parser.add_argument(
        "--authority",
        choices=("godot", "python"),
        help="authority that generated the candidate; required with --apply",
    )
    parser.add_argument(
        "--allow-metadata",
        action="append",
        default=[],
        help="explicitly allow a changed JSON metadata key; repeatable",
    )
    parser.add_argument(
        "--allow-round1-change",
        action="store_true",
        help="permit game:deal / round:01:end changes (normally refused)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="install after all guards pass; without this option nothing is written",
    )
    args = parser.parse_args()

    root = repo_root()
    allow_metadata = set(args.allow_metadata or [])
    expected = read_expected(args, root)
    traces = parse_trace_specs(args.trace, root)

    if not args.matrix_candidate and not traces:
        raise RuntimeError("REFUSED: provide --matrix-candidate and/or --trace")

    if args.apply and not args.authority:
        raise RuntimeError("REFUSED: --authority is required with --apply")

    current_matrix = None
    candidate_matrix = None
    changed: set[str] = set()

    if args.matrix_candidate:
        candidate_path = args.matrix_candidate
        if not candidate_path.is_absolute():
            candidate_path = (root / candidate_path).resolve()
        if not candidate_path.is_file():
            raise RuntimeError(f"REFUSED: matrix candidate missing: {candidate_path}")

        current_matrix = load_json(root / MATRIX_PATH)
        candidate_matrix = load_json(candidate_path)
        changed = validate_matrix(
            current_matrix,
            candidate_matrix,
            expected,
            allow_metadata,
            args.allow_round1_change,
        )

        if expected is None:
            print("DISCOVERY ONLY: candidate changed these matrix rows:")
            for name in sorted(changed):
                print(f"  {name}")
            if args.apply:
                raise RuntimeError(
                    "REFUSED: matrix apply requires --expect and/or --expect-file "
                    "with the exact approved changed set"
                )

    candidate_traces: dict[str, dict] = {}
    for name, path in traces.items():
        current_path = root / "golden" / f"{name}.json"
        if not current_path.is_file():
            raise RuntimeError(f"REFUSED: current trace missing: {current_path}")
        current = load_json(current_path)
        candidate = load_json(path)
        if candidate.get("name") != name:
            raise RuntimeError(
                f"REFUSED: --trace name {name!r} does not match candidate "
                f"name {candidate.get('name')!r}"
            )
        validate_trace(
            current,
            candidate,
            allow_metadata,
            args.allow_round1_change,
        )
        candidate_traces[name] = candidate

    expected_policy = policy_id(root)
    objects = []
    if candidate_matrix is not None:
        objects.append(("matrix", candidate_matrix))
    objects.extend((name, trace) for name, trace in candidate_traces.items())
    for label, obj in objects:
        if obj.get("ai_version") != expected_policy:
            raise RuntimeError(
                f"REFUSED: {label} ai_version={obj.get('ai_version')!r}; "
                f"current policy is {expected_policy!r}. Run bump_policy_id.py "
                "first when behavior policy changes."
            )

    print("\nSELECTIVE REBASELINE PLAN")
    if candidate_matrix is not None:
        print(f"  matrix rows changed: {len(changed)}")
        for name in sorted(changed):
            print(f"    {name}")
        if not args.allow_round1_change:
            print("  matrix early checkpoints preserved: game:deal, round:01:end")
    if candidate_traces:
        print(f"  full traces replaced: {', '.join(sorted(candidate_traces))}")
        if not args.allow_round1_change:
            print("  game trace early checkpoints preserved: game:deal, round:01:end")
    print(f"  authority: {args.authority or '<dry-run not specified>'}")

    if not args.apply:
        print("\nDRY RUN PASS — no files were changed.")
        if candidate_matrix is not None and expected is None:
            print(
                "Copy the changed row names above into --expect/--expect-file, "
                "review them, then rerun with --apply."
            )
        return 0

    install_paths = [root / MANIFEST_PATH, root / PROVENANCE_PATH]
    if candidate_matrix is not None:
        install_paths.append(root / MATRIX_PATH)
    install_paths.extend(
        root / "golden" / f"{name}.json"
        for name in candidate_traces
    )
    install_paths = list(dict.fromkeys(install_paths))

    candidate_files: list[Path] = []
    if args.matrix_candidate:
        candidate_files.append(candidate_path)
    candidate_files.extend(traces.values())
    candidate_repo_paths: list[Path] = []
    for candidate_file in candidate_files:
        try:
            candidate_file.relative_to(root)
        except ValueError:
            continue
        candidate_repo_paths.append(candidate_file)

    backup_paths_list = list(dict.fromkeys(install_paths + candidate_repo_paths))
    backup = backup_paths(
        root,
        backup_paths_list,
        "before_selective_golden_rebaseline",
    )
    print(f"Backup: {backup}")

    try:
        if candidate_matrix is not None:
            write_json_atomic(root / MATRIX_PATH, candidate_matrix)

        manifest = load_json(root / MANIFEST_PATH)
        manifest["ai_version"] = expected_policy

        for name, candidate in candidate_traces.items():
            write_json_atomic(root / "golden" / f"{name}.json", candidate)
            manifest.setdefault("traces", {})[name] = candidate["trace_hash"]

        write_json_atomic(root / MANIFEST_PATH, manifest)

        provenance_path = root / PROVENANCE_PATH
        provenance = (
            load_json(provenance_path)
            if provenance_path.is_file()
            else default_provenance()
        )
        event = {
            "timestamp_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
            "authority": args.authority,
            "mode": "selective",
            "matrix_changed_scenarios": sorted(changed),
            "trace_names": sorted(candidate_traces),
            "preserved_checkpoints": (
                []
                if args.allow_round1_change
                else list(PRESERVED_CHECKPOINTS)
            ),
        }
        provenance.setdefault("events", []).append(event)
        provenance.setdefault("artifacts", {}).setdefault(
            "lord_matrix.json",
            {
                "authority": "mixed-curated",
                "replacement_policy": "selective-only",
            },
        )
        if candidate_matrix is not None:
            provenance["artifacts"]["lord_matrix.json"][
                "last_selective_authority"
            ] = args.authority
        for name in candidate_traces:
            provenance["artifacts"][f"{name}.json"] = {
                "authority": args.authority,
                "replacement_policy": "selective-only",
            }
        write_json_atomic(provenance_path, provenance)

        # Candidate files created inside the repo are temporary evidence.
        # They were included in the backup, so rollback can restore them.
        for candidate_file in candidate_repo_paths:
            if candidate_file.name.endswith("_candidate.json") and candidate_file.exists():
                candidate_file.unlink()
                print(f"Removed temporary candidate: {candidate_file.relative_to(root)}")

        failures = all_static_checks(root)
        flat = [
            f"{label}: {error}"
            for label, errors in failures.items()
            for error in errors
        ]
        if flat:
            raise RuntimeError(
                "Post-install guardrails failed:\n  " + "\n  ".join(flat)
            )

    except Exception:
        print("Install failed; restoring backup.", file=sys.stderr)
        restore_backup(root, backup, backup_paths_list)
        raise

    print("\nSELECTIVE REBASELINE INSTALLED SAFELY.")
    print("Next: run Python tests, then Godot F2, then tools/verify.py.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
