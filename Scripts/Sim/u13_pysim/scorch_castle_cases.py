"""Explicit single-Castle fire cases, independent gameplay assertions and inputs.

No native expected states are used to generate or run these scenarios.
"""
from . import economy as e, power_components, paid_inputs, full_match_inputs
from .copying import copy_data
from .power_match import PowerMatch
from .power_rules import declaration

SCHEMA = 'U13_SCORCH_CASTLE_CASES_V1'


def generate():
    cases=[]
    for name in ('base_cycle','endpoint_pyro','peak_pyro','switching','lethal_and_empty','lost_before_activation','armed_banishment'):
        setup=paid_inputs.setup('scorch-castle:'+name,('Kalligan','Gremory'))
        g=PowerMatch(setup);ops=[]
        def record(op,rejected=False):
            before=g.snapshot() if rejected else None
            result=power_components.apply(g,op)
            if (result['action']=='invalid') != rejected:raise AssertionError((name,op,result))
            if rejected:assert before==g.snapshot()
            ops.append(dict(operation=copy_data(op),rejected=rejected))
        def until(hook,n):
            while g.clock.hook!=hook or g.clock.round!=n:
                if g.clock.hook=='submission_lock' and g._state['submissions']==[None,None]:
                    op=dict(kind='submit',plans=[dict(powers=[],order={})]*2)
                else:op=full_match_inputs.next_operation(g)
                record(op)
        def submit(sources,rejected=False):
            record(dict(kind='submit',plans=[dict(powers=sources,order={}),dict(powers=[],order={})]),rejected)
        def patch(key,**attrs):record(dict(kind='fixture_prepare',changes=[dict(kind='fixture_patch',entity_id=key,attributes=attrs)],refresh=g.clock.hook=='submission_lock'))
        until('submission_lock',1)
        w=g._state['world']
        castles=[r for r in w['entities']['entities'] if r['kind']=='castle' and r['owner']==1]
        a=next(r['id'] for r in castles if r['attributes']['castle_type']=='Keep')
        b=next(r['id'] for r in castles if r['attributes']['castle_type']=='Bastion')
        own=next(r['id'] for r in w['entities']['entities'] if r['kind']=='castle' and r['owner']==0)
        protected=next(r['id'] for r in castles if r['attributes']['castle_type']=='SummoningCircle')
        patch(a,integrity=17,status='standing',construction_state='active')
        patch(b,integrity=17,status='standing',construction_state='active')
        patch(protected,integrity=0,status='defunct',construction_state='unbuilt')
        cards=[r for r in w['entities']['entities'] if r['kind']=='card' and r['attributes']['value'] in (1,5)]
        guard_ids=[next(r['id'] for r in cards if r['attributes']['value']==value) for value in (1,5)]
        record(dict(kind='fixture_prepare',changes=[dict(kind='fixture_guard',card_id=key,player_id=1,lane='Castle' if i==0 else 'Lord',slot=0) for i,key in enumerate(guard_ids)]))
        if name=='lethal_and_empty':patch(a,integrity=3,status='standing')
        target=lambda key:dict(kind='castle',entity_id=key)
        for invalid in (dict(kind='guard',lane='Castle',player_id=1),dict(kind='guard',lane='Lord',player_id=1),target(own),target(protected),target(w['players'][1]['lord_entity_id']),target('missing'),dict(kind='castle'),dict(kind='lane',lane='Castle',player_id=1)):
            submit([declaration(0,1,'Inferno',invalid)],True)
        submit([declaration(0,1,'Pyroclasm')],True)
        submit([declaration(0,1,'Inferno',target(a))])
        if name in ('lost_before_activation','armed_banishment'):
            until('post_resolution_direct',1)
            if name=='lost_before_activation':patch(a,integrity=0,status='ruined')
            else:
                # A locked declaration survives its source's later banishment.
                patch(w['players'][0]['lord_entity_id'],alive=False,threat=0)
        first=None
        for n in (2,3,4):
            until('submission_lock',n)
            active=g._state['persistent']['active'][0]
            if first is None:first=copy_data(active)
            assert active['effect_id']==first['effect_id'] and active['activated_round']==2 and active['declaration']==first['declaration']
            assert active['stage_index']==n-2 and active['stages'][n-2]['intensity']==(2 if n==3 else 1)
            sources=[]
            if name=='switching' and n<4:
                sources.append(declaration(0,n,'Inferno',dict(kind='lane',lane='Castle') if n==2 else target(b)))
            if name=='endpoint_pyro' and n in (2,4) or name=='peak_pyro' and n==3 or name=='lethal_and_empty' and n==2:
                sources.append(declaration(0,n,'Pyroclasm',index=len(sources)))
            if name=='endpoint_pyro' and n==3 or name=='peak_pyro' and n==4 or name=='armed_banishment':
                submit([declaration(0,n,'Pyroclasm')],True)
            if n==4:submit([declaration(0,n,'Inferno',target(b))],True)
            submit(sources)
        until('submission_lock',5)
        assert not g._state['persistent']['active']
        submit([declaration(0,5,'Inferno',target(b))],True)
        events=[r['event'] for r in g._state['events']['rows']]
        hits=[r['data'] for r in events if r['type']=='HAZARD_HIT' and 'castle_damage' in r['data']]
        values=[sum(r['castle_damage'] for r in hits if r['round']==n) for n in (2,3,4)]
        expected=dict(base_cycle=[1,2,1],endpoint_pyro=[2,2,2],peak_pyro=[1,4,1],switching=[1,0,1],lethal_and_empty=[2,1,0],lost_before_activation=[0,0,0],armed_banishment=[1,2,1])[name]
        assert values==expected,(name,values)
        assert all(e.entity(g._state['world'],key)['owner']==1 and e.entity(g._state['world'],key)['attributes']['value']==v for key,v in zip(guard_ids,(1,5)))
        assert set(r['entity_id'] for r in hits)<=({a,b} if name=='switching' else {a})
        if name=='lethal_and_empty':
            assert e.entity(g._state['world'],a)['attributes']['status']=='ruined'
            deaths=[r['data'] for r in events if r['type']=='CASTLE_DESTROYED' and r['data'].get('cause')=='scorch']
            assert len(deaths)==1 and deaths[0]['player_id']==-1
            assert sum(r['type']=='NEUTRAL_TEAR_CREATED' and r['data'].get('source')=='CastleDestruction' for r in events)==1
        until('submission_lock',6)
        if name!='armed_banishment':submit([declaration(0,6,'Inferno',target(b))])
        cases.append(dict(name=name,setup=setup,operations=ops,castle_damage_by_round=expected))
    return dict(schema=SCHEMA,cases=cases)
