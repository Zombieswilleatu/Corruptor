#!/usr/bin/env python3
"""Profile the accepted optimized engine without changing its source fingerprint.

Unprofiled timings and cProfile run in separate processes. Exact final-state
checks remain outside both timers. This observer is not a new parity gate.
"""

import argparse
import cProfile
import hashlib
import json
from pathlib import Path
import pstats
import subprocess
import sys
import tempfile
import time

from u13_pysim import full_match_inputs
from u13_pysim.benchmark_full_match import digest, play
from u13_pysim.benchmark_full_match_copying import WORKER, validate_parity
from u13_pysim.verify import same, source_identity

ROOT = Path(__file__).resolve().parents[2]
ACCEPTED_REVISION = "c228d85d449b19cfb3cd929479b0255c7e49bfc1"
ACCEPTED_SOURCE = "e34ef7c6e3aeb39040ad413159feb6b2cef5e15e19adbe6accf777339613854f"
ACCEPTED_INPUTS = "c811aa29dd34c2e8c6cf7cc710693483340c067415aaae0b94c55cc8f8fb3865"
EVIDENCE = ROOT / "docs/evidence/U13_PYSIM_FULL_MATCH_COPYING_c228d85.json"


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def validate_accepted(evidence, source_hash, input_hash):
    same(ACCEPTED_SOURCE, source_hash, "profile.current_source; fresh acceptance required if changed")
    same(ACCEPTED_INPUTS, input_hash, "profile.current_inputs")
    same("U13_PYSIM_FULL_MATCH_COPYING_ACCEPTANCE_V1", evidence.get("schema"), "accepted.schema")
    same(True, evidence.get("accepted"), "accepted.status")
    same(ACCEPTED_REVISION, evidence.get("source_revision"), "accepted.revision")
    same(ACCEPTED_SOURCE, evidence.get("source_sha256"), "accepted.source")
    for runtime in ("cpython", "pypy"):
        result = evidence["runtimes"][runtime]
        parity = dict(result["parity_provenance"],
                      reference_verification=evidence["accepted_reference_verification"])
        validate_parity(parity, ACCEPTED_REVISION, ACCEPTED_SOURCE)
        same(True, result["reference_verification_matches_accepted_summary"], "accepted.replay")
        same(63, result["unit_tests"]["passed"], "accepted.tests")
        same(0, result["unit_tests"]["failed"], "accepted.test_failures")
    return evidence["accepted_reference_verification"]["games"]


def check_game(game, expected, label):
    same(expected["final_state_sha256"], digest(game), label + ".final_state")
    same(expected["outcome"], game.outcome(), label + ".outcome")


def function_identity(key):
    file, line, function = key
    file = file.replace("\\", "/")
    prefix = ROOT.as_posix() + "/"
    if file.startswith(prefix): file = file[len(prefix):]
    return dict(file=file, line=line, function=function)


def read_stats(stats):
    functions, modules = [], {}
    for key, (primitive, calls, exclusive, cumulative, callers) in stats.stats.items():
        identity = function_identity(key)
        # cProfile reverses the two count fields in caller records: nc, cc,
        # tt, ct, while the function record above starts cc, nc, tt, ct.
        functions.append(dict(identity, primitive_calls=primitive, total_calls=calls,
            exclusive_seconds=exclusive, cumulative_seconds=cumulative,
            callers=[dict(function_identity(caller), total_calls=metrics[0],
                          primitive_calls=metrics[1], exclusive_seconds=metrics[2],
                          cumulative_seconds=metrics[3])
                     for caller, metrics in sorted(callers.items())]))
        modules[identity["file"]] = modules.get(identity["file"], 0) + exclusive
    functions.sort(key=lambda row: row["cumulative_seconds"], reverse=True)
    return functions, modules


def profile_worker(config):
    same(ACCEPTED_SOURCE, source_identity(ROOT)[1], "worker.source")
    same(ACCEPTED_INPUTS, full_match_inputs.input_hash(), "worker.inputs")
    specs = full_match_inputs.load()["cases"]
    expected = config["expected_games"]
    same([s["name"] for s in specs], [g["name"] for g in expected], "worker.cases")
    warmups, stage_samples = [], []
    # The final pair also supplies hook timings with cProfile disabled. These
    # timer-instrumented games are not included in the throughput samples.
    for index in range(config["warmups"]):
        slot = index % len(specs)
        stages = {} if index >= config["warmups"] - len(specs) else None
        start = time.perf_counter_ns()
        game = play(specs[slot], stages)
        wall_ms = (time.perf_counter_ns() - start) / 1e6
        check_game(game, expected[slot], "warmup[" + str(index) + "]")
        row = dict(index=index, name=specs[slot]["name"], wall_ms=wall_ms,
                   stage_timers_enabled=stages is not None,
                   final_state_sha256=expected[slot]["final_state_sha256"])
        warmups.append(row)
        if stages is not None:
            stage_samples.append(dict(row, stage_wall_ms=stages,
                                      stage_sum_ms=sum(stages.values())))
        print(f'Profile warmup {index+1}/{config["warmups"]}: {row["name"]} {wall_ms/1000:.3f} s', flush=True)
    profiles = []
    for spec, verified in zip(specs, expected):
        stages, profiler = {}, cProfile.Profile()
        start = time.perf_counter_ns()
        game = profiler.runcall(play, spec, stages)
        wall_ms = (time.perf_counter_ns() - start) / 1e6
        check_game(game, verified, "profile." + spec["name"])
        stats = pstats.Stats(profiler)
        functions, modules = read_stats(stats)
        output = Path(config["report_dir"]) / spec["name"]
        profiler.dump_stats(str(output) + ".prof")
        with Path(str(output) + "-profile.txt").open("w", encoding="utf-8") as stream:
            text_stats = pstats.Stats(profiler, stream=stream)
            text_stats.sort_stats("cumulative").print_stats()
            text_stats.sort_stats("tottime").print_stats()
            text_stats.print_callers()
        row = dict(name=spec["name"], rounds=verified["rounds"],
            operations=len(spec["operations"]), outcome=verified["outcome"],
            final_state_sha256=verified["final_state_sha256"], wall_ms=wall_ms,
            profiled_stage_wall_ms=stages, total_profile_seconds=stats.total_tt,
            primitive_calls=stats.prim_calls, total_calls=stats.total_calls,
            functions=functions, exclusive_seconds_by_file=modules)
        write_json(str(output) + "-profile.json", row)
        profiles.append(row)
        print(f'Profile complete: {spec["name"]}, {len(functions)} functions, {wall_ms/1000:.3f} instrumented seconds', flush=True)
    write_json(Path(config["report_dir"]) / "profiles.json", dict(
        schema="U13_OPTIMIZED_FULL_MATCH_PROFILE_DETAILS_V1", warmups=warmups,
        stage_samples_without_cprofile=stage_samples, profiles=profiles,
        all_final_digests_matched=True, failures=0))


def run(report_dir, games=20, warmups=10):
    if type(games) is not int or games < 4 or games > 40 or games % 4:
        raise ValueError("games must be a multiple of four between 4 and 40")
    if type(warmups) is not int or warmups < 2 or warmups > 20 or warmups % 2:
        raise ValueError("warmups must be even and between 2 and 20")
    revision, source_hash = source_identity(ROOT)
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    expected = validate_accepted(evidence, source_hash, full_match_inputs.input_hash())
    report_dir = Path(report_dir).resolve()
    report_dir.mkdir(parents=True, exist_ok=True)
    if any(report_dir.iterdir()): raise ValueError("report directory must be empty")
    provenance = dict(source_revision=revision, source_sha256=source_hash,
        accepted_engine_revision=ACCEPTED_REVISION, inputs_sha256=full_match_inputs.input_hash(),
        observer_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
        accepted_evidence_sha256=hashlib.sha256(EVIDENCE.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
        reference_revision=evidence["accepted_reference_verification"]["source_revision"],
        prior_dual_runtime_parity_reused_by_identical_engine_source=True, new_parity_run=False)
    write_json(report_dir / "profile-identity.json", provenance)
    config = dict(implementation="accepted_optimized", games=games, warmups=warmups,
        sim_path=str(ROOT / "Scripts/Sim"), source_revision=revision,
        source_sha256=source_hash, inputs_sha256=full_match_inputs.input_hash(),
        expected_games=expected, report_path=str(report_dir / "unprofiled-samples.json"),
        report_dir=str(report_dir))
    with tempfile.TemporaryDirectory(prefix="u13-profile-") as temp:
        config_path = Path(temp) / "config.json"
        write_json(config_path, config)
        print("Unprofiled timing block: accepted optimized engine", flush=True)
        subprocess.run([sys.executable, "-c", WORKER, str(config_path)], check=True, timeout=900)
        print("Separate profiling process: warmups, hook timers, then cProfile", flush=True)
        subprocess.run([sys.executable, str(Path(__file__).resolve()), "--worker", str(config_path)],
                       check=True, timeout=900)
    same(source_hash, source_identity(ROOT)[1], "profile.source_after_run")
    same(ACCEPTED_INPUTS, full_match_inputs.input_hash(), "profile.inputs_after_run")
    timing = json.loads((report_dir / "unprofiled-samples.json").read_text(encoding="utf-8"))
    details = json.loads((report_dir / "profiles.json").read_text(encoding="utf-8"))
    for result in (timing, details):
        same(True, result["all_final_digests_matched"], "profile.results")
        same(0, result["failures"], "profile.failures")
    same(games, timing["measured_games"], "profile.measured_games")
    same(warmups, len(details["warmups"]), "profile.warmups")
    same(2, len(details["profiles"]), "profile.profiles")
    runtime = evidence["runtimes"].get(timing["python_implementation"].lower(), {})
    accepted_runtime = runtime.get("parity_provenance", {})
    runtime_matches = (timing["python"] == accepted_runtime.get("python") and
                       timing["platform"] == accepted_runtime.get("platform"))
    comparisons = []
    for profile, stages in zip(details["profiles"], details["stage_samples_without_cprofile"]):
        same(profile["name"], stages["name"], "profile.stage_case")
        case = next(row for row in timing["cases"] if row["name"] == profile["name"])
        comparisons.append(dict(name=profile["name"],
            unprofiled_mean_wall_ms=case["wall"]["mean_ms"],
            separate_stage_game_wall_ms=stages["wall_ms"],
            profiled_wall_ms=profile["wall_ms"],
            observed_profile_to_timing_ratio=profile["wall_ms"] / case["wall"]["mean_ms"]))
    result = dict(provenance, schema="U13_OPTIMIZED_FULL_MATCH_PROFILE_V1",
        runtime_matches_accepted_windows_runtime=runtime_matches,
        diagnostic_only=not runtime_matches, timing=timing, profile_details=details,
        instrumentation_comparison=comparisons,
        included=runtime.get("timing", {}).get("included", "setup; explicit operations; all hooks; transactions; complete semantic history; victory"),
        excluded="policy selection; input loading; result snapshots/digests; process startup/imports; report export",
        scope="same two accepted ordinary games; no mechanics changes or wider corpus",
        interpretation="cProfile changes runtime cost, especially with PyPy; use separate unprofiled timings for speed and stage timers as supporting evidence, not cumulative-time sums",
        decision_thresholds="2x whole-match speed needs 50% net time removed; 3x needs 66.7%. A profile alone does not establish achievable savings.",
        memory_measurement=None, failures=0)
    write_json(report_dir / "profile-summary.json", result)
    print(f'Unprofiled mean: {timing["mean_wall_ms"]/1000:.3f} s; final half: {timing["last_half_mean_wall_ms"]/1000:.3f} s', flush=True)
    print("U13 optimized full-match profile failures: 0", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-dir", type=Path)
    parser.add_argument("--games", type=int, default=20)
    parser.add_argument("--warmups", type=int, default=10)
    parser.add_argument("--worker", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        if args.worker:
            profile_worker(json.loads(args.worker.read_text(encoding="utf-8")))
        elif args.report_dir is None:
            parser.error("--report-dir is required")
        else:
            run(args.report_dir, args.games, args.warmups)
    except Exception as error:
        print(f"FAIL U13 optimized full-match profile: {error}", file=sys.stderr)
        raise SystemExit(1)
