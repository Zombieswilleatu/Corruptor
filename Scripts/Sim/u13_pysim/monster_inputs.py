"""Directed monster admissions and saved-round continuations; fixtures are explicit."""
import json
from . import economy as e, monsters, power_components as pc
from .copying import copy_data
from .power_match import PowerMatch
from .full_match_inputs import next_operation


def generate():
    cases=[]
    for name in monsters.NAMES:
        setup=dict(seed='monster-admission:'+name,lords=['Kanifous','Odradek'],castles=[['Keep','Bastion','SummoningCircle','Stockpile','SiegeEngine']]*2)
        game=PowerMatch(setup);operations=[]
        def record(op,rejected=False):
            before=game.snapshot();result=pc.apply(game,op)
            if (result['action']=='invalid')!=rejected:raise ValueError((name,game.clock.round,game.clock.hook,op,result))
            if rejected and game.snapshot()!=before:raise ValueError('Non-atomic monster rejection')
            operations.append(dict(operation=copy_data(op),rejected=rejected))
        while game.clock.hook!='submission_lock':record(next_operation(game))
        w=game._state['world'];cards=[]
        for suit,count in monsters.ROSTER[name]['recipe'].items():
            candidates=sorted((r for r in w['entities']['entities'] if r['kind']=='card' and r['attributes']['suit']==suit),key=lambda r:(r['attributes']['value'],r['id']))
            cards.extend(r['id'] for r in candidates[:count])
        record(dict(kind='fixture_prepare',changes=[dict(kind='fixture_give',player_id=0,card_id=k) for k in cards]))
        ward=dict(action='Ward',lane='Lord',card_ids=cards,monster_choice=name)
        record(dict(kind='submit',plans=[dict(powers=[],order=ward),dict(powers=[],order={})]),True)
        order=dict(action='Hunt',lane='Lord',target_id=w['players'][1]['lord_entity_id'],card_ids=cards,monster_choice=name)
        bad=copy_data(order);bad['card_ids']=cards[1:]
        record(dict(kind='submit',plans=[dict(powers=[],order=bad),dict(powers=[],order={})]),True)
        conflict=copy_data(order);conflict['guard_moves']=[dict(card_id=cards[0],lane='Lord',slot=0)]
        record(dict(kind='submit',plans=[dict(powers=[],order=conflict),dict(powers=[],order={})]),True)
        record(dict(kind='submit',plans=[dict(powers=[],order=order),dict(powers=[],order={})]))
        while not (game.clock.round==2 and game.clock.hook=='submission_lock'):record(next_operation(game))
        bodies=[r for r in game._state['world']['entities']['entities'] if r['attributes'].get('monster_id')==name]
        expected=(3,4,5) if name=='Varn' else (1,)
        if len(bodies) not in expected:raise ValueError(('summon count',name,len(bodies)))
        # Save/restore is exercised by every native fixture, also after spawning.
        record(dict(kind='fixture_prepare',changes=[]))
        if monsters.limited(name):
            record(dict(kind='fixture_prepare',changes=[dict(kind='fixture_give',player_id=0,card_id=k) for k in cards]))
            record(dict(kind='submit',plans=[dict(powers=[],order=order),dict(powers=[],order={})]),True)
        record(dict(kind='submit',plans=[dict(powers=[],order={}),dict(powers=[],order={})]))
        while not (game.clock.round==3 and game.clock.hook=='submission_lock'):record(next_operation(game))
        record(dict(kind='fixture_prepare',changes=[]))
        cases.append(dict(name='monster_'+name,setup=setup,operations=operations))
    return cases




def generate_games():
    from . import power_inputs
    from collections import Counter
    cases=[]
    for lords in (['Kanifous','Gremory'],['Odradek','Deimos'],['Kroni','Valak']):
        name='monsters_'+'_'.join(lords)
        setup=dict(seed=name,lords=lords,castles=[['Keep','Stockpile','SummoningCircle','SiegeEngine','Bastion']]*2)
        game=PowerMatch(setup);operations=[]
        while game.outcome()['winner']==-1:
            if game.clock.round>40:raise ValueError('Unfinished '+name)
            op=power_inputs.next_operation(game)
            if op['kind']=='submit':
                w=game._state['world']
                for pid,plan in enumerate(op['plans']):
                    if plan['order'].get('action') not in ('Hunt','Siege'):continue
                    eligible=monsters.available(w['entities']['entities'],plan['order'].get('card_ids',[]),pid,w['data']['monsters']['unlocked'][pid])
                    if eligible:plan['order']['monster_choice']=eligible[-1]
            result=game.apply(op)
            if result['action']=='invalid':raise ValueError((name,game.clock.round,op,result))
            operations.append(op)
        counts=Counter(r['event']['data']['monster_id'] for r in game._state['events']['rows'] if r['event']['type']=='MONSTER_SUMMONED')
        print(name,game.clock.round,dict(counts),game.outcome(),flush=True)
        cases.append(dict(name=name,setup=setup,operations=operations))
    return cases


if __name__=='__main__':
    import sys
    cases=generate_games() if '--games' in sys.argv else generate()
    with open(sys.argv[1],'w',encoding='utf-8') as f:json.dump(cases,f,ensure_ascii=False,indent=2)
    print(len(cases),'cases;',sum(len(c['operations']) for c in cases),'transitions')
