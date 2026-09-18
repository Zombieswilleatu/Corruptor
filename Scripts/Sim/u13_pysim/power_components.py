"""Directed power boundary inputs, explicitly separate from setup-to-victory games."""
from . import economy as e, paid_inputs, recruitment, powers
from .copying import copy_data
from .power_match import PowerMatch
from .power_rules import RULES,declaration
from .full_match_inputs import next_operation
from .primitives import entity_id


def prepare(game,changes,refresh=True):
    w=game._state['world']
    for op in changes:
        if op['kind']=='fixture_guard':
            z=e.zones(w)
            for pile in [z['deck'],z['discard'],*z['hands'],*z['committed'],z['market'],z['market_reserve']]:
                if op['card_id'] in pile:pile.remove(op['card_id'])
            r=e.entity(w,op['card_id']);r['owner']=op['player_id'];r['attributes'].update(role='guard',lane=op['lane'],slot=op['slot'])
        elif op['kind']=='fixture_marcher':
            a=recruitment.profile(op.get('suit','Butcher'),op['lane'],op['player_id'],0,1);a.update(op['attributes'])
            recruitment.create(w,op['origin'],op['ordinal'],op['player_id'],a)
        else:
            changed=paid_inputs.component_apply(w,op)
            e.require(changed['result']['action']!='invalid','power_fixture_invalid');w=changed['world']
    game._state['world']=w
    if refresh:game._state['presentation_world']=copy_data(w)
    return dict(action='fixture_prepared')


def apply(game,op):
    if op['kind']=='fixture_prepare':return prepare(game,op['changes'],op.get('refresh',True))
    if op['kind']=='phase_probe':
        from . import marching_game
        from .lifecycle import RoundRules
        context=dict(world=game._state['world'],round=game.clock.round,seed=game._state['seed'],hook='marching',player_order=game._state['player_order'],persistent_effects=game._state['persistent']['active'],full_roster=True)
        return marching_game.resolve(context,RoundRules.march_reaction,capture_ticks=True)
    return game.apply(op)


def generate():
    cases=[]
    for power,rules in RULES.items():
        setup=dict(seed='u13-power-component:'+power,lords=['Deimos' if rules.get('breach_wish') else rules['lord_id'],'Gremory'],castles=[['Keep','Stockpile','SummoningCircle','SiegeEngine','Bastion']]*2)
        g=PowerMatch(setup);ops=[]
        def record(op,rejected=False):
            before=g.snapshot();result=apply(g,op)
            if (result['action']=='invalid')!=rejected:raise ValueError((power,op,result))
            if rejected and before!=g.snapshot():raise ValueError('Non-atomic component')
            ops.append(dict(operation=copy_data(op),rejected=rejected))
        def until(hook,number=None):
            while g.clock.hook!=hook or number is not None and g.clock.round!=number:
                if g.clock.hook=='submission_lock' and g._state['submissions']==[None,None]:op=dict(kind='submit',plans=[dict(powers=[],order={})]*2)
                else:op=next_operation(g)
                record(op)
        until('submission_lock')
        w=g._state['world'];changes=[]
        if rules.get('breach_wish'):
            state=copy_data(w['data']['veil_breaches'])
            state['arrivals']=[dict(lord_id='Kanifous',threshold=5,protection=1,round=1,veil=5)]
            changes.append(dict(kind='fixture_data',data=dict(veil_breaches=state,neutral_tears=5)))
        castles=[r for r in w['entities']['entities'] if r['kind']=='castle']
        for c in castles:
            changes.append(dict(kind='fixture_patch',entity_id=c['id'],attributes=dict(construction_state='active',status='standing',integrity=c['attributes']['max_integrity'] if power=='InevitableRuin' else (7 if power.removeprefix('Breach')=='WishLongevity' else 10))))
        if rules['lord_id']=='Odradek':changes.append(dict(kind='fixture_resources',player_id=0,resources=dict(reconfiguration=4)))
        if rules['lord_id']=='Valak':changes.append(dict(kind='fixture_resources',player_id=0,resources=dict(life_essence=5)))
        cards=[r for r in w['entities']['entities'] if r['kind']=='card' and r['attributes']['value']==2]
        for pid in (0,1):
            for slot in (0,1):changes.append(dict(kind='fixture_guard',card_id=cards[pid*2+slot]['id'],player_id=pid,lane='Lord',slot=slot))
        for pid in (0,1):
            for i in range(4):
                changes.append(dict(kind='fixture_marcher',origin='power-component:'+str(pid),ordinal=i,player_id=pid,lane='Lord',suit='Butcher',attributes=dict(x_fp=1100+100*pid,y_fp=210+60*i,armor=0,hp=2)))
        record(dict(kind='fixture_prepare',changes=changes))
        w=g._state['world'];target={};params={};discard=None
        base_power=power.removeprefix('Breach')
        if base_power in ('PredatorOfRuin','Rout','MusterTheFaithful','BreathOfLife','WishPower'):target=dict(lane='Lord')
        elif base_power in ('InevitableRuin','WarMachine','WishLongevity'):
            r=next(c for c in w['entities']['entities'] if c['kind']=='castle' and c['owner']==(1 if base_power=='InevitableRuin' else 0) and (base_power!='WarMachine' or c['attributes']['combat_profile']=='siege_engine'))
            target=dict(entity_id=r['id'])
            if base_power=='InevitableRuin':discard=e.zones(w)['hands'][0][:2]
        elif base_power=='Inferno':target=dict(kind='lane',lane='Lord')
        elif base_power=='Snare':target=dict(player_id=1)
        elif base_power in ('Web','Redirect','AllegianceShift','GravityOrb','WishDeath'):target=dict(lane='Lord',field_position=dict(x_fp=1150,y_fp=300))
        elif base_power=='FalseOrders':target=dict(entity_id=cards[2]['id'],owner_id=1,lane='Castle')
        elif base_power=='Inversion':target=dict(owner_id=1,lane='Lord')
        elif base_power=='Consume':target=dict(entity_id=cards[2]['id'])
        elif base_power=='Ravenous':target=dict(lane='Lord',field_position=dict(x_fp=0,y_fp=300))
        elif base_power=='Projection':target=dict(kind='guard_zone',zone='Lord',player_id=1);params=dict(spend=3)
        elif base_power=='WishResurrection':
            target=dict(lane='Lord')
            # The existing opposing Marchers fight during the upcoming phase.
        if power=='Pyroclasm':
            record(dict(kind='submit',plans=[dict(powers=[declaration(0,1,'Inferno',dict(kind='castle',entity_id=next(c['id'] for c in w['entities']['entities'] if c['kind']=='castle' and c['owner']==1 and c['attributes']['castle_type']=='Keep')))],order={}),dict(powers=[],order={})]))
            until('submission_lock',2)
        n=g.clock.round;s=declaration(0,n,power,target,discard_ids=discard,parameters=params)
        for field,value in (('declaration_id','wrong'),('queue_index',2),('lord_id','WrongLord'),('visibility','hidden'),('declared_round',n+1)):
            bad=copy_data(s);bad[field]=value
            record(dict(kind='submit',plans=[dict(powers=[bad],order={}),dict(powers=[],order={})]),True)
        record(dict(kind='submit',plans=[dict(powers=[s],order={}),dict(powers=[],order={})]))
        # A declaration is queued, paid and fired by normal production hooks.
        until(rules['fire_hook'],n+rules['delay_rounds'])
        record(dict(kind='step',hook=rules['fire_hook']))
        if power in ('Ravenous','GravityOrb','Web','BreathOfLife','Rout'):
            until('marching',g.clock.round)
            record(dict(kind='phase_probe'))
        cases.append(dict(name='power_'+power,setup=setup,operations=ops))
    return cases


PHASE_NAMES=['lamp_'+s for s in (*recruitment.SUITS,'rejected')]+['interlock_live_attacker','kroni_breach_collapse']


def phase_cases():
    from .primitives import draw,instance_id
    from . import kroni_actors
    result=[]
    for name in PHASE_NAMES:
        setup=dict(seed='u13-power-phase:'+name,lords=['Kanifous','Odradek'],castles=[['Keep','Stockpile','SummoningCircle','SiegeEngine','Bastion']]*2)
        g=PowerMatch(setup);ops=[]
        def record(op):
            outcome=apply(g,op)
            e.require(outcome['action']!='invalid','phase_fixture_invalid')
            ops.append(dict(operation=copy_data(op),rejected=False))
        while g.clock.round!=2 or g.clock.hook!='marching':
            if g.clock.hook=='submission_lock' and g._state['submissions']==[None,None]:op=dict(kind='submit',plans=[dict(powers=[],order={})]*2)
            else:op=next_operation(g)
            record(op)
        w=g._state['world'];changes=[]
        if name.startswith('lamp_'):
            lamp_id=instance_id('wishmaster','0','1');suit=name.removeprefix('lamp_');rejected=suit=='rejected'
            if rejected:suit='Butcher'
            ordinal=0
            while (draw(setup['seed'],lamp_id+':'+entity_id('marcher','lamp-probe',ordinal),'WISHMASTER_REJECTION',0,10)==0)!=rejected:ordinal+=1
            lamp=dict(id=lamp_id,owner=0,phase='lamp',created_round=1,due_round=2,target=dict(lane='Lord',field_position=dict(x_fp=1000,y_fp=300)))
            changes.append(dict(kind='fixture_data',data=dict(kanifous_objects=[lamp])))
            changes.append(dict(kind='fixture_marcher',origin='lamp-probe',ordinal=ordinal,player_id=0,lane='Lord',suit=suit,attributes=dict(x_fp=1000,y_fp=300)))
            for i in range(2):changes.append(dict(kind='fixture_marcher',origin='lamp-opposition',ordinal=i,player_id=1,lane='Lord',suit='Penitent',attributes=dict(x_fp=1250+200*i,y_fp=300,hp=9,max_hp=9,attack=1)))
        elif name=='interlock_live_attacker':
            changes.append(dict(kind='fixture_data',data=dict(kanifous_objects=[])))
            for pid,hp,attack in ((1,2,1),(0,9,3)):
                changes.append(dict(kind='fixture_marcher',origin='interlock-probe',ordinal=pid,player_id=pid,lane='Lord',suit='Butcher',attributes=dict(x_fp=1000+100*pid,y_fp=300,hp=hp,max_hp=hp,armor=0,attack=attack)))
        else:
            actor=kroni_actors.create(instance_id('insatiable','2','breach'),-1,2,0,True,setup['seed'])
            # Full-world spatial probe: active Kroni actor under Valak collapse.
            changes.append(dict(kind='fixture_data',data=dict(kanifous_objects=[],kroni_actors=[actor],breach_lord='Valak')))
            for i,suit in enumerate(recruitment.SUITS*2):
                changes.append(dict(kind='fixture_marcher',origin='breach-probe',ordinal=i,player_id=i%2,lane='Lord' if actor['y_fp']<600 else 'Castle',suit=suit,
                    attributes=dict(x_fp=max(0,min(2400,actor['x_fp']+40*i-140)),y_fp=max(0,min(600,actor['y_fp']%600+35*i-100)))))
        record(dict(kind='fixture_prepare',changes=changes));record(dict(kind='phase_probe'))
        result.append(dict(name=name,setup=setup,operations=ops))
    return result


BOUNDARY_NAMES=['kroni_work_only','consume_source_banished','ruin_repaired_before_firing','repeatable_queue_and_budget']


def boundary_cases(base):
    result=[]
    for name,source_power in (('consume_source_banished','Consume'),('ruin_repaired_before_firing','InevitableRuin')):
        original=next(c for c in base if c['name']=='power_'+source_power);case=copy_data(original);case['name']=name;g=PowerMatch(case['setup'])
        for entry in case['operations'][:-1]:apply(g,entry['operation'])
        if source_power=='Consume':
            key=g._state['world']['players'][0]['lord_entity_id'];changes=[dict(kind='fixture_patch',entity_id=key,attributes=dict(alive=False,threat=0))]
        else:
            pending=next(r for r in g._state['pending']['pending'] if r['declaration']['power_id']==source_power);key=pending['declaration']['target']['entity_id'];row=e.entity(g._state['world'],key)
            changes=[dict(kind='fixture_patch',entity_id=key,attributes=dict(integrity=row['attributes']['max_integrity'],status='standing'))]
        case['operations'].insert(-1,dict(operation=dict(kind='fixture_prepare',changes=changes,refresh=False),rejected=False));result.append(case)
    for name,lord in (('kroni_work_only','Kroni'),('repeatable_queue_and_budget','Odradek')):
        setup=paid_inputs.setup('power-boundary:'+name,(lord,'Gremory'));g=PowerMatch(setup);ops=[]
        def record(op,rejected=False):
            changed=apply(g,op)
            if (changed['action']=='invalid')!=rejected:raise ValueError((name,op,changed))
            ops.append(dict(operation=copy_data(op),rejected=rejected))
        while g.clock.hook!='submission_lock':record(next_operation(g))
        if lord=='Kroni':
            key=g._state['world']['players'][0]['lord_entity_id']
            record(dict(kind='fixture_prepare',changes=[dict(kind='fixture_patch',entity_id=key,attributes=dict(hunger=3,hunger_milestone=True)),dict(kind='fixture_resources',player_id=0,resources=dict(personal_tears=1))]))
            plan=dict(powers=[],order=dict(castle_action=dict(action='Work',target_id='',card_ids=[],use_repair_token=False)))
        else:
            record(dict(kind='fixture_prepare',changes=[dict(kind='fixture_resources',player_id=0,resources=dict(reconfiguration=4))]))
            sources=[declaration(0,1,'Redirect',dict(lane='Lord',field_position=dict(x_fp=900+10*i,y_fp=300)),index=i) for i in range(5)]
            record(dict(kind='submit',plans=[dict(powers=sources,order={}),dict(powers=[],order={})]),True)
            plan=dict(powers=sources[:4],order={})
        record(dict(kind='submit',plans=[plan,dict(powers=[],order={})]))
        final='combat_resolution' if lord=='Kroni' else 'post_resolution_position'
        while True:
            hook=g.clock.hook;record(dict(kind='step',hook=hook))
            if hook==final:break
        result.append(dict(name=name,setup=setup,operations=ops))
    return sorted(result,key=lambda c:BOUNDARY_NAMES.index(c['name']))
