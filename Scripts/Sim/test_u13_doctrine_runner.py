#!/usr/bin/env python3
"""Exercise Bash runner deadlines and packaged failures with stub runtimes.

These process tests do not run, or stand in for, doctrine/runtime parity.
Run separately with: python3 Scripts/Sim/test_u13_doctrine_runner.py
"""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
import zipfile


STUB = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys
import time

runtime = Path(__file__).name
if sys.argv[1] == '-c':
    # Only the identity probes are simulated; the log scanner below is real.
    code = sys.argv[2].replace('sys.implementation.name', repr(runtime))
    code = code.replace('platform.python_implementation()', repr(runtime.title()))
    exec(code)
    sys.exit(0)
if sys.argv[1] == '-':
    sys.exit(subprocess.call([sys.executable, *sys.argv[1:]]))
command = sys.argv[2]
if command == 'check':
    destination = Path(sys.argv[sys.argv.index('--report') + 1])
    destination.with_suffix('.pid').write_text(str(os.getpid()))
    behavior = os.environ.get('U13_RUNNER_STUB', 'pass')
    print('Runner fixture started: ' + runtime, flush=True)
    if behavior == runtime + '_watchdog':
        time.sleep(30)
    if behavior == 'command_failure':
        print('Synthetic check failure', flush=True)
        sys.exit(7)
    if behavior == 'log_error':
        print('ERROR: synthetic zero-exit failure', flush=True)
        sys.exit(0)
    destination.write_text(json.dumps({'fixture': True, 'runtime': runtime}))
    print('PASS runner fixture (not a doctrine result)', flush=True)
elif command == 'compare':
    for path in sys.argv[3:]:
        assert json.loads(Path(path).read_text())['fixture']
    print('PASS runner fixture comparison', flush=True)
else:
    raise ValueError(command)
'''


@unittest.skipUnless(os.name == 'posix' and shutil.which('bash') and shutil.which('git'),
                     'POSIX process checks require Bash and Git')
class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix='u13 runner test ')
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        scripts = self.root / 'Scripts' / 'Sim'
        scripts.mkdir(parents=True)
        for name in ('run_u13_common_doctrine.sh', 'package_u13_reports.sh'):
            shutil.copyfile(Path(__file__).with_name(name), scripts / name)
        self.runner = scripts / 'run_u13_common_doctrine.sh'
        for name in ('cpython', 'pypy'):
            path = self.root / name
            path.write_text(STUB)
            path.chmod(0o755)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        subprocess.run(['git', '-C', str(self.root), '-c', 'user.name=Runner Test',
                        '-c', 'user.email=runner@example.invalid', 'commit',
                        '--allow-empty', '-qm', 'Runner fixture'], check=True)
        self.env = dict(os.environ, U13_REPORT_DOWNLOADS=str(self.root / 'reports'))
        self.env.pop('U13_DOCTRINE_TIMEOUT_SECONDS', None)
        self.env.pop('U13_RUNNER_STUB', None)
        self.command = ['bash', str(self.runner), str(self.root / 'pypy'), str(self.root / 'cpython')]

    def archive(self, result, expected_exit, reason):
        self.assertEqual(result.returncode, expected_exit, result.stdout)
        archives = list((self.root / 'reports').glob('*.zip'))
        self.assertEqual(len(archives), 1, result.stdout)
        with zipfile.ZipFile(archives[0]) as archive:
            files = {name: archive.read(name).decode() for name in archive.namelist()
                     if not name.endswith('/')}
        status = dict(line.split('=', 1) for line in files['run-status.txt'].splitlines())
        self.assertEqual(status['exit_status'], str(expected_exit))
        self.assertEqual(status['reason'], reason)
        self.assertIn('UPLOAD THIS FILE:', result.stdout)
        self.assertIn('runtimes.txt', files)
        return status, files

    def run_fixture(self, behavior='pass', timeout=None):
        self.env['U13_RUNNER_STUB'] = behavior
        if timeout is not None:
            self.env['U13_DOCTRINE_TIMEOUT_SECONDS'] = str(timeout)
        return subprocess.run(self.command, env=self.env, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, timeout=15)

    def assert_stopped(self, files, runtime):
        with self.assertRaises(ProcessLookupError):
            os.kill(int(files[runtime + '.pid']), 0)

    def test_success_has_separate_python_and_comparison_budgets(self):
        status, files = self.archive(self.run_fixture(), 0, 'passed')
        self.assertEqual(status['phase'], 'comparison.log')
        self.assertEqual(status['doctrine_timeout_seconds'], '1800')
        for runtime in ('cpython', 'pypy'):
            self.assertIn(f'START {runtime}.log (timeout 1800 seconds)', files['runner.log'])
            self.assertIn(runtime + '.json', files)
            self.assert_stopped(files, runtime)
        self.assertIn('START comparison.log (timeout 600 seconds)', files['runner.log'])

    def test_command_failure_preserves_status_and_stops_before_pypy(self):
        status, files = self.archive(self.run_fixture('command_failure'), 7, 'command_failed')
        self.assertEqual(status['phase'], 'cpython.log')
        self.assertIn('exited 7', files['cpython.log'])
        self.assertNotIn('pypy.log', files)

    def test_logged_error_cannot_pass_with_zero_exit_status(self):
        status, files = self.archive(self.run_fixture('log_error'), 1, 'log_error')
        self.assertEqual(status['phase'], 'cpython.log')
        self.assertIn('ERROR: synthetic', files['cpython.log'])
        self.assertNotIn('pypy.log', files)

    def check_watchdog(self, runtime):
        status, files = self.archive(self.run_fixture(runtime + '_watchdog', 1),
                                     124, 'watchdog_timeout')
        self.assertEqual(status['phase'], runtime + '.log')
        self.assertEqual(status['phase_timeout_seconds'], '1')
        self.assertGreaterEqual(int(status['phase_elapsed_seconds']), 1)
        self.assertLess(int(status['phase_elapsed_seconds']), 10)
        for log in (runtime + '.log', 'runner.log'):
            self.assertIn('FAIL doctrine watchdog:', files[log])
        self.assertNotIn('comparison.log', files)
        self.assert_stopped(files, runtime)
        return files

    def test_cpython_timeout_kills_child_and_packages_the_reason(self):
        files = self.check_watchdog('cpython')
        self.assertNotIn('pypy.log', files)

    def test_pypy_timeout_keeps_completed_cpython_report(self):
        files = self.check_watchdog('pypy')
        self.assertIn('cpython.json', files)

    def test_termination_kills_child_and_packages_the_reason(self):
        self.env['U13_RUNNER_STUB'] = 'cpython_watchdog'
        with subprocess.Popen(self.command, env=self.env, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True) as process:
            try:
                deadline = time.monotonic() + 5
                while not list((self.root / 'reports').glob('*/cpython.pid')):
                    self.assertIsNone(process.poll())
                    self.assertLess(time.monotonic(), deadline)
                    time.sleep(0.05)
                process.send_signal(signal.SIGTERM)
                output, _ = process.communicate(timeout=10)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()
        result = subprocess.CompletedProcess(self.command, process.returncode, output)
        status, files = self.archive(result, 143, 'terminated')
        self.assertEqual(status['phase'], 'cpython.log')
        self.assert_stopped(files, 'cpython')

    def test_invalid_timeout_is_rejected_before_starting(self):
        for value in ('0', '-1', '1.5', 'abc', '01', '86401'):
            with self.subTest(value=value):
                result = self.run_fixture(timeout=value)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('must be an integer', result.stdout)
                self.assertFalse((self.root / 'reports').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
