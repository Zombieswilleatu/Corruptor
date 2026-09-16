"""Bounded explicit-input coverage policy. This is not the new doctrine."""
import json
from pathlib import Path
from . import economy as e, effects, powers, paid_inputs, full_match_inputs as ordinary
from .copying import copy_data
from .power_rules import RULES, declaration
from .power_match import PowerMatch

PATH=Path(__file__).with_name('power_inputs.json')
SCHEMA='U13_NINE_LORD_INPUTS_V1'


def candidates(game,pid,power,index,hand):
    w=game._state['world'];n=game.clock.round;rows=w['entities']['entities'];own=w['players'][pid]['lord_id'];lane='Lord' if n%2 else 'Castle'
    enemies=[r for r in rows if r['kind']=='marcher' and r['owner']==1-pid]
    point=next((r for r in enemies if r['attributes']['lane']==lane),None)
    area=dict(lane=lane,field_position=dict(x_fp=point['attributes']['x_fp'] if point else 1200,y_fp=point['attributes']['y_fp'] if point else 300))
    targets=[];parameters={};discard=None
    if power in ('PredatorOfRuin','Rout','MusterTheFaithful','BreathOfLife','WishPower'):targets=[dict(lane=lane)]
    elif power in ('InevitableRuin','WarMachine','WishLongevity'):
        targets=[dict(entity_id=r['id']) for r in rows if r['kind']=='castle' and r['owner']==(1-pid if power=='InevitableRuin' else pid)]
        if power=='InevitableRuin':
            if len(hand)<2:return []
            discard=[r['id'] for r in hand[:2]]
    elif power=='Inferno':targets=[dict(kind='lane',lane=lane)]
    elif power in ('Pyroclasm','WishWealth'):targets=[{}]
    elif power=='Snare':targets=[dict(player_id=1-pid)]
    elif power in ('Web','Redirect','AllegianceShift','GravityOrb','WishDeath'):targets=[area]
    elif power=='FalseOrders':targets=[dict(entity_id=r['id'],owner_id=r['owner'],lane='Castle' if r['attributes']['lane']=='Lord' else 'Lord') for r in powers.guards(w)]
    elif power=='Inversion':targets=[dict(owner_id=1-pid,lane=lane)]
    elif power=='Consume':targets=[dict(entity_id=r['id']) for r in powers.guards(w) if r['owner']==1-pid]
    elif power=='Ravenous':targets=[dict(lane=lane,field_position=dict(x_fp=0 if pid==0 else 2400,y_fp=300))]
    elif power=='Projection':targets=[dict(kind='guard_zone',zone=lane,player_id=1-pid)];parameters=dict(spend=max(1,w['players'][pid]['resources']['life_essence']))
    elif power=='WishResurrection':targets=[dict(kind='guard_zone',zone=lane)]
    return [declaration(pid,n,power,t,index=index,discard_ids=discard,parameters=parameters) for t in targets]


def coverage_plan(game,pid):
    w=game._state['world'];view=ordinary.observation(game,pid);d=w['data'];kind=w['players'][pid]['lord_id'];hand=view['hand'][:]
    view.update(veil_total=paid_inputs.paid.veil(w),breach_lord=d['breach_lord'],invocation_rounds=d['dominion_rites']['invocation_rounds'][:])
    selected=[];names=[k for k,r in RULES.items() if r['lord_id']==kind]
    if kind=='Kanifous':names=names[(game.clock.round-1)%len(names):]+names[:(game.clock.round-1)%len(names)]
    for power in names:
        if kind=='Kanifous' and selected:break
        for s in candidates(game,pid,power,len(selected),hand):
            staged=copy_data({k:v for k,v in game._state.items() if k!='events'});staged['events']=dict(rows=[])
            try:effects.accept(staged,pid,selected+[s],game.clock.round,powers.validate)
            except e.Rejected:continue
            selected.append(s);spent=s['cost'].get('discard_ids',[]);hand=[r for r in hand if r['id'] not in spent];break
    plan=paid_inputs.paid_plan(dict(view,hand=hand));plan['powers']=selected
    moves=plan['order'].get('guard_moves',[]);limit=d['guard_public_limits'][pid]
    if len(moves)>limit:
        # Rebuild the coverage order with the cards the public cap frees.
        plan=ordinary.reference_plan(dict(view,hand=hand),guard_cards=0);plan['powers']=selected
    return plan


def next_operation(game):
    if game.clock.hook=='submission_lock' and game._state['submissions']==[None,None]:
        return dict(kind='submit',plans=[coverage_plan(game,pid) for pid in (0,1)])
    return ordinary.next_operation(game)


def generate():
    result=dict(schema=SCHEMA,policy='U13_POWER_COVERAGE_INPUTS_V1',round_cap=40,cases=[],settlements=ordinary.load()['settlements'])
    for name,lords in (('gremory_humbaba',('Gremory','Humbaba')),('deimos_kalligan',('Deimos','Kalligan')),('orias_odradek',('Orias','Odradek')),('kroni_valak',('Kroni','Valak')),('kanifous_gremory',('Kanifous','Gremory'))):
        setup=dict(seed='u13-nine-lords:'+name,lords=list(lords),castles=[['Keep','Stockpile','SummoningCircle','SiegeEngine','Bastion']]*2)
        game=PowerMatch(setup);ops=[]
        while game.outcome()['winner']==-1:
            if game.clock.round>40:raise ValueError('censored coverage game '+name)
            op=next_operation(game);applied=game.apply(op)
            if applied['action']=='invalid':raise ValueError((name,game.clock.round,op,applied))
            ops.append(op)
        result['cases'].append(dict(name=name,setup=setup,operations=ops,marching_probes=[]))
        print(name,game.clock.round,len(ops),game.outcome(),flush=True)
    from .power_components import generate as components, phase_cases, boundary_cases
    base=components()
    result['components']=base+phase_cases()+boundary_cases(base)
    return result

if __name__=='__main__':PATH.write_text(json.dumps(generate(),indent=2)+'\n',encoding='utf-8')
