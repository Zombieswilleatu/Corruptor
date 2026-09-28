import unittest
from .test_common import planning
from .test_lane_support import unit
from .observation import observe
from .facts import Facts
from .humbaba_tactics import cohorts,muster_score,survival_bonus
from .lords.humbaba import breath_value

class HumbabaTacticsTests(unittest.TestCase):
    def view(self):return observe(planning('Humbaba'),0)

    def test_observation_owns_progress_without_private_metadata(self):
        game=planning('Humbaba');w=game._state['world']
        w['data']['humbaba_muster_endurance']={'ours':dict(owner=0,points=23.5,rewarded=False,secret='hidden'),
                                             'theirs':dict(owner=1,points=24,rewarded=False)}
        v=observe(game,0)
        self.assertEqual({'ours':dict(owner=0,points=23.5,rewarded=False)},v['data']['humbaba_muster_endurance'])
        self.assertNotIn('humbaba_muster_endurance',observe(game,1)['data'])
        v['data']['humbaba_muster_endurance']['ours']['points']=0
        self.assertEqual(23.5,w['data']['humbaba_muster_endurance']['ours']['points'])

    def test_muster_prefers_blockable_contact_to_hopeless_melee(self):
        v=self.view()
        for i in range(3):
            unit(v,'arrow'+str(i),1,lane='Lord',x_fp=700,suit='Vulture',attack=1)
            unit(v,'burst'+str(i),1,lane='Castle',x_fp=700,attack=8)
        self.assertGreater(muster_score(Facts(v),'Lord'),muster_score(Facts(v),'Castle'))

    def test_far_stationary_bodies_do_not_count_as_immediate_contact(self):
        v=self.view();baseline=muster_score(Facts(v),'Castle')
        for i in range(10):unit(v,'far'+str(i),1,x_fp=2300,waiting=True)
        self.assertEqual(baseline,muster_score(Facts(v),'Castle'))

    def setup_cohort(self):
        v=self.view();v['data']['humbaba_muster_endurance']={'group':dict(owner=0,points=23,rewarded=False)}
        unit(v,'penitent',x_fp=1100,suit='Penitent',hp=2,max_hp=5,source_power_id='MusterTheFaithful',source_effect_id='group',muster_owner=0)
        unit(v,'foe',1,x_fp=1150)
        return v

    def test_breath_rewards_only_unearned_supported_cohort(self):
        v=self.setup_cohort();near=breath_value(Facts(v),'Castle')
        self.assertGreater(near['endurance_support'],0)
        v['data']['humbaba_muster_endurance']['group']['rewarded']=True
        paid=breath_value(Facts(v),'Castle')
        self.assertEqual(0,paid['endurance_support']);self.assertGreater(near['score'],paid['score'])

    def test_stolen_or_waiting_cohort_has_no_endurance_support(self):
        v=self.setup_cohort();r=next(r for r in v['board'] if r['id']=='penitent')
        r['attributes']['muster_owner']=1
        self.assertEqual([],cohorts(Facts(v)))
        r['attributes']['muster_owner']=0;r['attributes']['waiting']=True
        self.assertEqual([],cohorts(Facts(v)))

    def test_full_health_cohort_is_not_promised_healing(self):
        v=self.setup_cohort();next(r for r in v['board'] if r['id']=='penitent')['attributes']['hp']=5
        self.assertEqual(0,breath_value(Facts(v),'Castle')['endurance_support'])

    def test_speed_can_add_gate_arrival_across_both_marching_phases(self):
        v=self.view();unit(v,'fast',x_fp=0,step_fp=4)
        # Late phase 200 ticks plus next round's 100 + 200 ticks:
        # ordinary distance 2000, boosted 2500, gate at 2400.
        self.assertEqual(1,breath_value(Facts(v),'Castle')['incremental_arrivals'])

    def test_survival_bonus_ignores_other_lords(self):
        f=Facts(observe(planning('Gremory','Orias'),0))
        self.assertEqual(0,survival_bonus(f,f.world,dict(order={},powers=[])))

if __name__=='__main__':unittest.main()
