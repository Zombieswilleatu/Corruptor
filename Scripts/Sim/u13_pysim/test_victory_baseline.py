"""Victory boundaries for the shared 15-Soul / 7-Tear baseline."""
import re
import unittest
from types import SimpleNamespace
from pathlib import Path
from . import lifecycle, split_ward


def world(souls=(0, 0), tears=(0, 0), living=(True, True), veil=0, tempo=True):
    return dict(players=[dict(lord_entity_id=str(pid), resources=dict(
        souls=souls[pid], personal_tears=tears[pid])) for pid in (0, 1)],
        entities=dict(entities=[dict(id=str(pid), attributes=dict(alive=living[pid]))
                                for pid in (0, 1)]),
        data=dict(neutral_tears=veil-sum(tears),
                  tempo_experiment=split_ward.TEMPO if tempo else '', victory=dict(round_limit=20)))


class VictoryBaselineTests(unittest.TestCase):
    def test_native_and_python_baseline_agree(self):
        native = (Path(__file__).resolve().parents[1]/'U13Victory.gd').read_text()
        for name, expected in [('RITUAL_SOULS', 15), ('DOMINION_TEARS', 7), ('DOMINION_VEIL', 12), ('ROUND_LIMIT', 20)]:
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

    def test_tiebreak_chain_and_reward_gate(self):
        w=world(souls=(14,14),tears=(1,2),veil=10)
        self.assertEqual(1,lifecycle.evaluate(w,20)['winner'])
        w['players'][0]['resources']['personal_tears']=2
        castle=dict(id='c',kind='castle',owner=1,attributes=dict(status='standing',construction_state='active',integrity=1))
        w['entities']['entities'].append(castle)
        self.assertEqual(1,lifecycle.evaluate(w,20)['winner'])
        castle['attributes']['construction_state']='building'
        self.assertEqual(0,lifecycle.evaluate(w,20)['winner'])
        w['entities']['entities'][0]['attributes']['alive']=False
        self.assertEqual(1,lifecycle.evaluate(w,20)['winner'])
        w['entities']['entities'][1]['attributes']['alive']=False
        self.assertEqual(0,lifecycle.evaluate(w,20)['winner'])
        self.assertEqual(17,split_ward.soul_start_round(w))
        event=dict(event=dict(type='HUNT_RESOLVED',data=dict(banished=True,target_id='lord:1')))
        before=w['players'][0]['resources']['souls']
        split_ward.reward_breakthrough(SimpleNamespace(w=w,number=16),0,[event])
        self.assertEqual(before,w['players'][0]['resources']['souls'])
        split_ward.reward_breakthrough(SimpleNamespace(w=w,number=17),0,[event])
        self.assertEqual(before+1,w['players'][0]['resources']['souls'])
        w['data']['victory'].pop('round_limit')
        self.assertEqual(20,split_ward.soul_start_round(w))

    def test_legacy_save_deadline(self):
        saved=world(souls=(14,13))
        saved['data']['victory'].pop('round_limit')
        self.assertEqual(-1,lifecycle.evaluate(saved,24)['winner'])
        self.assertEqual('RoundLimit',lifecycle.evaluate(saved,25)['win_by'])

    def test_simultaneous_ritual_checkdown_and_reversed_seats(self):
        for preferred in (0, 1):
            other=1-preferred
            w=world(souls=(15,15), tears=(1,1))
            w['players'][preferred]['resources']['souls']=16
            w['players'][other]['resources']['personal_tears']=7
            self.assertEqual(dict(winner=preferred,win_by='Ritual'),lifecycle.evaluate(w,20))
            w['players'][other]['resources']['souls']=16
            self.assertEqual(other,lifecycle.evaluate(w,20)['winner'])
            w['players'][preferred]['resources']['personal_tears']=7
            castle=dict(kind='castle',owner=preferred,attributes=dict(status='standing',construction_state='active',integrity=1))
            w['entities']['entities'].append(castle)
            self.assertEqual(preferred,lifecycle.evaluate(w,20)['winner'])
            for change in [dict(status='ruined',integrity=0),dict(construction_state='building'),dict(integrity=0)]:
                before=dict(castle['attributes']);castle['attributes'].update(change)
                self.assertEqual(0,lifecycle.evaluate(w,20)['winner'])
                castle['attributes']=before
            w['entities']['entities'].pop()
            self.assertEqual(0,lifecycle.evaluate(w,20)['winner'])

    def test_only_eligible_lord_competes_for_ritual(self):
        self.assertEqual(dict(winner=1,win_by='Ritual'),lifecycle.evaluate(world(souls=(99,15),tears=(9,0),living=(False,True)),20))
        self.assertEqual(dict(winner=0,win_by='Ritual'),lifecycle.evaluate(world(souls=(15,99),tears=(0,9),living=(True,False)),20))

    def test_ritual_checkdown_also_applies_without_modern_deadline_field(self):
        w=world(souls=(15,15),tears=(0,1));w['data']['victory'].pop('round_limit')
        self.assertEqual(dict(winner=1,win_by='Ritual'),lifecycle.evaluate(w,1))
        self.assertEqual(0,lifecycle.deadline_winner(w))  # Legacy deadline remains separate.

    def test_precedence_and_round_limit(self):
        self.assertEqual(dict(winner=1,win_by='Ritual'), lifecycle.evaluate(
            world(souls=(15,16),tears=(0,7),veil=12),25))
        self.assertEqual(dict(winner=1,win_by='Dominion'), lifecycle.evaluate(
            world(souls=(14,0),tears=(0,7),veil=12),25))
        self.assertEqual(dict(winner=-1,win_by=''), lifecycle.evaluate(world(souls=(14,13)),19))
        self.assertEqual(dict(winner=0,win_by='RoundLimit'), lifecycle.evaluate(world(souls=(14,14)),20))
        self.assertEqual(dict(winner=1,win_by='FinalCollapse'), lifecycle.evaluate(
            world(souls=(0,1),tears=(7,0),veil=26,tempo=False)))
        self.assertEqual(dict(winner=1,win_by='Ritual'), lifecycle.evaluate(
            world(souls=(15,16),veil=26,tempo=False)))


if __name__ == '__main__': unittest.main()
