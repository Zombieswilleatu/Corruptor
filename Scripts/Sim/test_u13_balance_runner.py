import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import run_u13_lord_balance as runner


class FrozenResumeTests(unittest.TestCase):
    def test_resume_preserves_legacy_runner_and_forwards_supported_option(self):
        for supports_recycling in (False, True):
            with self.subTest(supports_recycling=supports_recycling), tempfile.TemporaryDirectory() as directory:
                report = Path(directory)
                script = report/'source/Scripts/Sim/run_u13_lord_balance.py'
                script.parent.mkdir(parents=True)
                script.write_text('# --worker-batch-size' if supports_recycling else '# original runner')
                (report/'balance-config.json').write_text(json.dumps({'repeats': 10}))
                args = ['runner', '--resume', str(report), '--workers', '3', '--worker-batch-size', '6']
                with patch('sys.argv', args), patch.object(runner, 'verify_frozen') as verify, \
                     patch.object(runner, 'package'), patch.object(runner.subprocess, 'call', return_value=0) as call:
                    self.assertEqual(0, runner.main())
                verify.assert_called_once_with(report.resolve())
                command = call.call_args.args[0]
                self.assertEqual(supports_recycling, '--worker-batch-size' in command)
                self.assertIn(str(script), command)
                self.assertEqual('10', command[command.index('--repeats')+1])
                if supports_recycling:
                    self.assertEqual('6', command[command.index('--worker-batch-size')+1])


if __name__ == '__main__': unittest.main()
