"""Bounded phase timing and honest layout-boundary costs, not full-match speed."""

import cProfile
import gc
import hashlib
import os
import platform
import pstats
import sys
import time

from . import codec, marching as m, marching_fixtures as f
from .benchmark_development import distribution
from .copying import copy_data
from .marching_columns import Columns
from .primitives import Entities, IDS_VERSION
from .verify import same


class RowBoundary:
    """Owned row dictionaries for import/publish comparison only; no row tick loop."""
    def __init__(self, raw):
        checked = Entities()
        checked.restore(raw)
        self.rows = [checked.rows[key] for key in sorted(checked.rows)]
        self.used = sorted(checked.used)

    def snapshot(self):
        return dict(schema_version=IDS_VERSION, entities=copy_data(self.rows), used_ids=self.used[:])


def digest(value):
    return hashlib.sha256(codec.dumps(value).encode("utf-8")).hexdigest()


def reachable_bytes(value, seen=None):
    """Deduplicated reachable Python object sizes, not incremental allocation/RSS."""
    seen = set() if seen is None else seen
    if id(value) in seen:
        return 0
    seen.add(id(value))
    size = sys.getsizeof(value)
    if isinstance(value, dict):
        return size + sum(reachable_bytes(k, seen) + reachable_bytes(v, seen) for k, v in value.items())
    if isinstance(value, (list, tuple)):
        return size + sum(reachable_bytes(v, seen) for v in value)
    if hasattr(value, "__dict__"):
        return size + reachable_bytes(vars(value), seen)
    return size


def measured(call):
    cpu, wall = time.process_time_ns(), time.perf_counter_ns()
    value = call()
    end_wall, end_cpu = time.perf_counter_ns(), time.process_time_ns()
    return value, (end_wall - wall) / 1e6, (end_cpu - cpu) / 1e6


def run(revision, source_hash, parity, iterations=20):
    if not 3 <= iterations <= 200:
        raise ValueError("iterations must be between 3 and 200")
    for key, value in dict(source_revision=revision, source_sha256=source_hash, inputs_sha256=f.input_hash(),
                           failures=0, batch_projection_verified=True).items():
        same(value, parity.get(key), "parity_prerequisite." + key)
    manifest, rows = f.load(), []
    for name in manifest["benchmark_cases"]:
        spec = next(c for c in manifest["cases"] if c["name"] == name)
        ctx = f.context(spec, f.initial(spec), 1)
        raw, input_digest = ctx["world"]["entities"], digest(ctx)
        expected = m.resolve(ctx)
        if expected["action"] != "resolved":
            raise ValueError("benchmark input did not resolve: " + name)
        projected = f.strip_ticks(expected)
        boundary = {"rows": RowBoundary(raw), "columns": Columns(raw)}
        same(boundary["rows"].snapshot(), boundary["columns"].snapshot(), "layout_roundtrip")
        walls = {key: [] for key in ("batch_phase", "trace_phase", "phase_prepare", "prepared_batch_work",
                                     "row_import", "column_import", "row_publish", "column_publish")}
        cpus = {key: [] for key in walls}
        # Fresh state per measurement. Warm-up does not leak unit deaths into trials.
        for _ in range(2):
            same(projected, m.resolve(ctx, capture_ticks=False), "warmup.batch")
            same(expected, m.resolve(ctx), "warmup.trace")
        for ordinal in range(iterations):
            order = (False, True) if ordinal % 2 == 0 else (True, False)
            for trace in order:
                key = "trace_phase" if trace else "batch_phase"
                result, wall, cpu = measured(lambda: m.resolve(ctx, capture_ticks=trace))
                walls[key].append(wall); cpus[key].append(cpu)
                same(expected if trace else projected, result, name + ".timed_result")
            phase, wall, cpu = measured(lambda: m.Phase(ctx, False, None))
            walls["phase_prepare"].append(wall); cpus["phase_prepare"].append(cpu)
            result, wall, cpu = measured(phase.run)
            walls["prepared_batch_work"].append(wall); cpus["prepared_batch_work"].append(cpu)
            same(projected, result, name + ".prepared_result")
            for layout in (("rows", "columns") if ordinal % 2 == 0 else ("columns", "rows")):
                constructor = RowBoundary if layout == "rows" else Columns
                key = "row" if layout == "rows" else "column"
                imported, wall, cpu = measured(lambda: constructor(raw))
                walls[key + "_import"].append(wall); cpus[key + "_import"].append(cpu)
                published, wall, cpu = measured(imported.snapshot)
                walls[key + "_publish"].append(wall); cpus[key + "_publish"].append(cpu)
                same(boundary[layout].snapshot(), published, name + ".layout_roundtrip")
        same(input_digest, digest(ctx), name + ".input_not_mutated")
        profile = cProfile.Profile()
        profiled = profile.runcall(m.resolve, ctx, capture_ticks=False)
        same(projected, profiled, name + ".profiled_result")
        functions = []
        for (file, line, function), (primitive, total, exclusive, cumulative, callers) in sorted(
                pstats.Stats(profile).stats.items(), key=lambda item: item[1][3], reverse=True)[:16]:
            functions.append(dict(file=file.replace("\\", "/").split("/")[-1], line=line, function=function,
                                  primitive_calls=primitive, total_calls=total, exclusive_seconds=exclusive, cumulative_seconds=cumulative))
        counts = {}
        for row in projected["events"]:
            kind = row["event"]["type"]
            counts[kind] = counts.get(kind, 0) + 1
        summary = {key: distribution(value) for key, value in walls.items()}
        rows.append(dict(name=name, seed=spec["seed"], round=1, ticks=200, initial_marchers=len(raw["entities"]),
                         final_marchers=len(expected["world"]["entities"]["entities"]), event_counts=counts,
                         input_sha256=input_digest, batch_result_sha256=digest(projected), trace_result_sha256=digest(expected),
                         wall=summary, cpu={key: distribution(value) for key, value in cpus.items()},
                         amortized_batch_us_per_tick=summary["batch_phase"]["mean_ms"] * 1000 / 200,
                         reachable_python_object_bytes={key: reachable_bytes(value) for key, value in boundary.items()},
                         separate_instrumented_profile=functions))
    return dict(schema="U13_PYSIM_MARCHING_TIMING_V1", source_revision=revision, source_sha256=source_hash,
                inputs_sha256=f.input_hash(), python_mirror=m.VERSION, diagnostic_only=parity["diagnostic_only"],
                reference_runtime=parity["runtime"], python=platform.python_version(), implementation=platform.python_implementation(),
                platform=platform.platform(), machine=platform.machine(), processor=platform.processor(), logical_cpus=os.cpu_count(),
                workers=1, garbage_collection_enabled=gc.isenabled(), iterations_per_case=iterations, warmups_per_mode_per_case=2,
                scope="three isolated 200-tick phases; ordinary/dense/Gravity inputs; no full game or doctrine",
                phase_modes=dict(batch_phase="public resolve; includes validation, import, all rule events and final publication; excludes MARCHING_TICK recording",
                                 trace_phase="same public resolve plus all 200 exact tick frames",
                                 phase_prepare="owned context copy and validated column import only",
                                 prepared_batch_work="phase.run after preparation; includes tick work, rule events and final publication"),
                layout_scope="validated import and publication only; RowBoundary is not a competing optimized row-based tick kernel",
                memory_scope="deduplicated reachable Python object bytes; neither process RSS nor incremental allocator usage",
                excludes=["fixture selection", "exact comparisons and hashing", "Godot execution", "export/JSON I/O", "policy decisions",
                          "unported Lord reactions and actors", "remaining round hooks", "victory", "worker scaling"],
                cases=rows, failures=0, full_match_games_per_second=None, full_match_50000_wall_seconds=None)
