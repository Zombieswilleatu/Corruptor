"""Compare accepted and current Python implementations on one machine.

The baseline is loaded from a pinned git commit into a temporary directory.
Both implementations use the exact same existing timing/fixture source and
the same Python executable, in sequential baseline/current/current/baseline
blocks. Export and exact-result hashing happen outside the measured interval.
"""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

from .verify import source_identity

BASELINE = "1fc29d78b1650084f3d462883ffdfbd144c76de4"
BASELINE_SOURCE = "73072edd9ea35c3d50edef2cdcc85adaafbf48490f9801a959bf973679c8d089"
VERSION = "U13_PYSIM_COPYING_BENCHMARK_V1"

# Import the selected package in a fresh interpreter, avoiding module-cache
# collisions between baseline and candidate implementations.
WORKER = r'''
import cProfile, hashlib, json, pstats, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from u13_pysim import codec
from u13_pysim.benchmark_development import run
from u13_pysim.development import DevelopmentMatch
from u13_pysim.development_fixtures import setup, scripted_operations
profiler = cProfile.Profile() if sys.argv[5] == "profile" else None
if profiler: profiler.enable()
report = run(sys.argv[2], sys.argv[3], int(sys.argv[4]))
if profiler: profiler.disable()
inputs, states = hashlib.sha256(), hashlib.sha256()
def add(digest, value):
    payload = codec.dumps(value).encode("utf-8")
    digest.update(str(len(payload)).encode("ascii") + b":" + payload)
for index in range(9):
    config, operations = setup(index), scripted_operations(index)
    add(inputs, dict(setup=config, operations=operations))
    game = DevelopmentMatch(config)
    add(states, game.snapshot())
    for op in operations:
        result = game.apply(op)
        add(states, dict(operation=op, result=result, state=game.snapshot(), outcome=game.outcome()))
report["input_sha256"] = inputs.hexdigest()
report["exact_result_sha256"] = states.hexdigest()
if profiler:
    stats = pstats.Stats(profiler)
    report["profile_scope"] = "instrumented run including input preparation and warmups; not throughput"
    report["profile_top"] = [dict(file=Path(key[0]).name, line=key[1], function=key[2],
                                 primitive_calls=value[0], total_calls=value[1],
                                 exclusive_seconds=value[2], cumulative_seconds=value[3])
                             for key, value in sorted(stats.stats.items(), key=lambda item: item[1][3], reverse=True)[:15]]
print(json.dumps(report))
'''


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def run(root, iterations=15, include_profiles=True):
    if not 1 <= iterations <= 100:
        raise ValueError("iterations must be between 1 and 100 per setup per block")
    root = Path(root).resolve()
    revision, source_hash = source_identity(root)
    # Only this known accepted baseline is supported. No branch-name lookup or
    # network fetch changes the selected historical implementation.
    if git(root, "rev-parse", BASELINE).decode().strip() != BASELINE:
        raise ValueError("accepted copying baseline is unavailable")
    prefix = "Scripts/Sim/u13_pysim/"
    names = git(root, "ls-tree", "-r", "--name-only", BASELINE, "--", prefix).decode().splitlines()
    blobs = {name: git(root, "show", BASELINE + ":" + name) for name in names if name.endswith(".py")}
    shared_sources = {}
    for name in ("benchmark_development.py", "development_fixtures.py"):
        relative = prefix + name
        current = (root / relative).read_bytes().replace(b"\r\n", b"\n")
        baseline = blobs[relative].replace(b"\r\n", b"\n")
        if current != baseline:
            raise ValueError("comparison timing/fixture source changed: " + relative)
        shared_sources[relative] = hashlib.sha256(current).hexdigest()
    blocks, profiles = [], []
    with tempfile.TemporaryDirectory(prefix="u13-pysim-copying-") as temporary:
        sim = Path(temporary) / "Scripts/Sim"
        package = sim / "u13_pysim"
        package.mkdir(parents=True)
        for name, content in blobs.items():
            if Path(name).parent.as_posix() != prefix.rstrip("/"):
                raise ValueError("unexpected baseline package path")
            (package / Path(name).name).write_bytes(content)

        def execute(label, profiled=False):
            selected = sim if label == "baseline" else root / "Scripts/Sim"
            selected_revision = BASELINE if label == "baseline" else revision
            selected_source = BASELINE_SOURCE if label == "baseline" else source_hash
            command = [sys.executable, "-c", WORKER, str(selected), selected_revision,
                       selected_source, "1" if profiled else str(iterations),
                       "profile" if profiled else "timing"]
            completed = subprocess.run(command, capture_output=True, text=True, timeout=120, check=True)
            report = json.loads(completed.stdout)
            return dict(implementation=label, report=report)

        for label in ("baseline", "current", "current", "baseline"):
            print("Copying comparison: " + label, flush=True)
            blocks.append(execute(label))
        if include_profiles:
            for label in ("baseline", "current"):
                print("Copying profile (separate): " + label, flush=True)
                profiles.append(execute(label, True))
    all_reports = [block["report"] for block in blocks + profiles]
    for key in ("input_sha256", "exact_result_sha256", "python", "python_implementation", "platform", "machine"):
        if len({report[key] for report in all_reports}) != 1:
            raise ValueError("comparison differs in " + key)
    summaries = {}
    for label in ("baseline", "current"):
        reports = [block["report"] for block in blocks if block["implementation"] == label]
        count = sum(report["measured_cycles"] for report in reports)
        wall = sum(report["measured_wall_seconds"] for report in reports)
        cpu = sum(report["measured_cpu_seconds"] for report in reports)
        summaries[label] = dict(measured_cycles=count, warmup_cycles=sum(r["warmup_cycles"] for r in reports),
                                mean_wall_ms=wall * 1000 / count, measured_wall_seconds=wall,
                                mean_cpu_ms=cpu * 1000 / count, measured_cpu_seconds=cpu,
                                phase_mean_wall_ms={phase: sum(r["phase_wall"][phase]["mean_ms"] * r["measured_cycles"]
                                                               for r in reports) / count
                                                    for phase in reports[0]["phase_wall"]})
    before, after = summaries["baseline"]["mean_wall_ms"], summaries["current"]["mean_wall_ms"]
    return dict(schema=VERSION, source_revision=revision, source_sha256=source_hash,
                baseline_revision=BASELINE, baseline_source_sha256=BASELINE_SOURCE,
                scope="opening through first Development; not full-round or full-match throughput",
                block_order=[block["implementation"] for block in blocks], workers=1,
                same_python_executable=True, shared_source_sha256=shared_sources,
                input_sha256=all_reports[0]["input_sha256"], exact_result_sha256=all_reports[0]["exact_result_sha256"],
                exact_results_match=True, summary=summaries, mean_wall_speedup=before / after,
                mean_wall_reduction_percent=100 * (1 - after / before), blocks=blocks,
                separate_profiles=profiles, full_match_games_per_second=None, full_match_50000_wall_seconds=None)
