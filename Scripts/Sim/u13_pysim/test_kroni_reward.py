"""Enemy-only Ravenous threshold, one reward per use, and real bite counting."""
import unittest
from . import kroni_actors
from .lord_hooks import LordRoundRules
from .power_match import PowerMatch
from .full_match_inputs import load


class KroniRewardTests(unittest.TestCase):
    def test_enemy_threshold_and_once_per_use(self):
        for enemy, total, paid, expected in ((10,30,False,0),(11,11,False,1),(22,30,False,1),(11,11,True,0)):
            with self.subTest(enemy=enemy,total=total,paid=paid):
                setup=dict(load()['cases'][0]['setup'],lords=['Kroni','Odradek'])
                game=PowerMatch(setup); w=game._state['world']
                actor=kroni_actors.create('reward',0,1,0)
                actor.update(enemy_consumed=enemy,consumed=total,rewarded=paid,active=False)
                w['data']['kroni_actors']=[actor]
                souls=w['players'][0]['resources']['souls'];neutral=w['data']['neutral_tears']
                rules=LordRoundRules(w,1,'threshold',[0,1],'marching',[])
                events=rules.extra()
                self.assertEqual(souls+expected,w['players'][0]['resources']['souls'])
                self.assertEqual(neutral+expected,w['data']['neutral_tears'])
                rewards=[r['event']['data'] for r in events if r['event']['type']=='RAVENOUS_REWARDED']
                self.assertEqual(expected,len(rewards))
                if rewards:self.assertEqual(enemy,rewards[0]['enemy_consumed'])
                rules.extra()
                self.assertEqual(souls+expected,w['players'][0]['resources']['souls'])

    def test_real_bites_count_enemy_ownership_only(self):
        class Buffer:
            def __init__(self,owner):
                self.units=[dict(id='meal',owner=owner,attributes=dict(x_fp=16,y_fp=300,lane='Lord',step_fp=0))]
            def rows(self):return self.units[:]
            def retire_id(self,key):self.units=[]
        for pid in (0,1):
            for owner in (0,1):
                actor=kroni_actors.create('bite',pid,1,0)
                actor.update(x_fp=0,vx_fp=16,vy_fp=1,y_fp=300)
                events=kroni_actors.step([actor],Buffer(owner),1,0,False)
                self.assertEqual(1,actor['consumed'])
                self.assertEqual(int(owner!=pid),actor['enemy_consumed'])
                self.assertEqual(1,sum(r['event']['type']=='MARCHER_DEVOURED' for r in events))

    def test_breach_and_legacy_unknown_kills_do_not_pay(self):
        for breach in (False,True):
            game=PowerMatch(dict(load()['cases'][0]['setup'],lords=['Kroni','Odradek']))
            w=game._state['world'];actor=kroni_actors.create('old',-1 if breach else 0,1,0,breach)
            actor['consumed']=30
            if breach:actor['enemy_consumed']=30
            else:actor.pop('enemy_consumed')
            w['data']['kroni_actors']=[actor]
            events=LordRoundRules(w,1,'threshold',[0,1],'marching',[]).extra()
            self.assertFalse(any(r['event']['type']=='RAVENOUS_REWARDED' for r in events))

if __name__=='__main__':unittest.main()
