"""Single-process partial rules timing. This does not run complete matches."""

import math
import os
import platform
import statistics
import time

from .development import DevelopmentMatch, VERSION
from .development_fixtures import setup, scripted_operations

VERSION_BENCHMARK = "U13_PYSIM_DEVELOPMENT_TIMING_V1"


def distribution(samples):
    ordered = sorted(samples)
    return dict(samples=len(samples), mean_ms=statistics.mean(samples),
                median_ms=statistics.median(samples),
                p95_ms=ordered[math.ceil(len(ordered) * 0.95) - 1],
                min_ms=ordered[0], max_ms=ordered[-1])


def run(revision, source_hash, iterations=30):
    if not 1 <= iterations <= 1000:
        raise ValueError("iterations must be between 1 and 1000 per Lord setup")
    # These are explicit fixture inputs, prepared outside timing. No doctrine is
    # embedded in the engine, and no expected Godot snapshots are read here.
    cases = [(setup(index), scripted_operations(index)) for index in range(9)]
    groups = (("upkeep_and_choices", 0, 6), ("submission_and_lock", 6, 8), ("development", 8, 9))
    phases = {name: [] for name in ("opening", *[group[0] for group in groups])}
    walls, cpus = [], []

    def cycle(config, operations, measured):
        start_cpu, start_wall = time.process_time_ns(), time.perf_counter_ns()
        game = DevelopmentMatch(config)
        previous = time.perf_counter_ns()
        if measured:
            phases["opening"].append((previous - start_wall) / 1e6)
        for name, first, end in groups:
            for op in operations[first:end]:
                result = game.apply(op)
                if result["action"] == "invalid":
                    raise ValueError("timing input rejected: " + str(result))
            current = time.perf_counter_ns()
            if measured:
                phases[name].append((current - previous) / 1e6)
            previous = current
        if measured:
            walls.append((previous - start_wall) / 1e6)
            cpus.append((time.process_time_ns() - start_cpu) / 1e6)

    for config, operations in cases:
        cycle(config, operations, False)
    # Interleave all nine setups, avoiding one large run of a single Lord.
    for _ in range(iterations):
        for config, operations in cases:
            cycle(config, operations, True)
    return dict(schema=VERSION_BENCHMARK, python_mirror=VERSION,
                source_revision=revision, source_sha256=source_hash,
                python=platform.python_version(), python_implementation=platform.python_implementation(),
                platform=platform.platform(), machine=platform.machine(), processor=platform.processor(),
                logical_cpus=os.cpu_count(), workers=1, warmup_cycles=9,
                measured_cycles=len(walls), iterations_per_setup=iterations,
                scope="fresh opening through first Development; six hooks; not a full round or match",
                includes=["opening RNG and setup", "engine transaction copies", "upkeep and Slaver passes",
                          "sealed submissions and lock", "two deployed pairs and Work", "engine events",
                          "small timing bookkeeping overhead"],
                excludes=["input selection and doctrine", "Godot execution", "trace encoding or decoding",
                          "external snapshots and exact comparisons", "artillery and combat", "Marching",
                          "later rounds and Lord effects", "victory", "worker scaling"],
                wall_cycle=distribution(walls), cpu_cycle=distribution(cpus),
                phase_wall={name: distribution(samples) for name, samples in phases.items()},
                measured_wall_seconds=sum(walls) / 1000, measured_cpu_seconds=sum(cpus) / 1000,
                python_full_match_implemented=False, full_match_games_per_second=None,
                full_match_50000_wall_seconds=None)
