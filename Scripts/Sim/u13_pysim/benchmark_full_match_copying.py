"""Pinned native replay and sustained, same-runtime copying comparison.

The oracle identity is kept separate from the executing candidate identity.
Reusing the accepted stream requires unchanged native sources and inputs.
Baseline/candidate timings run the identical worker in separate processes;
each process runs the complete alternating sequence without a JIT reset.
"""

import hashlib
import io
import json
import math
from pathlib import Path
import platform
import subprocess
import sys
import tarfile
import tempfile

from . import full_match_inputs as inputs
from .verify import same, source_identity
from .verify_full_match import verify, verify_rejections

BASELINE = "d059b9560a95c32779597260d99829f9f1534f22"
BASELINE_SOURCE = "b25bdf65d1f1689f7e0b5e35cee748e810bd1bf409f2084ee55b0b280ad7358e"
INPUTS_SHA256 = "c811aa29dd34c2e8c6cf7cc710693483340c067415aaae0b94c55cc8f8fb3865"
TRACE_SHA256 = "81318a197145163bbd0d282c16a2b1ccc19d92c8ad7f68b1c6c8ac3f2f697b72"
PARITY_SCHEMA = "U13_FULL_MATCH_COPYING_PARITY_V1"
SCHEMA = "U13_FULL_MATCH_COPYING_TIMING_V1"


def text_bytes(data):
    return data.replace(b"\r\n", b"\n")


def baseline_sources(root):
    raw = subprocess.check_output(["git", "-C", str(root), "archive", "--format=tar",
                                   BASELINE, "Scripts/Sim"], timeout=120)
    sources = {}
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
        for entry in archive:
            if not entry.isfile():
                if not entry.isdir(): raise ValueError("non-file in baseline archive")
                continue
            path = Path(entry.name)
            if path.is_absolute() or ".." in path.parts or path.parts[:2] != ("Scripts", "Sim"):
                raise ValueError("unexpected baseline archive path")
            sources[path.as_posix()] = archive.extractfile(entry).read()
    digest = hashlib.sha256()
    for name, data in sorted(sources.items()):
        if (name.endswith(".gd") or name == "Scripts/Sim/run_u13_pysim.py" or
                Path(name).parent.as_posix() == "Scripts/Sim/u13_pysim" and name.endswith(".py")):
            encoded = name.encode("utf-8")
            digest.update(str(len(encoded)).encode() + b":" + encoded + hashlib.sha256(text_bytes(data)).digest())
    same(BASELINE_SOURCE, digest.hexdigest(), "baseline.source_sha256")
    return sources


def check_native_sources(root, sources):
    root = Path(root)
    expected = {name: text_bytes(data) for name, data in sources.items() if name.endswith(".gd")}
    actual = {p.relative_to(root).as_posix(): text_bytes(p.read_bytes())
              for p in (root / "Scripts/Sim").rglob("*.gd")}
    same(sorted(expected), sorted(actual), "reference.native_source_paths")
    digest = hashlib.sha256()
    for name, data in sorted(expected.items()):
        if data != actual[name]:
            raise ValueError("reference native source changed: " + name + "; a new Godot export is required")
        digest.update(name.encode() + b"\0" + hashlib.sha256(data).digest())
    return dict(files=len(expected), sha256=digest.hexdigest())


def check_trace(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    same(TRACE_SHA256, digest.hexdigest(), "reference.trace_sha256")


def replay(root, trace):
    root = Path(root).resolve()
    revision, source_hash = source_identity(root)
    native = check_native_sources(root, baseline_sources(root))
    same(INPUTS_SHA256, inputs.input_hash(), "reference.inputs_sha256")
    check_trace(trace)
    # These parameters authenticate the historical oracle, not the candidate.
    # The candidate executes the comparison; its actual identity is below.
    result = verify(trace, BASELINE, BASELINE_SOURCE)
    result["deliberate_mismatches_rejected"] = verify_rejections(trace, BASELINE, BASELINE_SOURCE)
    return dict(schema=PARITY_SCHEMA, source_revision=revision, source_sha256=source_hash,
                inputs_sha256=inputs.input_hash(), python=sys.version,
                python_implementation=platform.python_implementation(), platform=platform.platform(),
                reference_revision=BASELINE, reference_source_sha256=BASELINE_SOURCE,
                reference_trace_sha256=TRACE_SHA256, native_sources=native,
                native_sources_unchanged=True, new_godot_run=False,
                reference_verification=result, failures=0)


def validate_parity(parity, revision, source_hash):
    for key, value in dict(schema=PARITY_SCHEMA, source_revision=revision, source_sha256=source_hash,
                           inputs_sha256=INPUTS_SHA256, reference_revision=BASELINE,
                           reference_source_sha256=BASELINE_SOURCE, reference_trace_sha256=TRACE_SHA256,
                           native_sources_unchanged=True, new_godot_run=False, failures=0).items():
        same(value, parity.get(key), "parity_prerequisite." + key)
    result = parity["reference_verification"]
    for key, value in dict(source_revision=BASELINE, source_sha256=BASELINE_SOURCE,
                           inputs_sha256=INPUTS_SHA256, complete_games_matched=2,
                           complete_rounds_matched=30, game_operations_matched=767,
                           fixture_operations=0, terminal_rejections_matched=4,
                           directed_settlement_components_matched=8,
                           full_world_tick_probes_matched=1, tick_frames_compared=200,
                           all_semantic_rows_and_views_matched=True,
                           deliberate_mismatches_rejected=13, failures=0).items():
        same(value, result.get(key), "parity_prerequisite.reference." + key)


WORKER = r'''
import gc, hashlib, json, os, platform, statistics, sys, time
from pathlib import Path
config = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
sys.path.insert(0, config["sim_path"])
from u13_pysim import codec, full_match_inputs
from u13_pysim.benchmark_full_match import play, digest
from u13_pysim.benchmark_development import distribution
from u13_pysim.verify import same
specs = full_match_inputs.load()["cases"]
expected = config["expected_games"]
same(config["inputs_sha256"], full_match_inputs.input_hash(), "worker.inputs_sha256")
same([s["name"] for s in specs], [r["name"] for r in expected], "worker.cases")
same(True, gc.isenabled(), "worker.gc_enabled")
rows = []
for index in range(config["games"]):
    slot = index % len(specs)
    spec, verified = specs[slot], expected[slot]
    cpu, wall = time.process_time_ns(), time.perf_counter_ns()
    game = play(spec)
    wall_ms = (time.perf_counter_ns() - wall) / 1e6
    cpu_ms = (time.process_time_ns() - cpu) / 1e6
    result_hash = digest(game)
    same(verified["final_state_sha256"], result_hash, "worker.final_state["+str(index)+"]")
    same(verified["outcome"], game.outcome(), "worker.outcome["+str(index)+"]")
    rows.append(dict(index=index, name=spec["name"], rounds=verified["rounds"],
                     wall_ms=wall_ms, cpu_ms=cpu_ms, final_state_sha256=result_hash))
    print(f'{config["implementation"]} {index+1}/{config["games"]} {spec["name"]}: {wall_ms/1000:.3f} s', flush=True)
groups = []
for spec, verified in zip(specs, expected):
    samples = [row for row in rows if row["name"] == spec["name"]]
    groups.append(dict(name=spec["name"], rounds=verified["rounds"],
        input_sha256=hashlib.sha256(codec.dumps(spec).encode()).hexdigest(),
        final_state_sha256=verified["final_state_sha256"], outcome=verified["outcome"],
        wall=distribution([r["wall_ms"] for r in samples]), cpu=distribution([r["cpu_ms"] for r in samples])))
middle = len(rows)//2
report = dict(implementation=config["implementation"], source_revision=config["source_revision"],
    source_sha256=config["source_sha256"], inputs_sha256=full_match_inputs.input_hash(),
    python=sys.version, python_implementation=platform.python_implementation(), executable=sys.executable,
    platform=platform.platform(), processor=platform.processor(), logical_cpus=os.cpu_count(),
    gc_enabled=gc.isenabled(), process_id=os.getpid(), one_process_for_all_games=True,
    unrecorded_warmup_games=0, measured_games=len(rows), samples=rows, cases=groups,
    mean_wall_ms=statistics.mean(r["wall_ms"] for r in rows),
    mean_cpu_ms=statistics.mean(r["cpu_ms"] for r in rows),
    first_half_mean_wall_ms=statistics.mean(r["wall_ms"] for r in rows[:middle]),
    last_half_mean_wall_ms=statistics.mean(r["wall_ms"] for r in rows[middle:]),
    initial_pair_mean_wall_ms=statistics.mean(r["wall_ms"] for r in rows[:len(specs)]),
    all_final_digests_matched=True, profiling_enabled=False,
    pypy_environment={k:os.environ[k] for k in ("PYPY_GC_MAX", "PYPY_GC_MIN", "PYPY_GC_NURSERY",
        "PYPY_GC_MAJOR_COLLECT", "PYPY_GC_GROWTH", "PYPY_GC_MAX_DELTA", "PYPYLOG") if k in os.environ},
    interpreter_flags=str(sys.flags), interpreter_xoptions=sys._xoptions,
    memory_measurement=None, failures=0)
Path(config["report_path"]).write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
'''


def run(root, parity, games=20, reverse=False, report_dir=None):
    if type(games) is not int or games < 4 or games > 100 or games % 4:
        raise ValueError("games must be a multiple of four between 4 and 100")
    root = Path(root).resolve()
    revision, source_hash = source_identity(root)
    validate_parity(parity, revision, source_hash)
    same(sys.version, parity.get("python"), "parity_prerequisite.python")
    same(platform.python_implementation(), parity.get("python_implementation"), "parity_prerequisite.runtime")
    sources = baseline_sources(root)
    native = check_native_sources(root, sources)
    same(INPUTS_SHA256, inputs.input_hash(), "comparison.inputs_sha256")
    shared = {}
    for name in ("Scripts/Sim/u13_pysim/benchmark_full_match.py", "Scripts/Sim/u13_pysim/full_match_inputs.json"):
        content = text_bytes((root / name).read_bytes())
        if content != text_bytes(sources[name]): raise ValueError("shared workload changed: " + name)
        shared[name] = hashlib.sha256(content).hexdigest()
    order = ["candidate", "baseline"] if reverse else ["baseline", "candidate"]
    blocks = []
    with tempfile.TemporaryDirectory(prefix="u13-full-match-copying-") as temp:
        temp = Path(temp)
        for name, content in sources.items():
            target = temp / "baseline" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        results = Path(report_dir).resolve() if report_dir is not None else temp / "results"
        results.mkdir(parents=True, exist_ok=True)
        for label in order:
            output = results / (label + "-samples.json")
            config = dict(implementation=label, games=games,
                          sim_path=str((temp / "baseline" if label == "baseline" else root) / "Scripts/Sim"),
                          source_revision=BASELINE if label == "baseline" else revision,
                          source_sha256=BASELINE_SOURCE if label == "baseline" else source_hash,
                          inputs_sha256=INPUTS_SHA256, expected_games=parity["reference_verification"]["games"],
                          report_path=str(output))
            config_path = temp / (label + ".json")
            config_path.write_text(json.dumps(config), encoding="utf-8")
            print("Sustained copying comparison: " + label, flush=True)
            subprocess.run([sys.executable, "-c", WORKER, str(config_path)], check=True, timeout=900)
            block = json.loads(output.read_text(encoding="utf-8"))
            same(games, block["measured_games"], "worker.measured_games")
            same(True, block["all_final_digests_matched"], "worker.exact_results")
            same(0, block["failures"], "worker.failures")
            if any(not math.isfinite(r["wall_ms"]) or r["wall_ms"] <= 0 for r in block["samples"]):
                raise ValueError("worker timing sample invalid")
            blocks.append(block)
    by_label = {block["implementation"]: block for block in blocks}
    baseline, candidate = by_label["baseline"], by_label["candidate"]
    for key in ("python", "python_implementation", "executable", "platform", "inputs_sha256", "gc_enabled"):
        same(baseline[key], candidate[key], "comparison." + key)
    for before, after in zip(baseline["cases"], candidate["cases"]):
        for key in ("name", "rounds", "input_sha256", "final_state_sha256", "outcome"):
            same(before[key], after[key], "comparison.case." + key)
    before, after = baseline["mean_wall_ms"], candidate["mean_wall_ms"]
    return dict(schema=SCHEMA, source_revision=revision, source_sha256=source_hash,
                baseline_revision=BASELINE, baseline_source_sha256=BASELINE_SOURCE,
                inputs_sha256=INPUTS_SHA256, reference_trace_sha256=TRACE_SHA256,
                native_sources=native, shared_workload_sha256=shared,
                worker_sha256=hashlib.sha256(WORKER.encode()).hexdigest(),
                workers=1, block_order=order, games_per_implementation=games,
                same_python_executable=True, parity_prerequisite_passed=True,
                initial_games_included=True, blocks=blocks, mean_wall_speedup=before / after,
                mean_wall_reduction_percent=100 * (1 - after / before),
                included="independent setup; explicit decisions; all 20 hooks; transactions; complete semantic history; victory",
                excluded="process startup/imports; input loading; policy selection; comparison snapshots/digests; export; profiling",
                scope="alternating repetitions of the two accepted ordinary games, not roster-complete doctrine throughput",
                warmup_caveat="initial games and early/later halves are reported; no steady-state JIT or sustained campaign capacity is asserted",
                memory_measurement=None, full_match_50000_wall_seconds=None, failures=0)
