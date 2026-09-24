import unittest
from u13_doctrine.test_common import planning
from u13_pysim.battle import Battle
class Tears(unittest.TestCase):
 def setUp(self):
  self.w=planning('Gremory')._state['world'];self.b=Battle(self.w,1,'test',[0,1],'marching');self.start=self.w['players'][0]['resources']['personal_tears'];self.neutral=self.w['data']['neutral_tears'];self.serial=0
 def kill(self,key='a',predator=True,victim=1,cause='combat'):
  self.serial+=1;a=dict(suit='Vulture')
  if predator:a['source_power_id']='PredatorOfRuin'
  return self.b.react(dict(type='MARCHER_DEFEATED',data=dict(cause=cause,hook='marching',event_id=str(self.serial),round=self.b.number,attacker=dict(id=key,owner=0,attributes=a),victim=dict(owner=victim))))
 def tears(self):return self.w['players'][0]['resources']['personal_tears']-self.start
 def test_two_individual_kills_once_lifetime(self):
  self.kill();self.assertEqual(0,self.tears());self.b.number=2;self.kill();self.assertEqual(1,self.tears());self.b.number=3
  for _ in range(5):self.kill()
  self.assertEqual(1,self.tears());self.assertEqual(self.neutral,self.w['data']['neutral_tears'])
 def test_pair_does_not_pool_and_cap_defers_to_later_kill(self):
  self.kill('a');self.kill('b');self.assertEqual(0,self.tears());self.kill('a');self.kill('b');self.assertEqual(1,self.tears())
  self.b.number=2;self.assertEqual(1,self.tears());self.kill('b');self.assertEqual(2,self.tears())
 def test_regular_kill_draw_separate_from_tear(self):
  events=self.kill('normal',False);self.assertEqual(1,sum(e['event']['type']=='PICKING_THE_BONES' for e in events));self.kill();self.kill();self.assertEqual(1,self.tears())
 def test_invalid_kills_do_not_count(self):
  self.kill(cause='hazard');self.kill(victim=0);self.kill();self.assertEqual(0,self.tears());self.kill();self.assertEqual(1,self.tears())
 def test_banished_does_not_count(self):
  lord=next(e for e in self.w['entities']['entities'] if e['kind']=='lord' and e['owner']==0);lord['attributes']['alive']=False
  self.kill();self.kill();self.assertEqual(0,self.tears());lord['attributes']['alive']=True;self.kill();self.assertEqual(0,self.tears());self.kill();self.assertEqual(1,self.tears())
if __name__=='__main__':unittest.main()
