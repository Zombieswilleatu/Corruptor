from pathlib import Path
import sys,json
R=Path(__file__).resolve().parent;sys.path.insert(0,str(R))
from u13_doctrine.test_odradek import prepared
from u13_doctrine.facts import Facts
from u13_doctrine.observation import observe
from u13_pysim import economy as e,power_components
from u13_pysim.power_rules import declaration
from u13_pysim.full_match_inputs import next_operation
from u13_pysim.codec import pack,CODEC
cases=[]
for suit in ('Wright','Penitent','Vulture','Butcher'):
 for count in range(4):
  g,ids=prepared(points=3,guards=1,units=0)
  power_components.prepare(g,[dict(kind='fixture_patch',entity_id=ids[0],attributes=dict(suit=suit))])
  f=Facts(observe(g,0));castle=next(r for r in f.castles(0) if r['attributes']['castle_type']=='SiegeEngine')
  plan=dict(powers=[declaration(0,g.clock.round,'Multiply',dict(entity_id=ids[0],lane='Castle'))],order=dict(guard_moves=[dict(card_id=r['id'],lane='Castle',slot=i) for i,r in enumerate(f.hand[:count])],castle_action=dict(action='Work',target_id=castle['id'],card_ids=[],use_repair_token=False)))
  case=dict(name=f'{suit}_reserved_{count}',initial=g.snapshot(),steps=[])
  op=dict(kind='submit',plans=[plan,dict(order={},powers=[])])
  while True:
   result=g.apply(op);assert result['action']!='invalid',result
   case['steps'].append(dict(operation=op,result=result,state=g.snapshot()))
   if g.clock.hook=='post_repair_artillery':break
   op=next_operation(g)
  cases.append(case)
for built in (False,True):
 g,_=prepared(points=1,guards=0,units=0);changes=[]
 for index,lane in enumerate(('Lord','Castle')):
  attrs=dict(suit='Wright',x_fp=900,y_fp=200,wright_site=0,wright_owner=0,wright_progress=5,wright_repair_round=1,wright_repair_next_tick=250)
  if built and lane=='Castle':attrs.update(wright_built=True,wright_guard_until=300,wright_progress=32)
  changes.append(dict(kind='fixture_marcher',player_id=0,lane=lane,origin='redirect-claims',ordinal=index,attributes=attrs))
 power_components.prepare(g,changes)
 case=dict(name='Redirect_Wright_built_'+str(built),initial=g.snapshot(),steps=[])
 op=dict(kind='submit',plans=[dict(order={},powers=[declaration(0,g.clock.round,'Redirect',dict(lane='Castle',field_position=dict(x_fp=900,y_fp=200)))]),dict(order={},powers=[])])
 while True:
  result=g.apply(op);assert result['action']!='invalid',result
  case['steps'].append(dict(operation=op,result=result,state=g.snapshot()))
  if g.clock.hook=='post_resolution_allegiance':break
  op=next_operation(g)
 cases.append(case)
g,ids=prepared(points=3,guards=1,units=0)
g.apply(dict(kind='submit',plans=[dict(order={},powers=[declaration(0,g.clock.round,'Multiply',dict(entity_id=ids[0],lane='Castle'))]),dict(order={},powers=[])]))
while g.clock.hook!='development':g.apply(next_operation(g))
power_components.prepare(g,[dict(kind='fixture_patch',entity_id=ids[0],attributes=dict(lane='Lord'))],refresh=False)
case=dict(name='Multiply_target_moved_before_firing',initial=g.snapshot(),steps=[])
op=next_operation(g);result=g.apply(op);assert result['action']!='invalid',result
case['steps'].append(dict(operation=op,result=result,state=g.snapshot()));cases.append(case)
dest=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__import__('tempfile').gettempdir())/'corruptor-multiply-native-parity.json';dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(json.dumps(dict(codec=CODEC,payload=pack(cases)),separators=(',',':')))
print('Generated',len(cases),'exact Python-to-native cases',dest.stat().st_size)
