"""Muster cohort accounting, eligibility, lifetime limit and retired low-HP passive."""
import unittest
from .power_match import PowerMatch
from .full_match_inputs import load
from .lifecycle import RoundRules
from . import muster_endurance as m, economy as e

class EnduranceTests(unittest.TestCase):
    def setUp(self):
        setup=dict(load()['cases'][0]['setup'],lords=['Humbaba','Humbaba'])
        self.w=PowerMatch(setup)._state['world']
        self.start=self.w['players'][0]['resources']['personal_tears']
        self.neutral=self.w['data']['neutral_tears']
    def unit(self,key='a',owner=0,group='group'):
        return dict(id=key,kind='marcher',owner=owner,attributes=dict(suit='Penitent',hp=5,
            source_power_id='MusterTheFaithful',source_effect_id=group,muster_owner=0))
    def hit(self,unit=None,before=5,after=0,block=False,enemy=1,number=1):
        return m.credit(self.w,unit or self.unit(),dict(owner=enemy),before,after,block,number,1)
    def gained(self):return self.w['players'][0]['resources']['personal_tears']-self.start
    def test_pool_fractional_damage_and_blocks(self):
        for key in ('a','b','c'):self.hit(self.unit(key),before=7.5,after=0)
        self.hit(before=5,after=5,block=True);self.hit(before=5,after=5,block=True)
        self.assertEqual(0,self.gained())
        events=self.hit(before=5,after=4.5,number=2)
        self.assertEqual(1,self.gained());self.assertEqual(self.neutral,self.w['data']['neutral_tears'])
        self.assertEqual(1,sum(x['event']['type']=='MUSTER_ENDURANCE_REWARDED' for x in events))
    def test_once_per_group_across_rounds(self):
        self.hit(before=25,after=0)
        for n in (2,3):self.hit(before=25,after=0,number=n)
        self.assertEqual(1,self.gained())
    def test_separate_casts_can_each_pay_same_round(self):
        for group in ('one','two'):self.hit(self.unit(group=group),before=25)
        self.assertEqual(2,self.gained())
    def test_blocks_only_and_no_damage_credit_for_overkill(self):
        self.hit(before=2,after=0)
        self.assertEqual(2,self.w['data'][m.KEY]['group']['points'])
        for _ in range(23):self.hit(before=5,after=5,block=True)
        self.assertEqual(1,self.gained())
    def test_friendly_dead_regular_and_stolen_excluded(self):
        self.hit(enemy=0);self.hit(before=0)
        unit=self.unit();unit['attributes'].pop('source_power_id');self.hit(unit)
        self.hit(self.unit(owner=1),enemy=0)
        self.assertNotIn(m.KEY,self.w['data'])
    def test_banishment_requires_later_contribution(self):
        lord=e.entity(self.w,self.w['players'][0]['lord_entity_id']);lord['attributes']['alive']=False
        self.hit(before=25);self.assertEqual(0,self.gained())
        lord['attributes']['alive']=True;self.assertEqual(0,self.gained())
        self.hit(before=5,after=5);self.assertEqual(0,self.gained())
        self.hit(before=5,after=5,block=True);self.assertEqual(1,self.gained())
    def test_snapshot_preserves_progress(self):
        self.hit(before=20)
        from .copying import copy_data
        self.w=copy_data(self.w);self.hit(before=5);self.assertEqual(1,self.gained())
    def test_old_low_hp_reward_removed(self):
        self.w['entities']['entities'].append(self.unit())
        self.w['entities']['entities'][-1]['attributes']['hp']=1
        events=RoundRules(self.w,1,'test',[0,1],'end_marching_checks').run({})
        self.assertFalse(events);self.assertEqual(self.neutral,self.w['data']['neutral_tears'])
