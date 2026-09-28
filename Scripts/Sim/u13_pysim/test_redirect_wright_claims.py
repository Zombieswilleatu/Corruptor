import unittest
from . import power_components, field_fortifications, economy as e
from .power_rules import declaration
from .full_match_inputs import next_operation
from u13_doctrine.test_odradek import prepared

class RedirectWrightClaimsTests(unittest.TestCase):
 def test_lane_change_releases_claim_without_resetting_build_history_or_repair_cooldown(self):
  for built in (False,True):
   g,_=prepared(points=1,guards=0,units=0)
   changes=[]
   for i,lane in enumerate(('Lord','Castle')):
    a=dict(suit='Wright',x_fp=900,y_fp=200,wright_site=0,wright_owner=0,wright_progress=5,wright_repair_round=1,wright_repair_next_tick=250)
    if built and lane=='Castle':a.update(wright_built=True,wright_guard_until=300,wright_progress=32)
    changes.append(dict(kind='fixture_marcher',player_id=0,lane=lane,origin='redirect-claims',ordinal=i,attributes=a))
   power_components.prepare(g,changes)
   self.assertTrue(field_fortifications.valid(g._state['world']))
   s=declaration(0,g.clock.round,'Redirect',dict(lane='Castle',field_position=dict(x_fp=900,y_fp=200)))
   self.assertNotEqual('invalid',g.apply(dict(kind='submit',plans=[dict(order={},powers=[s]),dict(order={},powers=[])]))['action'])
   for _ in range(30):
    result=g.apply(next_operation(g));self.assertNotEqual('invalid',result['action'],result)
    if g.clock.hook=='post_resolution_allegiance':break
   else:self.fail('Redirect not reached')
   w=g._state['world'];moved=next(r for r in w['entities']['entities'] if r.get('origin')=='redirect-claims' and r['ordinal']==1)
   a=moved['attributes'];self.assertEqual(a['lane'],'Lord');self.assertTrue(field_fortifications.valid(w))
   self.assertEqual((1,250),(a['wright_repair_round'],a['wright_repair_next_tick']))
   if built:self.assertTrue(a['wright_built'] and a['wright_released'])
   else:self.assertNotIn('wright_site',a)

if __name__=='__main__':unittest.main()
