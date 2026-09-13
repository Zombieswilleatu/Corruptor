"""Report packaging/scheduler tests with a fake engine; no gameplay assertions.

Run: python3 Scripts/Sim/test_u13_report_exports.py
"""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import zipfile

SIM = Path(__file__).resolve().parent
MOCK_ENGINE = r'''#!/usr/bin/env python3
import json, os, pathlib, sys, time
args = sys.argv[1:]
mode = os.environ.get("U13_EXPORT_TEST_MODE", "won")
if "--version" in args:
    print("4.7.2.stable.export-test-driver")
    sys.exit(0)
script = pathlib.Path(args[args.index("--script") + 1]).name
footers = {
    "U13CommittedHuntTestRunner.gd": "U13 committed Hunt failures: 0",
    "U13BasicDoctrineTestRunner.gd": "U13 basic doctrine failures: 0",
    "U13PlanningPerformanceTestRunner.gd": "U13 planning performance failures: 0",
    "U13SnarePlanningTestRunner.gd": "U13 Snare planning failures: 0",
    "U13FullMatchBatchTestRunner.gd": "U13 full match harness failures: 0",
}
if script in footers:
    print(footers[script])
    sys.exit(0)
out = pathlib.Path(next(x.split("=", 1)[1] for x in args if x.startswith("--output=")))
if script == "U13ResolutionCacheTestRunner.gd":
    out.write_text(json.dumps({"test_driver": True}))
    print("FAIL injected" if mode == "fail" else "U13 resolution cache failures: 0")
    sys.exit(1 if mode == "fail" else 0)
out.mkdir(parents=True, exist_ok=True)
(out / "test-checkpoint.json").write_text(json.dumps({"test_driver": True, "mode": mode}))
if "--summarize" in args:
    (out / "summary.json").write_text(json.dumps({"test_driver": True}))
    print("U13 full match batch: export test")
    sys.exit(2 if mode == "censored" else 0)
if mode == "hang":
    (out / "test-worker.pid").write_text(str(os.getpid()))
    time.sleep(30)
    sys.exit(99)
if mode == "fail":
    print("FAIL injected match failure")
    sys.exit(1)
label = "doctrine match" if "Doctrine" in script else "full match"
print("U13 " + label + " " + mode + ": export test")
sys.exit(2 if mode == "censored" else 0)
'''


def run_tests(root):
    exports = root / "Downloads"
    exports.mkdir()
    engine = root / "test-engine"
    engine.write_text(MOCK_ENGINE)
    engine.chmod(0o755)
    env = dict(os.environ, U13_REPORT_DOWNLOADS=str(exports),
               U13_DOCTRINE_GAMES="1", U13_DOCTRINE_WORKERS="1",
               U13_BATCH_GAMES="1", U13_BATCH_WORKERS="1")
    for runner in ["doctrine", "full_matches", "resolution_perf"]:
        modes = ["won", "fail"] if runner == "resolution_perf" else ["won", "censored", "fail"]
        for mode in modes:
            reports = root / (runner + "-" + mode)
            before = set(exports.glob("*.zip"))
            result = subprocess.run(["bash", str(SIM / ("run_u13_" + runner + ".sh")),
                                     str(engine), str(reports)], env=dict(env, U13_EXPORT_TEST_MODE=mode),
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
            expected = {"won": 0, "censored": 2, "fail": 1}[mode]
            assert result.returncode == expected, result.stdout
            created = set(exports.glob("*.zip")) - before
            assert len(created) == 1 and "UPLOAD THIS FILE:" in result.stdout, result.stdout
            with zipfile.ZipFile(created.pop()) as archive:
                assert archive.testzip() is None
                assert ("exit_status=%d\n" % expected) in archive.read("run-status.txt").decode()
                assert any(name.endswith(".log") for name in archive.namelist())
                if runner == "doctrine":
                    assert "match-000/test-checkpoint.json" in archive.namelist()
            print("PASS archive and exit status:", runner, mode)

    # Export trouble must not turn a failed test green or lose the original log.
    for mode, expected in [("won", 0), ("fail", 1)]:
        reports = root / ("export-error-" + mode)
        result = subprocess.run(["bash", str(SIM / "run_u13_resolution_perf.sh"), str(engine), str(reports)],
                                env=dict(env, U13_EXPORT_TEST_MODE=mode, U13_REPORT_DOWNLOADS=str(reports)),
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
        assert result.returncode == expected and "Upload ZIP unavailable" in result.stdout, result.stdout
        assert (reports / "resolution.log").is_file()
    print("PASS archive errors preserve test result and original reports")

    # Stop two live workers, then archive both partial reports. The wrapper's
    # termination status must survive compression, and no engine may remain.
    reports = root / "interrupted"
    before = set(exports.glob("*.zip"))
    proc = subprocess.Popen(["bash", str(SIM / "run_u13_doctrine.sh"), str(engine), str(reports)],
                            env=dict(env, U13_EXPORT_TEST_MODE="hang", U13_DOCTRINE_GAMES="2", U13_DOCTRINE_WORKERS="2"),
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    deadline = time.monotonic() + 10
    try:
        while len(list(reports.glob("match-*/test-worker.pid"))) < 2 and time.monotonic() < deadline:
            time.sleep(0.05)
        pids = [int(p.read_text()) for p in reports.glob("match-*/test-worker.pid")]
        assert len(pids) == 2
        proc.send_signal(signal.SIGTERM)
        output, _ = proc.communicate(timeout=10)
        assert proc.returncode == 143, output
        created = set(exports.glob("*.zip")) - before
        assert len(created) == 1, output
        with zipfile.ZipFile(created.pop()) as archive:
            assert "exit_status=143\n" in archive.read("run-status.txt").decode()
            assert all("match-%03d/test-checkpoint.json" % i in archive.namelist() for i in range(2))
        for pid in pids:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                continue
            raise AssertionError("worker remained alive: %d" % pid)
        print("PASS interrupted run archives after stopping both workers")
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.communicate(timeout=10)

    # Export old reports twice without changing the first ZIP or executing any
    # path text. Spaces, Unicode, quotes and wildcard characters are literal.
    reports = root / "old run's [files] $literal"
    (reports / "match-000").mkdir(parents=True)
    (reports / "match-000" / "résumé.json").write_text('{"old":true}')
    originals = []
    for attempt in range(2):
        (reports / "summary.json").write_text(json.dumps({"attempt": attempt}))
        before = set(exports.glob("*.zip"))
        subprocess.run(["bash", str(SIM / "package_u13_reports.sh"), str(reports)], env=env,
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        new = (set(exports.glob("*.zip")) - before).pop()
        originals.append((new, new.read_bytes()))
        with zipfile.ZipFile(new) as archive:
            assert json.loads(archive.read("summary.json")) == {"attempt": attempt}
            # Linux zip may omit the UTF-8 flag; check content without decoding its filename.
            assert any(archive.read(n) == b'{"old":true}' for n in archive.namelist() if not n.endswith("/"))
    assert all(path.read_bytes() == data for path, data in originals)
    assert not list(exports.glob(".u13-package-*"))
    print("PASS repeated exports are unique, complete, and preserve earlier ZIPs")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="u13-export-tests-") as directory:
        run_tests(Path(directory))
    print("U13 report export tests passed")
