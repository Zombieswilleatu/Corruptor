"""Prove the Web-only comparison changes only the focal policy assignment."""
from dataclasses import asdict
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from .common import VERSION, Weights
from .comparison import freeze_baseline
from .web_comparison import BASELINE, OPPONENT, WebPolicy, cases, snare_identity

class WebComparisonTests(unittest.TestCase):
    def test_setups_and_three_policy_routing(self):
        specs=cases()
        self.assertEqual(16,len(specs))
        self.assertEqual(4,len({s['setup']['seed'] for s in specs}))
        self.assertEqual(8,len({s['pair_id'] for s in specs}))
        for old,new in zip(specs[::2],specs[1::2]):
            self.assertEqual(old['setup'],new['setup'])
            self.assertEqual(old['focal_seat'],new['focal_seat'])
        root=Path(__file__).resolve().parents[3]
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)
            freeze_baseline(root,BASELINE,p/'baseline')
            freeze_baseline(root,OPPONENT,p/'opponent')
            self.assertEqual(snare_identity(p/'baseline/orias_tactics.py'),snare_identity(root/'Scripts/Sim/u13_doctrine/orias_tactics.py'))
            for spec in specs[:4]:
                policy=WebPolicy(p/'baseline',spec,asdict(Weights()))
                focal=spec['focal_seat'];other=1-focal
                self.assertIn('V15_ROUT',policy.policy_ids[other])
                self.assertEqual(VERSION,policy.policy_ids[focal]) if spec['variant']=='new' else self.assertIn('V16_ORIAS',policy.policy_ids[focal])
                for seat in (0,1):
                    with patch.object(policy.policies[seat],'decide',return_value={'policy':policy.policy_ids[seat]}) as decide:
                        policy.decide({'player_id':seat},None);decide.assert_called_once()
                    with patch.object(policy.policies[seat],'choose_card',return_value={'seat':seat}) as choose:
                        self.assertEqual({'seat':seat},policy.choose_card({'player_id':seat},'slaver'));choose.assert_called_once()

if __name__=='__main__':unittest.main()
