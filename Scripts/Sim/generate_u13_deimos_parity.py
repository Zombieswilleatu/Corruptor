"""Generate exact Deimos milestone/Pillage cases for the native parity runner."""
from pathlib import Path
import sys,json,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parent))
from u13_doctrine.test_deimos import prepared
from u13_doctrine.facts import Facts
from u13_doctrine.observation import observe
from u13_pysim import economy as e,power_components
from u13_pysim.power_rules import declaration
from u13_pysim.full_match_inputs import next_operation
from u13_pysim.codec import pack,CODEC
from u13_pysim.copying import copy_data
cases=[]
for kind in ('last_castle','not_last_castle','already_rewarded','banished','pillage'):
    g,engine,victim,spare=prepared(hp=1,last=kind!='not_last_castle')
    powers=[declaration(0,g.clock.round,'WarMachine',dict(entity_id=engine))];order={};changes=[]
    if kind=='already_rewarded':g._state['world']['data']['deimos_all_castles_ruined']=[True,False]
    if kind=='banished':
        changes.append(dict(kind='fixture_patch',entity_id=g._state['world']['players'][0]['lord_entity_id'],attributes=dict(alive=False)))
        powers=[]
    if kind=='pillage':
        changes.append(dict(kind='fixture_patch',entity_id=victim,attributes=dict(status='ruined',integrity=0)))
        f=Facts(observe(g,0));card=f.hand[0];guard=next(r for r in g._state['world']['entities']['entities'] if r['kind']=='card' and r['id'] not in [x['id'] for x in f.hand])
        changes.extend([dict(kind='fixture_patch',entity_id=card['id'],attributes=dict(suit='Butcher',value=1)),dict(kind='fixture_patch',entity_id=guard['id'],attributes=dict(suit='Penitent',value=5)),dict(kind='fixture_guard',card_id=guard['id'],player_id=1,lane='Castle',slot=0)])
        order=dict(action='Siege',lane='Castle',target_id='castle_zone:1',card_ids=[card['id']]);powers=[]
    power_components.prepare(g,changes)
    case=dict(name=kind,initial=g.snapshot(),steps=[])
    op=dict(kind='submit',plans=[dict(order=order,powers=powers),dict(order={},powers=[])])
    while True:
        result=g.apply(op);assert result['action']!='invalid',result
        case['steps'].append(dict(operation=op,result=result,state=g.snapshot()))
        if g.clock.hook=='post_resolution_spawns':break
        op=next_operation(g)
    events=[x['event'] for x in g._state['events']['rows']]
    bonus=sum(x['type']=='DEIMOS_ALL_CASTLES_RUINED' for x in events)
    assert bonus==int(kind=='last_castle'),(kind,bonus)
    if kind=='pillage':
        hit=next(x['data'] for x in events if x['type']=='SIEGE_RESOLVED' and x['data']['player_id']==0)
        assert hit['pillage_success'] and any(x['type']=='FEAR_AURA' and x['data']['returned_ids']==[guard['id']] for x in events)
    cases.append(case)
dest=Path(sys.argv[1]) if len(sys.argv)>1 else Path(tempfile.gettempdir())/'u13-deimos-parity.json'
dest.write_text(json.dumps(dict(codec=CODEC,payload=pack(cases)),separators=(',',':')))
print('Generated',len(cases),'cases,',sum(len(c['steps'])*4 for c in cases)+len(cases)+1,'native checks')
