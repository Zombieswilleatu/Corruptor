"""Victory boundaries for the shared 15-Soul / 7-Tear baseline."""
import re
import unittest
from pathlib import Path
from . import lifecycle, split_ward


def world(souls=(0, 0), tears=(0, 0), living=(True, True), veil=0, tempo=True):
    return dict(players=[dict(lord_entity_id=str(pid), resources=dict(
        souls=souls[pid], personal_tears=tears[pid])) for pid in (0, 1)],
        entities=dict(entities=[dict(id=str(pid), attributes=dict(alive=living[pid]))
                                for pid in (0, 1)]),
        data=dict(neutral_tears=veil-sum(tears),
                  tempo_experiment=split_ward.TEMPO if tempo else ''))


class VictoryBaselineTests(unittest.TestCase):
    def test_native_and_python_baseline_agree(self):
        native = (Path(__file__).resolve().parents[1]/'U13Victory.gd').read_text()
        for name, expected in [('RITUAL_SOULS', 15), ('DOMINION_TEARS', 7), ('DOMINION_VEIL', 12)]:
            self.assertEqual(expected, getattr(lifecycle, name))
            self.assertEqual(expected, int(re.search(r'const '+name+r': int = (\d+)', native)[1]))

    def test_ritual_boundary_and_living_lord_for_both_seats(self):
        for pid in (0, 1):
            for souls in (12, 13, 14, 15, 16):
                for alive in (True, False):
                    with self.subTest(pid=pid, souls=souls, alive=alive):
                        amounts=[0, 0]; amounts[pid]=souls
                        living=[True, True]; living[pid]=alive
                        result=lifecycle.evaluate(world(souls=amounts, living=living), 1)
                        self.assertEqual(dict(winner=pid, win_by='Ritual') if alive and souls>=15
                                         else dict(winner=-1, win_by=''), result)

    def test_dominion_threshold_veil_and_ties_for_both_seats(self):
        for pid in (0, 1):
            for own, other, veil, wins in [(5,0,12,False),(6,0,12,False),
                    (7,0,11,False),(7,0,12,True),(7,7,14,False),(8,7,15,True)]:
                with self.subTest(pid=pid, own=own, other=other, veil=veil):
                    tears=[other,other]; tears[pid]=own
                    result=lifecycle.evaluate(world(tears=tears, veil=veil, living=(False,False)), 1)
                    self.assertEqual(dict(winner=pid, win_by='Dominion') if wins
                                     else dict(winner=-1, win_by=''), result)

    def test_precedence_and_round_limit(self):
        self.assertEqual(dict(winner=0,win_by='Ritual'), lifecycle.evaluate(
            world(souls=(15,16),tears=(0,7),veil=12),25))
        self.assertEqual(dict(winner=1,win_by='Dominion'), lifecycle.evaluate(
            world(souls=(14,0),tears=(0,7),veil=12),25))
        self.assertEqual(dict(winner=-1,win_by=''), lifecycle.evaluate(world(souls=(14,13)),24))
        self.assertEqual(dict(winner=0,win_by='RoundLimit'), lifecycle.evaluate(world(souls=(14,14)),25))
        self.assertEqual(dict(winner=1,win_by='FinalCollapse'), lifecycle.evaluate(
            world(souls=(0,1),tears=(7,0),veil=26,tempo=False)))
        self.assertEqual(dict(winner=0,win_by='Ritual'), lifecycle.evaluate(
            world(souls=(15,16),veil=26,tempo=False)))


if __name__ == '__main__': unittest.main()
