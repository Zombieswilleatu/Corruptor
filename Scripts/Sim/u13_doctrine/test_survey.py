"""Campaign coverage and evidence validation, without expensive game repeats."""
import tempfile
import os
from pathlib import Path
import unittest
from unittest.mock import patch

from .diagnostics import fingerprint
from .survey import aggregate, atomic_json, cases, read_record, pooled_results, run_one


def tiny_worker(spec, identity, directory):
    if spec == 'fail': raise ValueError('worker failure')
    return spec, os.getpid()


class SurveyTests(unittest.TestCase):
    def test_worker_recycling_and_disabled_mode(self):
        rotated = [r for r in pooled_results(list(range(5)), {}, '', 1, 2, tiny_worker) if r is not None]
        # Several completed futures may be returned together in either order.
        self.assertEqual(list(range(5)), sorted(r[0] for r in rotated))
        self.assertEqual(3, len({r[1] for r in rotated}))
        retained = list(pooled_results([0, 1, 2], {}, '', 1, 0, tiny_worker))
        self.assertEqual(1, len({r[1] for r in retained}))
        with self.assertRaisesRegex(ValueError, 'worker failure'):
            list(pooled_results(['fail'], {}, '', 1, 2, tiny_worker))

    def test_memory_sidecar_preserves_record_integrity(self):
        spec, identity = next(cases(1)), {'weights': {}}
        ops = [{'kind': 'step'}]
        semantic = dict(rounds=1, decisions_sha256=fingerprint(ops))
        with tempfile.TemporaryDirectory() as directory:
            games = Path(directory)/'games'; games.mkdir()
            with patch('u13_doctrine.survey.run_case', return_value=(semantic, {}, ops)):
                result = run_one(spec, identity, games)
            record = read_record(games/(spec['name']+'.json.gz'), identity, spec)
            self.assertEqual(semantic, record['semantic'])
            self.assertNotIn('performance', record)
            self.assertEqual(os.getpid(), result['performance']['after_gc']['pid'])
            self.assertTrue((Path(directory)/'performance'/(spec['name']+'.json')).is_file())

    def test_crossed_seeds_unique_ids_and_extension_preserve_first_pass(self):
        first, all_cases = list(cases(2)), list(cases(10))
        self.assertEqual(162, len(first))
        self.assertEqual(810, len(all_cases))
        self.assertEqual(first, all_cases[:162])
        self.assertEqual(810, len({c['name'] for c in all_cases}))
        self.assertEqual(81, len({tuple(c['setup']['lords']) for c in first}))
        index = {(tuple(c['setup']['lords']), c['repeat']): c for c in first}
        for c in first:
            reverse = index[(tuple(reversed(c['setup']['lords'])), c['repeat'])]
            self.assertEqual(c['setup']['seed'], reverse['setup']['seed'])
            self.assertEqual(c['setup']['castles'], list(reversed(reverse['setup']['castles'])))

    def test_resume_rejects_different_identity_and_corrupt_operations(self):
        spec, manifest, ops = next(cases(1)), {'identity': 'test'}, [{'kind': 'step'}]
        semantic = dict(decisions_sha256=fingerprint(ops))
        record = dict(manifest_sha256=fingerprint(manifest), spec=spec, status='complete',
            semantic=semantic, semantic_sha256=fingerprint(semantic), trace=[],
            trace_sha256=fingerprint([]), operations=ops)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'one.json.gz'
            atomic_json(path, record, compressed=True)
            self.assertEqual(record, read_record(path, manifest, spec))
            with self.assertRaisesRegex(ValueError, 'different survey'):
                read_record(path, {'identity': 'other'}, spec)
            record['operations'] = []
            atomic_json(path, record, compressed=True)
            with self.assertRaisesRegex(ValueError, 'corrupt operation'):
                read_record(path, manifest, spec)

    def test_failures_are_not_counted_as_completed_games(self):
        spec = next(cases(1))
        result = aggregate([dict(spec=spec, semantic={}, status='failed', error='censored', timing={}, wall_seconds=2)])
        self.assertEqual((0, 1, 0, 0), (result['completed'], result['failed'], result['rounds'], result['operations']))


if __name__ == '__main__': unittest.main()
