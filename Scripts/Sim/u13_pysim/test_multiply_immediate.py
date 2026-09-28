import unittest
from . import economy as e, powers
from .power_rules import declaration, RULES
from .full_match_inputs import next_operation
from .copying import copy_data
from u13_doctrine.test_odradek import prepared, horizon
from u13_doctrine.observation import observe, Preview
from u13_doctrine.facts import Facts
from u13_doctrine.defensive_plans import development, exposure
from u13_doctrine.lords.odradek import multiply_value
from u13_doctrine.common import CommonSmartCore

class ImmediateMultiplyTests(unittest.TestCase):
 def advance_development(self,g,plan):
  self.assertNotEqual('invalid',g.apply(dict(kind='submit',plans=[plan,dict(order={},powers=[])]))['action'])
  for _ in range(10):
   result=g.apply(next_operation(g));self.assertNotEqual('invalid',result['action'],result)
   if g.clock.hook=='post_repair_artillery':return
  self.fail('development not reached')

 def test_same_round_before_combat_with_three_copies_cost_and_one_pair(self):
  g,ids=prepared(points=3,guards=1,units=0);n=g.clock.round
  s=declaration(0,n,'Multiply',dict(entity_id=ids[0],lane='Castle'))
  self.assertEqual((n,'development'),(s['fire_round'],s['fire_hook']))
  self.advance_development(g,dict(powers=[s],order={}))
  w=g._state['world'];copies=[r for r in powers.guards(w) if r['owner']==0]
  self.assertEqual(3,len(copies));self.assertEqual(0,w['players'][0]['resources']['reconfiguration'])
  self.assertIn(ids[0],e.zones(w)['discard']);self.assertTrue(e.cards_valid(w))
  self.assertEqual(1,len([p for p in w['data']['guard_work']['pairs'] if p['player_id']==0 and p['active']]))
  event=next(r['event'] for r in g._state['events']['rows'] if r['event']['type']=='MULTIPLY_RESOLVED')
  self.assertEqual((n,'development'),(event['data']['round'],event['data']['hook']))
  self.assertEqual(RULES['AllegianceShift']['cost'],dict(reconfiguration=4))

 def test_sealed_deployments_do_not_overlap_and_forecast_matches_real_work_and_defense(self):
  for suit in ('Wright','Penitent','Vulture','Butcher'):
   for count in (0,1,2,3):
    with self.subTest(suit=suit,count=count):
     g,ids=prepared(points=3,guards=1,units=0);e.entity(g._state['world'],ids[0])['attributes']['suit']=suit
     f=Facts(observe(g,0));castle=next(r for r in f.castles(0) if r['attributes']['castle_type']=='SiegeEngine')
     s=declaration(0,g.clock.round,'Multiply',dict(entity_id=ids[0],lane='Castle'))
     moves=[dict(card_id=r['id'],lane='Castle',slot=i) for i,r in enumerate(f.hand[:count])]
     p=dict(powers=[s],order=dict(guard_moves=moves,castle_action=dict(action='Work',target_id=castle['id'],card_ids=[],use_repair_token=False)))
     before=g.snapshot();projected,details=development(f,p);self.assertEqual(before,g.snapshot())
     self.advance_development(g,p);w=g._state['world'];guards=[r for r in powers.guards(w) if r['owner']==0]
     self.assertEqual(3,len(guards));self.assertEqual(3,len({r['attributes']['slot'] for r in guards}));self.assertTrue(e.cards_valid(w))
     made=next(r['event']['data']['created_ids'] for r in g._state['events']['rows'] if r['event']['type']=='MULTIPLY_RESOLVED')
     self.assertEqual(3-count,len(made))
     self.assertEqual(e.entity(w,castle['id'])['attributes']['integrity'],e.entity(projected,castle['id'])['attributes']['integrity'])
     public=copy_data(w);public['entities']['entities']=[r for r in public['entities']['entities'] if r['kind']!='card' or r['attributes'].get('role')=='guard']
     for pressure in (9,15,21):self.assertEqual(exposure(f,public,p,'Castle',pressure),exposure(f,projected,p,'Castle',pressure))

 def test_no_future_credit_for_the_guard_destroyed_by_current_multiply(self):
  g,ids=prepared(points=4,guards=1,units=0);f=Facts(observe(g,0));t=dict(entity_id=ids[0],lane='Castle')
  s=declaration(0,g.clock.round,'Multiply',t);p=dict(powers=[s],order={})
  self.assertEqual(0,horizon(observe(g,0),p)['score'])
  pair=dict(Penitent=15,Vulture=16,Wright=8,Butcher=9)[f.by_id[ids[0]]['attributes']['suit']]
  self.assertEqual(12+15*3+pair,multiply_value(f,t))

 def test_planning_is_pure_deterministic_and_bounded(self):
  g,_=prepared(points=3,guards=1,units=0);v=observe(g,0);before=g.snapshot();bot=CommonSmartCore()
  one=bot.decide(v,Preview(g,0));shuffled=copy_data(v);shuffled['board'].reverse();shuffled['hand'].reverse()
  self.assertEqual(one,bot.decide(shuffled,Preview(g,0)));self.assertEqual(before,g.snapshot());self.assertFalse(one['rejected_previews'])
  self.assertLessEqual(one['budget']['used']['complete_plans'],32);self.assertLessEqual(one['budget']['used']['previews'],8)

if __name__=='__main__':unittest.main()
