import unittest
from .facts import Facts,valak_hunt_bonus
from .common import ordinary,Weights
from .observation import observe
from .test_common import planning
class ValakPressureTests(unittest.TestCase):
 def test_no_empty_attack_or_other_lord_bonus(self):
  empty=dict(guards=0,damage=0,banished=False,essence_spent=0)
  for essence in (0,2,5):self.assertEqual(valak_hunt_bonus(dict(lord_id='Valak',alive=True),essence,empty),0)
  for lord,alive in [('Kroni',True),('Valak',False)]:
   self.assertEqual(valak_hunt_bonus(dict(lord_id=lord,alive=alive),5,dict(empty,essence_spent=5,banished=True)),0)
 def test_drain_and_vulnerability_windows(self):
  lord=dict(lord_id='Valak',alive=True);progress=dict(guards=1,damage=0,banished=False,essence_spent=0)
  self.assertGreater(valak_hunt_bonus(lord,0,progress),valak_hunt_bonus(lord,5,progress))
  self.assertGreater(valak_hunt_bonus(lord,5,dict(progress,guards=0,essence_spent=3)),0)
  self.assertLessEqual(valak_hunt_bonus(lord,5,dict(progress,banished=True,essence_spent=5)),40)
 def test_absorption_and_cheap_candidate(self):
  v=observe(planning('Kalligan','Valak'),0);v['data']['guard_work']['pairs']=[]
  v['board']=[r for r in v['board'] if r['kind']!='marcher'];v['players'][1]['resources']['life_essence']=5
  f=Facts(v);cards=sorted(f.hand,key=lambda r:(-f.strength([r['id']],'Hunt'),r['id']))
  target=f.lord[1]['id'];ids=[cards[0]['id']];forecast=f.attack('Hunt',target,ids)
  from u13_pysim import split_ward
  self.assertEqual(forecast['essence_spent'],min(5,f.strength(ids,'Hunt')+split_ward.attack_bonus(f.world)))
  ps=list(ordinary(f,'combat',Weights()))
  self.assertTrue(any(p.term=='Hunt' and len(p.cards)<=2 and f.attack('Hunt',target,p.cards)['essence_spent']>=2 for p in ps))
  for p in ps:
   if p.term=='Siege':self.assertEqual(f.attack('Siege',p.payload['target_id'],p.cards)['valak_pressure_bonus'],0)
