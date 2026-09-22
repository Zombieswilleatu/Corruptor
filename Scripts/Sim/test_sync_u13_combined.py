"""Exercise the updater in throwaway repositories, including refusal paths."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import sync_u13_combined as sync


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-b', 'u13-basic-doctrine')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'user.name', 'Fixture')
        (self.root/'a.py').write_bytes(b'base\n')
        (self.root/'stable.py').write_bytes(b'stable\n')
        self.git('add', '.'); self.git('commit', '-m', 'base')
        self.base = self.git('rev-parse', 'HEAD').strip()
        (self.root/'a.py').write_bytes(b'final\n')
        (self.root/'new.py').write_bytes(b'new\n')
        receipt = self.root/sync.RECEIPT; receipt.parent.mkdir(parents=True)
        receipt.write_text(json.dumps({'a.py':[sync.digest(b'base\n'),sync.digest(b'combined\n')],
                                       'stable.py':[sync.digest(b'stable\n')]}))
        self.git('add', '.'); self.git('commit', '-m', 'target')
        self.target = self.git('rev-parse', 'HEAD').strip()
        # Only the disposable fixture repository is reset.
        self.git('reset', '--hard', self.base)
        self.patch = patch.object(sync, 'BASE', self.base)
        self.patch.start(); self.addCleanup(self.patch.stop)

    def git(self, *args):
        return subprocess.check_output(['git','-C',str(self.root),*args], stderr=subprocess.DEVNULL, text=True)

    def test_known_combined_edits_fast_forward_and_preserve_stashes_and_unrelated_files(self):
        (self.root/'a.py').write_bytes(b'older personal edit\n')
        self.git('stash', 'push', '-m', 'older stash')
        old_stash = self.git('rev-parse', 'refs/stash').strip()
        (self.root/'a.py').write_bytes(b'combined\r\n')
        (self.root/'new.py').write_bytes(b'new\n')
        (self.root/'keep.txt').write_text('unrelated')
        sync.synchronize(self.root, self.target)
        self.assertEqual(self.target, self.git('rev-parse','HEAD').strip())
        self.assertEqual(b'final\n', (self.root/'a.py').read_bytes())
        self.assertEqual('unrelated', (self.root/'keep.txt').read_text())
        self.assertIn(old_stash, self.git('stash','list','--format=%H'))
        self.assertEqual(2,len(self.git('stash','list').splitlines()))
        sync.synchronize(self.root, self.target)
        self.assertEqual(2,len(self.git('stash','list').splitlines()))

    def test_unknown_edit_refuses_before_any_stash_or_head_change(self):
        (self.root/'stable.py').write_text('new personal change')
        with self.assertRaisesRegex(ValueError,'Unknown local edits'):
            sync.synchronize(self.root,self.target)
        self.assertEqual(self.base,self.git('rev-parse','HEAD').strip())
        self.assertEqual('',self.git('stash','list'))
        self.assertEqual('new personal change',(self.root/'stable.py').read_text())

    def test_check_only_does_not_stash_or_update(self):
        (self.root/'a.py').write_bytes(b'combined\n')
        sync.synchronize(self.root,self.target,True)
        self.assertEqual(self.base,self.git('rev-parse','HEAD').strip())
        self.assertEqual(b'combined\n',(self.root/'a.py').read_bytes())

    def test_staged_changes_refuse(self):
        (self.root/'a.py').write_bytes(b'combined\n'); self.git('add','a.py')
        with self.assertRaisesRegex(ValueError,'staged changes'):
            sync.synchronize(self.root,self.target)
        self.assertTrue(self.git('diff','--cached','--name-only').strip())


if __name__ == '__main__': unittest.main()
