"""Archived baseline compatibility must not weaken source verification."""
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

import run_u13_ward_experiment as runner


class BaselineSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[2]
        cls.snapshots = {}
        for revision in runner.BASELINE_REVISIONS:
            raw = subprocess.check_output(['git', '-C', str(cls.root), 'archive', revision,
                                           '--', *runner.BASELINE_FOLDERS])
            with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
                cls.snapshots[revision] = {m.name: archive.extractfile(m).read()
                                          for m in archive if m.isfile() and m.name.endswith('.py')}

    def materialize(self, report, revision, crlf=False):
        for name, content in self.snapshots[revision].items():
            path = report/'source'/name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content.replace(b'\n', b'\r\n') if crlf else content)

    def test_both_complete_baselines_and_windows_line_endings(self):
        for revision in runner.BASELINE_REVISIONS:
            with self.subTest(revision=revision), tempfile.TemporaryDirectory() as tmp:
                report = Path(tmp)
                self.materialize(report, revision, crlf=True)
                self.assertEqual(revision, runner.baseline_source(self.root, report))

    def test_original_archive_needs_no_later_monitoring_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp)
            self.materialize(report, runner.ARCHIVED_BASELINE)
            self.assertFalse((report/'source/Scripts/Sim/u13_doctrine/process_memory.py').exists())
            self.assertEqual(runner.ARCHIVED_BASELINE, runner.baseline_source(self.root, report))

    def test_missing_changed_and_extra_rule_files_are_rejected(self):
        for mutation in ('missing', 'changed', 'extra'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                report = Path(tmp)
                self.materialize(report, runner.ARCHIVED_BASELINE)
                path = report/'source/Scripts/Sim/u13_pysim/monsters.py'
                if mutation == 'missing': path.unlink()
                elif mutation == 'changed': path.write_bytes(path.read_bytes()+b'\n# changed\n')
                else: path.with_name('unexpected_rules.py').write_text('# unknown source\n')
                with self.assertRaisesRegex(ValueError, 'no supported pre-change build'):
                    runner.baseline_source(self.root, report)

    def test_mixed_versions_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp)
            self.materialize(report, runner.ARCHIVED_BASELINE)
            name = 'Scripts/Sim/u13_pysim/marching.py'
            (report/'source'/name).write_bytes(self.snapshots[runner.BASELINE][name])
            with self.assertRaisesRegex(ValueError, 'no supported pre-change build'):
                runner.baseline_source(self.root, report)


if __name__ == '__main__': unittest.main()
