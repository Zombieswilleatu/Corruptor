#!/usr/bin/env python3
"""Pinned Godot replay and ABBA timing of the last focused Marching pass."""

import argparse
import hashlib
import io
import json
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tarfile
import tempfile

from u13_pysim import codec, full_match_inputs, marching_fixtures
from u13_pysim import verify_marching
from u13_pysim.benchmark_full_match_copying import (
    WORKER, INPUTS_SHA256, check_native_sources, replay, validate_parity)
from u13_pysim.verify import same, source_identity

ROOT = Path(__file__).resolve().parents[2]
CONTROL = "c228d85d449b19cfb3cd929479b0255c7e49bfc1"
CONTROL_SOURCE = "e34ef7c6e3aeb39040ad413159feb6b2cef5e15e19adbe6accf777339613854f"
PHASE_REVISION = "e8cc3f9c236afa2ce4586999913a52e833b5813f"
PHASE_SOURCE = "6ce44971808ae9d45815da43e478978022f279259e083d38cc421e99c8898fc4"
PHASE_TRACE = "65438fd88d6b0f75856c93d83fbe06353234182e372f3b83bd3eaa9a38d5e9b6"
PHASE_INPUTS = "5baaab5d5a70fbc0c89c633bf7bc043e328f0784f604f821f1a9dd96b539e4de"
EVIDENCE = ROOT / "docs/evidence/U13_PYSIM_FULL_MATCH_COPYING_c228d85.json"


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def fingerprint(sources):
    digest = hashlib.sha256()
    for name, data in sorted(sources.items()):
        if (name.endswith(".gd") or name == "Scripts/Sim/run_u13_pysim.py" or
                Path(name).parent.as_posix() == "Scripts/Sim/u13_pysim" and name.endswith(".py")):
            encoded = name.encode()
            digest.update(str(len(encoded)).encode() + b":" + encoded +
                          hashlib.sha256(data.replace(b"\r\n", b"\n")).digest())
    return digest.hexdigest()


def control_sources(root):
    raw = subprocess.check_output(["git", "-C", str(root), "archive", "--format=tar",
                                   CONTROL, "Scripts/Sim"], timeout=120)
    sources = {}
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
        for entry in archive:
            if entry.isdir():
                continue
            path = Path(entry.name)
            if (not entry.isfile() or path.is_absolute() or ".." in path.parts or
                    path.parts[:2] != ("Scripts", "Sim")):
                raise ValueError("Unexpected control archive entry")
            sources[path.as_posix()] = archive.extractfile(entry).read()
    same(CONTROL_SOURCE, fingerprint(sources), "control.source_sha256")
    return sources


def check_workload(root, sources):
    for name in ("benchmark_full_match.py", "full_match_inputs.json"):
        key = "Scripts/Sim/u13_pysim/" + name
        same(sources[key].replace(b"\r\n", b"\n"),
             (root / key).read_bytes().replace(b"\r\n", b"\n"), "shared_workload." + name)
    same(INPUTS_SHA256, full_match_inputs.input_hash(), "inputs_sha256")
    same(PHASE_INPUTS, marching_fixtures.input_hash(), "marching.inputs_sha256")


def check_phase_bytes(raw):
    same(PHASE_TRACE, hashlib.sha256(raw).hexdigest(), "marching.reference_trace_sha256")


def validate_control(evidence):
    same("U13_PYSIM_FULL_MATCH_COPYING_ACCEPTANCE_V1", evidence.get("schema"), "control.acceptance.schema")
    same(True, evidence.get("accepted"), "control.accepted")
    same(CONTROL, evidence.get("source_revision"), "control.revision")
    same(CONTROL_SOURCE, evidence.get("source_sha256"), "control.source")
    for rt in ("cpython", "pypy"):
        record = evidence["runtimes"][rt]
        validate_parity(dict(record["parity_provenance"],
                             reference_verification=evidence["accepted_reference_verification"]),
                        CONTROL, CONTROL_SOURCE)
        same(True, record["reference_verification_matches_accepted_summary"], "control.replay")
        same(63, record["unit_tests"]["passed"], "control.tests")
        same(0, record["unit_tests"]["failed"], "control.test_failures")
        same(hashlib.sha256(WORKER.encode()).hexdigest(), record["timing"]["worker_sha256"], "control.worker")


def run(full_trace, phase_trace, output, games=20):
    if type(games) is not int or games < 4 or games > 40 or games % 4:
        raise ValueError("games per block must be a multiple of four between 4 and 40")
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError("report directory must be empty")
    revision, source_hash = source_identity(ROOT)
    sources = control_sources(ROOT)
    native = check_native_sources(ROOT, sources)
    check_workload(ROOT, sources)
    accepted = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    validate_control(accepted)
    accepted_runtime = accepted["runtimes"].get(platform.python_implementation().lower(), {}).get("parity_provenance", {})
    runtime_matches = sys.version == accepted_runtime.get("python") and platform.platform() == accepted_runtime.get("platform")
    phase_raw = Path(phase_trace).read_bytes()
    check_phase_bytes(phase_raw)
    identity = dict(source_revision=revision, source_sha256=source_hash,
        control_revision=CONTROL, control_source_sha256=CONTROL_SOURCE,
        inputs_sha256=INPUTS_SHA256, marching_inputs_sha256=PHASE_INPUTS,
        observer_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
        accepted_evidence_sha256=hashlib.sha256(EVIDENCE.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
        worker_sha256=hashlib.sha256(WORKER.encode()).hexdigest(), native_sources=native,
        python=sys.version, python_implementation=platform.python_implementation(), platform=platform.platform(),
        runtime_matches_accepted_windows_runtime=runtime_matches,
        diagnostic_only=not runtime_matches, new_godot_run=False)
    write(output / "identity.json", identity)

    print("Replay both complete games against the pinned Windows Godot stream", flush=True)
    full = replay(ROOT, full_trace)
    validate_parity(full, revision, source_hash)
    same(accepted["accepted_reference_verification"], full["reference_verification"], "full.accepted_reference")
    write(output / "full-match-parity.json", full)
    print("Full-match replay passed, including 13 corruption rejections", flush=True)
    suite = codec.loads(phase_raw.decode("utf-8"))
    phase = verify_marching.verify(suite, PHASE_REVISION, PHASE_SOURCE)
    phase["deliberate_mismatches_rejected"] = verify_marching.verify_rejections(suite, PHASE_REVISION, PHASE_SOURCE)
    for key, value in dict(marching_phases_matched=28, tick_frames_matched=5600,
                           contact_probes_matched=33, deliberate_mismatches_rejected=14, failures=0).items():
        same(value, phase[key], "marching." + key)
    write(output / "marching-parity.json", dict(candidate_identity=identity,
        reference_trace_sha256=PHASE_TRACE, reference_verification=phase))
    print("Marching replay passed: 5,600 ticks and 14 corruption rejections", flush=True)

    blocks = []
    with tempfile.TemporaryDirectory(prefix="u13-marching-control-") as temp:
        temp = Path(temp)
        for name, raw in sources.items():
            path = temp / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        # Match each ordering: AB followed by BA, with fresh processes and the
        # full alternating sequence in each. Initial games stay in the result.
        for index, label in enumerate(("control", "candidate", "candidate", "control")):
            report = output / (str(index) + "-" + label + "-samples.json")
            config = dict(implementation=label, games=games,
                sim_path=str((temp if label == "control" else ROOT) / "Scripts/Sim"),
                source_revision=CONTROL if label == "control" else revision,
                source_sha256=CONTROL_SOURCE if label == "control" else source_hash,
                inputs_sha256=INPUTS_SHA256, expected_games=full["reference_verification"]["games"],
                report_path=str(report))
            path = temp / "worker.json"
            write(path, config)
            print(f"Unprofiled block {index+1}/4: {label}; {games} consecutive games", flush=True)
            subprocess.run([sys.executable, "-c", WORKER, str(path)], check=True, timeout=900)
            block = json.loads(report.read_text(encoding="utf-8"))
            same(games, block["measured_games"], "worker.games")
            same(True, block["all_final_digests_matched"], "worker.digests")
            same(0, block["failures"], "worker.failures")
            blocks.append(block)
    same((revision, source_hash), source_identity(ROOT), "source_after_run")
    check_workload(ROOT, sources)
    for block in blocks[1:]:
        for key in ("python", "python_implementation", "platform", "executable", "gc_enabled", "inputs_sha256",
                    "interpreter_flags", "interpreter_xoptions", "pypy_environment"):
            same(blocks[0][key], block[key], "matched_runtime." + key)
    means = {}
    for label in ("control", "candidate"):
        selected = [b for b in blocks if b["implementation"] == label]
        means[label] = dict(mean_wall_ms=statistics.mean(r["wall_ms"] for b in selected for r in b["samples"]),
            last_half_mean_wall_ms=statistics.mean(r["wall_ms"] for b in selected for r in b["samples"][games//2:]))
    pairs = [dict(order=[blocks[a]["implementation"], blocks[b]["implementation"]],
        control_mean_wall_ms=blocks[c]["mean_wall_ms"], candidate_mean_wall_ms=blocks[d]["mean_wall_ms"],
        speedup=blocks[c]["mean_wall_ms"]/blocks[d]["mean_wall_ms"])
        for a,b,c,d in ((0,1,0,1), (2,3,3,2))]
    ratio = means["control"]["mean_wall_ms"] / means["candidate"]["mean_wall_ms"]
    result = dict(identity, schema="U13_MARCHING_OPTIMIZATION_COMPARISON_V1",
        full_match_parity=full, marching_parity=phase, marching_reference_trace_sha256=PHASE_TRACE,
        block_order=[b["implementation"] for b in blocks], games_per_block=games,
        measured_games=4*games, blocks=blocks, summary=means, paired_comparisons=pairs,
        mean_wall_speedup=ratio, all_final_digests_matched=True, profiling_enabled=False,
        included="independent setup; explicit decisions; all hooks; transactions; complete semantic history; victory",
        excluded="policy selection; input loading; process startup/imports; result snapshots/digests; export; profiling",
        scope="Two accepted ordinary games repeated; four supported Lords, no declared powers, paid Rites or Resummon.",
        limitations="ABBA reduces order bias but does not measure temperature, CPU frequency, GC cost, memory, worker scaling or campaign throughput.",
        failures=0)
    write(output / "comparison.json", result)
    print(f'Mean: {means["control"]["mean_wall_ms"]:.2f} -> {means["candidate"]["mean_wall_ms"]:.2f} ms; {ratio:.3f}x', flush=True)
    print("U13 Marching optimization comparison failures: 0", flush=True)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full-trace", type=Path, required=True)
    parser.add_argument("--marching-trace", type=Path, required=True)
    parser.add_argument("--report-dir", type=Path, required=True)
    parser.add_argument("--games", type=int, default=20)
    args = parser.parse_args()
    try:
        run(args.full_trace, args.marching_trace, args.report_dir, args.games)
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"FAIL U13 Marching optimization: {error}", file=sys.stderr)
        raise SystemExit(1)
