import unittest
from . import economy as e, powers, power_components, effects
from .power_rules import declaration
from .copying import copy_data
from .resolution import Ordinary
from .multiply import resolve, validate
from u13_doctrine.test_odradek import prepared, next_planning, decision
from u13_doctrine.observation import observe
from u13_doctrine.facts import Facts
from u13_doctrine.lords.odradek import multiply_value, proposals
from u13_doctrine.coordination import context

class MultiplyTests(unittest.TestCase):
 def fixture(self):
  g,ids=prepared(points=4,guards=1,units=0);t=dict(entity_id=ids[0],lane='Castle')
  s=declaration(0,g.clock.round,'Multiply',t);return g,ids[0],s
 def fill(self,g,count):
  w=g._state['world'];cards=[r for r in w['entities']['entities'] if r['kind']=='card' and r['attributes'].get('role')!='guard'][:count]
  power_components.prepare(g,[dict(kind='fixture_guard',card_id=r['id'],player_id=0,lane='Castle',slot=i) for i,r in enumerate(cards)])
 def direct(self,g,s):
  n=g.clock.round+1;rec=dict(declaration=s,fire_hook='round_start_scheduled')
  b=Ordinary(g._state['world'],n,g._state['seed'],g._state['player_order'],rec['fire_hook'])
  return resolve(rec,g._state,n,b)
 def test_real_next_round_cost_copy_and_no_tear(self):
  g,key,s=self.fixture();w=g._state['world'];before=w['data']['neutral_tears'];r=e.entity(w,key);suit=r['attributes']['suit'];value=r['attributes']['value']
  r['attributes']['temporary_test_bonus']=99
  choice=dict(order={},powers=[s]);accepted=g.apply(dict(kind='submit',plans=[choice,dict(order={},powers=[])]))
  self.assertNotEqual(accepted['action'],'invalid');self.assertEqual(e.entity(g._state['world'],key)['owner'],1)
  from .full_match_inputs import next_operation
  locked=g.apply(next_operation(g));self.assertNotEqual(locked['action'],'invalid',locked)
  self.assertEqual(g._state['world']['players'][0]['resources']['reconfiguration'],1)
  from .full_match_inputs import next_operation
  for _ in range(1000):
   if g.clock.hook=='submission_lock' and g._state['submissions']==[None,None]:break
   result=g.apply(next_operation(g));self.assertNotEqual(result['action'],'invalid',result)
  else:self.fail('next round not reached')
  w=g._state['world'];own=[r for r in powers.guards(w) if r['owner']==0]
  self.assertEqual(len(own),3);self.assertEqual([r['attributes']['suit'] for r in own],[suit]*3)
  self.assertEqual([r['attributes']['value'] for r in own],[value]*3)
  self.assertTrue(all('temporary_test_bonus' not in r['attributes'] for r in own));self.assertEqual(w['data']['neutral_tears'],before)
  self.assertIn(key,e.zones(w)['discard']);self.assertTrue(e.cards_valid(w))
  self.assertEqual(len(set(r['id'] for r in own)),3)
  self.assertTrue(any(p['player_id']==0 and p['lane']=='Castle' and p['suit']==suit for p in w['data']['guard_work']['pairs']))
 def test_declaration_needs_two_slots(self):
  g,key,s=self.fixture();self.fill(g,2)
  self.assertEqual(validate(s,g._state['world'],'declaration'),'multiply_requires_two_slots')
  before=g.snapshot();result=g.apply(dict(kind='submit',plans=[dict(order={},powers=[s]),dict(order={},powers=[])]))
  self.assertEqual(result['action'],'invalid');self.assertEqual(g.snapshot(),before)
 def test_partial_capacity_and_full_capacity_at_resolution(self):
  for count in (0,1,2,3):
   g,key,s=self.fixture();self.fill(g,count)
   self.assertEqual(validate(s,g._state['world'],'firing'),'')
   events=self.direct(g,s);made=events[-1]['event']['data']['created_ids'];self.assertEqual(len(made),3-count)
   self.assertLessEqual(len([r for r in powers.guards(g._state['world']) if r['owner']==0]),3)
   self.assertIn(key,e.zones(g._state['world'])['discard']);self.assertTrue(e.cards_valid(g._state['world']))
 def test_missing_moved_or_converted_target_fizzles(self):
  for change in ('role','lane','owner'):
   g,key,s=self.fixture();next_plans=dict(order={},powers=[s]);result=g.apply(dict(kind='submit',plans=[next_plans,dict(order={},powers=[])]));self.assertNotEqual(result['action'],'invalid')
   from .full_match_inputs import next_operation
   locked=g.apply(next_operation(g));self.assertNotEqual(locked['action'],'invalid',locked)
   # The real pending-effect dispatcher must fizzle instead of creating copies.
   w=g._state['world'];r=e.entity(w,key)
   if change=='role':r['attributes']['role']='card';r['owner']=-1;e.zones(w)['discard'].append(key)
   elif change=='lane':r['attributes']['lane']='Lord'
   else:r['owner']=0
   effects.resolve_due(g._state,s['fire_round'],s['fire_hook'],powers.validate,powers.resolve)
   events=[row['event'] for row in g._state['events']['rows']]
   self.assertTrue(any(x['type']=='FIZZLE_INVALID_TARGET' and x['data']['power_id']=='Multiply' for x in events))
   self.assertFalse(any(x['type']=='MULTIPLY_RESOLVED' for x in events))
 def test_own_guard_cannot_be_targeted(self):
  g,key,s=self.fixture();e.entity(g._state['world'],key)['owner']=0
  self.assertEqual(validate(s,g._state['world'],'declaration'),'multiply_target_unavailable')
 def test_doctrine_values_pair_and_accounts_for_own_attack(self):
  g,key,s=self.fixture();f=Facts(observe(g,0));options=[p for p in proposals(f) if p.term=='Multiply'];self.assertTrue(options)
  full=multiply_value(f,s['target']);plan=dict(powers=[],order=dict(guard_moves=[dict(lane='Castle',slot=i) for i in (0,1,2)]))
  self.assertLess(multiply_value(f,s['target'],plan,dict(guard_losses=[])),full)
  self.assertEqual(multiply_value(f,s['target'],dict(order={}),dict(guard_losses=[key])),0)
 def test_doctrine_can_choose_multiply(self):
  g,key,s=self.fixture();d=decision(g)
  self.assertIn('Multiply',[p['power_id'] for p in d['plan']['powers']])

 def test_own_attack_lane_is_removed_from_actual_decision(self):
  from unittest.mock import patch
  from u13_doctrine.facts import Proposal
  from u13_doctrine.common import CommonSmartCore
  from u13_doctrine.observation import Preview
  for action,lane,should_cast in [('Hunt','Lord',True),('Siege','Castle',False)]:
   g,key,decl=self.fixture()
   def force(f,category,weights):
    if category=='combat':
     yield Proposal('combat','Pass',{},-1000,'fixture_pass')
     target=f.lord[1]['id'] if action=='Hunt' else f.castles(1)[0]['id']
     card=min(f.hand,key=lambda r:r['attributes']['value'])['id']
     yield Proposal('combat',action,dict(action=action,lane=lane,target_id=target,card_ids=[card]),1000,'fixture',(card,))
   with patch('u13_doctrine.common.ordinary',force),patch('u13_doctrine.common.Recipes.proposals',return_value=iter(())):
    d=CommonSmartCore().decide(observe(g,0),Preview(g,0))
   names=[p['power_id'] for p in d['plan']['powers']]
   self.assertEqual('Multiply' in names,should_cast,d['plan'])
 def test_all_suits_create_live_pairs(self):
  from .development import intact
  for suit in ('Wright','Vulture','Penitent','Butcher'):
   g,key,s=self.fixture();e.entity(g._state['world'],key)['attributes']['suit']=suit
   self.direct(g,s);w=g._state['world'];pair=w['data']['guard_work']['pairs'][-1]
   self.assertEqual(pair['suit'],suit);self.assertTrue(intact(w,pair))
   self.assertEqual(len(pair['ids']),2)
   self.assertEqual(len([p for p in w['data']['guard_work']['pairs'] if p['player_id']==0]),1)
   # The third copy is independent of the pair; losing it must not break the bond.
   third=next(r for r in powers.guards(w) if r['owner']==0 and r['id'] not in pair['ids'])
   third['attributes']['role']='card';self.assertTrue(intact(w,pair))

 def test_swapped_costs_and_three_point_admission(self):
  from .power_rules import RULES
  from u13_doctrine.observation import Preview
  self.assertEqual(RULES['Multiply']['cost'],dict(reconfiguration=3))
  self.assertEqual(RULES['AllegianceShift']['cost'],dict(reconfiguration=4))
  g,key,s=self.fixture()
  power_components.prepare(g,[dict(kind='fixture_resources',player_id=0,resources=dict(reconfiguration=3))])
  r=g.apply(dict(kind='submit',plans=[dict(order={},powers=[s]),dict(order={},powers=[])]))
  self.assertNotEqual(r['action'],'invalid',r)
  from .full_match_inputs import next_operation
  r=g.apply(next_operation(g));self.assertNotEqual(r['action'],'invalid',r)
  self.assertEqual(g._state['world']['players'][0]['resources']['reconfiguration'],0)
  g,key,s=self.fixture()
  power_components.prepare(g,[dict(kind='fixture_resources',player_id=0,resources=dict(reconfiguration=3))])
  shift=declaration(0,g.clock.round,'AllegianceShift',dict(lane='Lord',field_position=dict(x_fp=1200,y_fp=300)))
  before=g.snapshot();r=g.apply(dict(kind='submit',plans=[dict(order={},powers=[shift]),dict(order={},powers=[])]))
  self.assertEqual(r['action'],'invalid');self.assertEqual(g.snapshot(),before)
