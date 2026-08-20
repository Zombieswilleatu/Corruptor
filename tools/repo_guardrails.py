
from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path

POLICY_RE = re.compile(r'POLICY_ID\s*=\s*["\']([^"\']+)["\']')
SOFTMAX_RE = re.compile(r'softmax-\d{4}\.\d{2}-[A-Za-z0-9._-]+')
OLD_BASTION_READ = "VARIANT.get('bastion_fortified', False)"


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_json(obj) -> str:
    return json.dumps(
        obj,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    )


def trace_hash(snapshots: list[dict]) -> str:
    digest = hashlib.sha256()
    for snapshot in snapshots:
        digest.update(canonical_json(snapshot).encode("utf-8"))
    return digest.hexdigest()


def policy_id(root: Path | None = None) -> str:
    root = root or repo_root()
    path = root / "corruptor_softmax_policy.py"
    text = path.read_text(encoding="utf-8")
    match = POLICY_RE.search(text)
    if not match:
        raise RuntimeError(f"Cannot find POLICY_ID in {path}")
    return match.group(1)


def check_policy_identity(root: Path | None = None) -> list[str]:
    root = root or repo_root()
    errors: list[str] = []
    try:
        expected = policy_id(root)
    except Exception as exc:
        return [str(exc)]

    policy_files = [
        root / "Scripts" / "Sim" / "GoldenTests.gd",
        root / "Scripts" / "Sim" / "BotRoundEngineTests.gd",
        root / "Scripts" / "Sim" / "SeededGameSetupTests.gd",
        root / "Scripts" / "Sim" / "LordMatrixTests.gd",
        root / "Scripts" / "Sim" / "LordMatrixSoakRunner.gd",
    ]
    for path in policy_files:
        if not path.is_file():
            errors.append(f"Missing policy-bearing file: {path.relative_to(root)}")
            continue
        values = set(SOFTMAX_RE.findall(path.read_text(encoding="utf-8")))
        if not values:
            errors.append(f"{path.relative_to(root)} has no pinned softmax policy id")
            continue
        bad = sorted(value for value in values if value != expected)
        if bad:
            errors.append(
                f"{path.relative_to(root)} has stale AI policy id(s): {bad}; "
                f"expected {expected}"
            )

    manifest_path = root / "golden" / "_manifest.json"
    if not manifest_path.is_file():
        errors.append("Missing golden/_manifest.json")
        return errors

    try:
        manifest = _read_json(manifest_path)
    except Exception as exc:
        errors.append(f"Cannot read golden/_manifest.json: {exc}")
        return errors

    if manifest.get("ai_version") != expected:
        errors.append(
            "golden/_manifest.json ai_version="
            f"{manifest.get('ai_version')!r}; expected {expected!r}"
        )

    matrix_path = root / "golden" / "lord_matrix.json"
    if matrix_path.is_file():
        try:
            matrix = _read_json(matrix_path)
            if matrix.get("ai_version") != expected:
                errors.append(
                    "golden/lord_matrix.json ai_version="
                    f"{matrix.get('ai_version')!r}; expected {expected!r}"
                )
        except Exception as exc:
            errors.append(f"Cannot read golden/lord_matrix.json: {exc}")

    for trace_name in sorted(manifest.get("traces", {})):
        path = root / "golden" / f"{trace_name}.json"
        if not path.is_file():
            continue
        try:
            trace = _read_json(path)
        except Exception as exc:
            errors.append(f"Cannot read {path.relative_to(root)}: {exc}")
            continue
        if trace.get("ai_version") != expected:
            errors.append(
                f"{path.relative_to(root)} ai_version="
                f"{trace.get('ai_version')!r}; expected {expected!r}"
            )

    return errors


def check_bastion_alias(root: Path | None = None) -> list[str]:
    root = root or repo_root()
    errors: list[str] = []

    rule_path = root / "Scripts" / "Sim" / "RuleConfig.gd"
    if not rule_path.is_file():
        errors.append("Missing Scripts/Sim/RuleConfig.gd")
    else:
        rule_text = rule_path.read_text(encoding="utf-8")
        if not re.search(r"@export\s+var\s+bastion_wall\s*:\s*bool", rule_text):
            errors.append("RuleConfig.gd does not export canonical bastion_wall")

    policy_path = root / "corruptor_softmax_policy.py"
    if policy_path.is_file():
        policy_text = policy_path.read_text(encoding="utf-8")
        if "bastion_fortified" in policy_text:
            errors.append(
                "corruptor_softmax_policy.py still references retired "
                "bastion_fortified; use bastion_wall"
            )

    sim_path = root / "corruptor_sim.py"
    if not sim_path.is_file():
        errors.append("Missing corruptor_sim.py")
        return errors

    text = sim_path.read_text(encoding="utf-8")
    if "def bastion_wall_enabled()" not in text:
        errors.append("corruptor_sim.py is missing bastion_wall_enabled()")
        return errors

    occurrences = [
        match.start()
        for match in re.finditer(re.escape(OLD_BASTION_READ), text)
    ]
    helper_start = text.find("def bastion_wall_enabled()")
    helper_end_match = re.search(r"(?m)^def\s+\w+\(", text[helper_start + 1 :])
    helper_end = (
        helper_start + 1 + helper_end_match.start()
        if helper_end_match
        else len(text)
    )
    outside = [
        pos
        for pos in occurrences
        if not (helper_start <= pos < helper_end)
    ]
    if len(occurrences) != 1 or outside:
        errors.append(
            "Retired bastion_fortified gameplay reads escaped the compatibility "
            f"helper: total old-key reads={len(occurrences)}, outside_helper={len(outside)}"
        )

    calls = text.count("bastion_wall_enabled()") - 1
    if calls < 1:
        errors.append("bastion_wall_enabled() has no live call sites")

    return errors


def check_golden_integrity(root: Path | None = None) -> list[str]:
    root = root or repo_root()
    errors: list[str] = []
    manifest_path = root / "golden" / "_manifest.json"

    if not manifest_path.is_file():
        return ["Missing golden/_manifest.json"]

    try:
        manifest = _read_json(manifest_path)
    except Exception as exc:
        return [f"Cannot read golden/_manifest.json: {exc}"]

    traces = manifest.get("traces")
    if not isinstance(traces, dict) or not traces:
        errors.append("golden/_manifest.json traces is missing/empty")
        return errors

    for name, manifest_hash in sorted(traces.items()):
        path = root / "golden" / f"{name}.json"
        if not path.is_file():
            errors.append(f"Manifest trace missing file: {path.relative_to(root)}")
            continue
        try:
            trace = _read_json(path)
        except Exception as exc:
            errors.append(f"Cannot read {path.relative_to(root)}: {exc}")
            continue

        if trace.get("name") != name:
            errors.append(
                f"{path.relative_to(root)} name={trace.get('name')!r}; expected {name!r}"
            )

        snapshots = trace.get("snapshots")
        if not isinstance(snapshots, list):
            errors.append(f"{path.relative_to(root)} snapshots is not a list")
            continue

        computed = trace_hash(snapshots)
        recorded = trace.get("trace_hash")
        if recorded != computed:
            errors.append(
                f"{path.relative_to(root)} trace_hash corrupt: "
                f"recorded={recorded} computed={computed}"
            )
        if manifest_hash != recorded:
            errors.append(
                f"{path.relative_to(root)} manifest hash mismatch: "
                f"manifest={manifest_hash} trace={recorded}"
            )

    matrix_path = root / "golden" / "lord_matrix.json"
    if not matrix_path.is_file():
        errors.append("Missing golden/lord_matrix.json")
    else:
        try:
            matrix = _read_json(matrix_path)
            scenarios = matrix.get("scenarios")
            if not isinstance(scenarios, list):
                errors.append("golden/lord_matrix.json scenarios is not a list")
            else:
                names = [str(row.get("name", "")) for row in scenarios if isinstance(row, dict)]
                if len(names) != len(scenarios):
                    errors.append("golden/lord_matrix.json has a non-object scenario")
                if any(not name for name in names):
                    errors.append("golden/lord_matrix.json has a scenario with no name")
                if len(set(names)) != len(names):
                    errors.append("golden/lord_matrix.json has duplicate scenario names")
                if int(matrix.get("scenario_count", -1)) != len(scenarios):
                    errors.append(
                        "golden/lord_matrix.json scenario_count does not match scenarios"
                    )
                if len(scenarios) != 81:
                    errors.append(
                        f"golden/lord_matrix.json expected 81 rows, found {len(scenarios)}"
                    )
        except Exception as exc:
            errors.append(f"Cannot validate golden/lord_matrix.json: {exc}")

    provenance_path = root / "golden" / "_provenance.json"
    if not provenance_path.is_file():
        errors.append(
            "Missing golden/_provenance.json; curated/selective golden ownership "
            "must be explicit"
        )
    else:
        try:
            provenance = _read_json(provenance_path)
            matrix_info = provenance.get("artifacts", {}).get("lord_matrix.json", {})
            if matrix_info.get("replacement_policy") != "selective-only":
                errors.append(
                    "golden/_provenance.json must mark lord_matrix.json "
                    "replacement_policy=selective-only"
                )
        except Exception as exc:
            errors.append(f"Cannot read golden/_provenance.json: {exc}")

    return errors


def check_temp_artifacts(root: Path | None = None) -> list[str]:
    root = root or repo_root()
    errors: list[str] = []
    exact = [
        root / "Scripts" / "Sim" / "SelectiveGoldenExporter.gd",
        root / "golden" / "lord_matrix_godot_candidate.json",
        root / "golden" / "game_deimos_valak_s1_godot_candidate.json",
    ]
    for path in exact:
        if path.exists():
            errors.append(f"Temporary rebaseline artifact still present: {path.relative_to(root)}")

    for path in root.glob("corruptor_oracle_verify_*"):
        errors.append(f"Temporary oracle directory still present: {path.name}")

    scan_roots = [
        root,
        root / "Scripts" / "Sim",
        root / "tests",
        root / "golden",
    ]
    seen: set[Path] = set()
    for base in scan_roots:
        if not base.exists():
            continue
        for pattern in ("*.bak_before_*", "*.verified_regen.tmp", "*_candidate.json"):
            for path in base.glob(pattern):
                if path in seen or ".corruptor_backups" in path.parts:
                    continue
                seen.add(path)
                errors.append(
                    f"Temporary/backup artifact outside .corruptor_backups: "
                    f"{path.relative_to(root)}"
                )

    return errors


def all_static_checks(root: Path | None = None) -> dict[str, list[str]]:
    root = root or repo_root()
    return {
        "policy identity": check_policy_identity(root),
        "Bastion alias": check_bastion_alias(root),
        "golden integrity": check_golden_integrity(root),
        "temporary artifacts": check_temp_artifacts(root),
    }


def git_paths(root: Path, staged: bool) -> list[Path]:
    cmd = ["git", "diff"]
    if staged:
        cmd.append("--cached")
    cmd.append("--name-only")
    result = subprocess.run(
        cmd,
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return []
    return [
        root / line.strip()
        for line in result.stdout.splitlines()
        if line.strip()
    ]


def godot_sensitive_paths(root: Path | None = None) -> list[Path]:
    root = root or repo_root()
    candidates = git_paths(root, staged=False) + git_paths(root, staged=True)
    unique: dict[str, Path] = {}
    for path in candidates:
        try:
            rel = path.relative_to(root).as_posix()
        except ValueError:
            continue
        sensitive = (
            rel.startswith("Scripts/Sim/")
            or rel.startswith("golden/")
            or rel in {
                "corruptor_sim.py",
                "corruptor_softmax_policy.py",
                "golden_master.py",
                "lord_matrix_master.py",
            }
        )
        if sensitive:
            unique[rel] = path
    return [unique[key] for key in sorted(unique)]
