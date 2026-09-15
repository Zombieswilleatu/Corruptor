#!/usr/bin/env python3
"""CLI for bounded U13 parity gates; requires Python 3.10+, stdlib only."""

import argparse
import json
from pathlib import Path
import sys
import subprocess
import unittest

from u13_pysim import codec
from u13_pysim.verify import source_identity, verify, verify_rejections


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("source-identity")
    commands.add_parser("self-test")
    commands.add_parser("self-test-planning")
    commands.add_parser("self-test-development")
    commands.add_parser("self-test-copying")
    commands.add_parser("self-test-resolution")
    commands.add_parser("self-test-marching")
    commands.add_parser("self-test-full-match")
    inputs = commands.add_parser("generate-full-match-inputs")
    inputs.add_argument("--output",type=Path,required=True)
    benchmark = commands.add_parser("benchmark-development")
    benchmark.add_argument("--iterations", type=int, default=30, help="Measured cycles per setup; nine setups")
    benchmark.add_argument("--report", type=Path)
    copying = commands.add_parser("benchmark-copying")
    copying.add_argument("--iterations", type=int, default=15, help="Cycles per setup per block; two blocks per implementation")
    copying.add_argument("--no-profiles", action="store_true")
    copying.add_argument("--report", type=Path)
    marching = commands.add_parser("benchmark-marching")
    marching.add_argument("--iterations", type=int, default=20)
    marching.add_argument("--verified-report", type=Path, required=True)
    marching.add_argument("--report", type=Path)
    full = commands.add_parser("benchmark-full-match")
    full.add_argument("--iterations",type=int,default=3)
    full.add_argument("--verified-report",type=Path,required=True)
    full.add_argument("--report",type=Path)
    full_copy_check = commands.add_parser("verify-full-match-copying")
    full_copy_check.add_argument("trace",type=Path)
    full_copy_check.add_argument("--report",type=Path)
    full_copy = commands.add_parser("benchmark-full-match-copying")
    full_copy.add_argument("--games",type=int,default=20,help="Alternating full matches per implementation, in one process")
    full_copy.add_argument("--verified-report",type=Path,required=True)
    full_copy.add_argument("--report",type=Path,required=True)
    full_copy.add_argument("--reverse",action="store_true",help="Run candidate before baseline")
    for command in ("verify", "verify-planning", "verify-development", "verify-resolution", "verify-marching", "verify-full-match"):
        check = commands.add_parser(command)
        check.add_argument("trace", type=Path)
        check.add_argument("--diagnostic", action="store_true", help="Label local non-Windows/4.7.2 results diagnostic only")
        check.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.command.startswith("self-test"):
        stages = ["foundation","planning","development","copying","resolution","marching","full_match"]
        stage = "foundation" if args.command == "self-test" else args.command.removeprefix("self-test-").replace("-","_")
        modules = ["u13_pysim.test_"+name for name in stages[:stages.index(stage)+1]]
        tests = unittest.defaultTestLoader.loadTestsFromNames(modules)
        result = unittest.TextTestRunner(verbosity=2).run(tests)
        return 0 if result.wasSuccessful() else 1
    if args.command == "generate-full-match-inputs":
        from u13_pysim.full_match_inputs import generate
        args.output.write_text(json.dumps(generate(),indent=2)+"\n",encoding="utf-8")
        print("Generated explicit complete-game inputs; Godot verification is required")
        return 0
    revision, source_hash = source_identity(root)
    if args.command == "source-identity":
        print(revision)
        print(source_hash)
        return 0
    if args.command == "verify-full-match-copying":
        from u13_pysim.benchmark_full_match_copying import replay
        try:
            result = replay(root,args.trace)
            if args.report: args.report.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
            exact = result["reference_verification"]
            print(f"Copied-state replay: {exact['complete_games_matched']} complete games, {exact['game_operations_matched']} operations, {exact['deliberate_mismatches_rejected']} corruption rejections")
            print("Accepted Windows Godot 4.7.2 reference reused; candidate source identity recorded separately")
            print("U13 PySim full-match copying parity failures: 0")
            return 0
        except (ValueError,OSError,KeyError,TypeError,subprocess.SubprocessError) as error:
            print(f"FAIL U13 PySim full-match copying parity: {error}",file=sys.stderr)
            return 1
    if args.command == "benchmark-full-match-copying":
        from u13_pysim.benchmark_full_match_copying import run
        try:
            parity = json.loads(args.verified_report.read_text(encoding="utf-8"))
            result = run(root,parity,args.games,args.reverse,args.report.parent)
            args.report.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
            blocks = {r["implementation"]:r for r in result["blocks"]}
            before,after = blocks["baseline"],blocks["candidate"]
            print(f"Full-match copying: {before['mean_wall_ms']:.2f} -> {after['mean_wall_ms']:.2f} ms; {result['mean_wall_speedup']:.2f}x observed speedup")
            print(f"Candidate first/later half means: {after['first_half_mean_wall_ms']:.2f} / {after['last_half_mean_wall_ms']:.2f} ms; initial games included")
            print("U13 PySim full-match copying timing failures: 0")
            return 0
        except (ValueError,OSError,KeyError,TypeError,subprocess.SubprocessError) as error:
            print(f"FAIL U13 PySim full-match copying timing: {error}",file=sys.stderr)
            return 1
    if args.command == "benchmark-development":
        from u13_pysim.benchmark_development import run
        try:
            result = run(revision, source_hash, args.iterations)
            if args.report:
                args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
            print(json.dumps(result, indent=2))
            print("U13 PySim development partial timing completed; full-match speed unknown")
            return 0
        except (ValueError, OSError) as error:
            print(f"FAIL U13 PySim development timing: {error}", file=sys.stderr)
            return 1
    if args.command == "benchmark-copying":
        from u13_pysim.benchmark_copying import run
        try:
            result = run(root, args.iterations, not args.no_profiles)
            if args.report:
                args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
            before = result["summary"]["baseline"]["mean_wall_ms"]
            after = result["summary"]["current"]["mean_wall_ms"]
            print(f"Partial cycle: {before:.2f} ms baseline -> {after:.2f} ms current; {result['mean_wall_speedup']:.2f}x")
            print("Full-match speed remains unknown")
            print("U13 PySim copying comparison failures: 0")
            return 0
        except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
            print(f"FAIL U13 PySim copying: {error}", file=sys.stderr)
            if isinstance(error, subprocess.CalledProcessError) and error.stderr:
                print(error.stderr, file=sys.stderr)
            return 1
    if args.command == "benchmark-marching":
        from u13_pysim.benchmark_marching import run
        try:
            parity = json.loads(args.verified_report.read_text(encoding="utf-8"))
            result = run(revision, source_hash, parity, args.iterations)
            if args.report:
                args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
            for case in result["cases"]:
                wall = case["wall"]
                print(f"{case['name']}: {wall['batch_phase']['mean_ms']:.2f} ms per 200-tick batch phase; {wall['trace_phase']['mean_ms']:.2f} ms with tick recording")
            print("Full-match speed remains unknown")
            print("U13 PySim marching timing failures: 0")
            return 0
        except (ValueError, OSError, KeyError, TypeError) as error:
            print(f"FAIL U13 PySim marching timing: {error}", file=sys.stderr)
            return 1
    if args.command == "benchmark-full-match":
        from u13_pysim.benchmark_full_match import run
        try:
            parity = json.loads(args.verified_report.read_text(encoding="utf-8"))
            result = run(revision,source_hash,parity,args.iterations)
            if args.report: args.report.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
            for game in result["games"]:
                print(f"{game['name']}: {game['wall']['mean_ms']:.2f} ms per complete {game['rounds']}-round match")
            print("Explicit ordinary games; policy selection excluded; not roster-complete doctrine throughput")
            print("U13 PySim full-match timing failures: 0")
            return 0
        except (ValueError,OSError,KeyError,TypeError) as error:
            print(f"FAIL U13 PySim full-match timing: {error}",file=sys.stderr)
            return 1
    if args.command == "verify-full-match":
        from u13_pysim.verify_full_match import verify as compare, verify_rejections as reject
        try:
            result = compare(args.trace,revision,source_hash,args.diagnostic)
            result["deliberate_mismatches_rejected"] = reject(args.trace,revision,source_hash,args.diagnostic)
            if args.report: args.report.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
            print(json.dumps(result,indent=2))
            print("U13 PySim full-match Python failures: 0")
            return 0
        except (ValueError,TypeError,KeyError,OSError,UnicodeError) as error:
            print(f"FAIL U13 PySim full-match: {error}",file=sys.stderr)
            return 1
    label = {"verify-planning": "planning", "verify-development": "development", "verify-resolution": "resolution", "verify-marching": "marching"}.get(args.command, "foundation")
    compare, reject = verify, verify_rejections
    if label == "planning":
        from u13_pysim.verify_planning import verify as compare, verify_rejections as reject
    elif label == "development":
        from u13_pysim.verify_development import verify as compare, verify_rejections as reject
    elif label == "resolution":
        from u13_pysim.verify_resolution import verify as compare, verify_rejections as reject
    elif label == "marching":
        from u13_pysim.verify_marching import verify as compare, verify_rejections as reject
    try:
        suite = codec.loads(args.trace.read_text(encoding="utf-8"))
        result = compare(suite, revision, source_hash, diagnostic=args.diagnostic)
        result["deliberate_mismatches_rejected"] = reject(suite, revision, source_hash, diagnostic=args.diagnostic)
        if args.report:
            args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, indent=2))
        print(f"U13 PySim {label} Python failures: 0")
        return 0
    except (ValueError, TypeError, KeyError, OSError, UnicodeError) as error:
        print(f"FAIL U13 PySim {label}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    if sys.version_info < (3, 10):
        raise SystemExit("Python 3.10 or newer is required")
    raise SystemExit(main())
