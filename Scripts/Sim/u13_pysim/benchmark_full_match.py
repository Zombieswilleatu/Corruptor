"""Actual setup-to-victory timing for the verified, explicitly scoped games."""

import cProfile
import gc
import hashlib
import os
import platform
import pstats
import sys
import time

from . import codec, full_match_inputs as f
from .benchmark_development import distribution
from .full_match import FullMatch, VERSION
from .verify import same


def digest(match):
    return hashlib.sha256(codec.dumps(match.snapshot()).encode()).hexdigest()


def play(spec, stage_times=None):
    start = time.perf_counter_ns()
    match = FullMatch(spec["setup"])
    if stage_times is not None: stage_times["setup"] = (time.perf_counter_ns()-start)/1e6
    for op in spec["operations"]:
        start = time.perf_counter_ns() if stage_times is not None else 0
        result = match.apply(op)
        if result["action"] == "invalid": raise ValueError(f"Timed operation rejected: {op}: {result}")
        if stage_times is not None:
            key = op.get("hook",op["kind"])
            stage_times[key] = stage_times.get(key,0)+(time.perf_counter_ns()-start)/1e6
    if not match.clock.completed or match.outcome()["winner"] == -1:
        raise ValueError("Timed match did not reach victory")
    return match


def run(revision, source_hash, parity, iterations=3):
    if not 3 <= iterations <= 20: raise ValueError("iterations must be between 3 and 20")
    specs = f.load()["cases"]
    for key,value in dict(python_mirror=VERSION,source_revision=revision,source_sha256=source_hash,
            inputs_sha256=f.input_hash(),complete_games_matched=len(specs),fixture_operations=0,
            all_semantic_rows_and_views_matched=True,failures=0).items():
        same(value,parity.get(key),"parity_prerequisite."+key)
    rows = []
    for spec,verified in zip(specs,parity["games"]):
        same(spec["name"],verified["name"],"parity_prerequisite.game")
        same(digest(play(spec)),verified["final_state_sha256"],"warmup.final_state")
        walls,cpus = [],[]
        for _ in range(iterations):
            cpu,wall = time.process_time_ns(),time.perf_counter_ns()
            match = play(spec)
            walls.append((time.perf_counter_ns()-wall)/1e6)
            cpus.append((time.process_time_ns()-cpu)/1e6)
            same(digest(match),verified["final_state_sha256"],"timed.final_state")
            same(match.outcome(),verified["outcome"],"timed.outcome")
        # Profile a separate full game; its overhead is excluded from timings.
        stages,profiler = {},cProfile.Profile()
        profiled = profiler.runcall(play,spec,stages)
        same(digest(profiled),verified["final_state_sha256"],"profiled.final_state")
        functions = []
        for (file,line,function),(primitive,total,exclusive,cumulative,_) in sorted(
                pstats.Stats(profiler).stats.items(),key=lambda item:item[1][3],reverse=True)[:24]:
            functions.append(dict(file=file.replace("\\","/").split("/")[-1],line=line,function=function,
                primitive_calls=primitive,total_calls=total,exclusive_seconds=exclusive,cumulative_seconds=cumulative))
        rows.append(dict(name=spec["name"],setup=spec["setup"],rounds=verified["rounds"],outcome=verified["outcome"],
            input_sha256=hashlib.sha256(codec.dumps(spec).encode()).hexdigest(),final_state_sha256=verified["final_state_sha256"],
            operations=len(spec["operations"]),peak_marchers=verified["peak_marchers"],event_rows=verified["event_rows"],
            wall=distribution(walls),cpu=distribution(cpus),wall_samples_ms=walls,cpu_samples_ms=cpus,
            profiled_stage_wall_ms=stages,profile=functions))
    mean = sum(r["wall"]["mean_ms"] for r in rows)/len(rows)
    return dict(schema="U13_FULL_MATCH_TIMING_V1",python_mirror=VERSION,source_revision=revision,source_sha256=source_hash,
        inputs_sha256=f.input_hash(),python=sys.version,platform=platform.platform(),processor=platform.processor(),
        logical_cpus=os.cpu_count(),gc_enabled=gc.isenabled(),diagnostic_only=parity["diagnostic_only"],
        reference_runtime=parity["runtime"],reference_platform=parity["reference_platform"],iterations_per_game=iterations,warmups_per_game=1,
        timer="perf_counter_ns + process_time_ns",event_profile="U13_BATCH_EVENTS_V1",
        included="independent setup; all decisions applied; 20 hooks per round; transactions; full semantic event history; victory",
        excluded="policy selection; Godot; input loading; snapshots for comparison; digesting; export; profiling overhead",
        scope=parity["scope"],games=rows,mean_full_match_wall_ms=mean,mean_games_per_second=1000/mean,
        target_50_ms_met=mean <= 50,
        full_match_50000_wall_seconds=None,
        throughput_caveat="two fixed games are a reference-path measurement, not a population or doctrine-throughput benchmark",
        failures=0)
