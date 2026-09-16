"""Owned declared-power transforms for the existing nine-Lord authority."""
from . import economy as e, recruitment as recruit
from .copying import copy_data
from .primitives import instance_id
from .battle import Battle, targetable, operational, note_loss
from .resolution import Ordinary
from .power_rules import RULES

LANES = ('Lord','Castle')
WISHES = ('WishPower','WishLongevity','WishResurrection','WishDeath','WishWealth')
RECONFIG = ('Redirect','FalseOrders','AllegianceShift','Inversion')


def spatial(target):
    p=target.get('field_position',{})
    return (set(target)=={'lane','field_position'} and target['lane'] in LANES
            and type(p) is dict and set(p)=={'x_fp','y_fp'}
            and type(p['x_fp']) is int and 0<=p['x_fp']<=2400
            and type(p['y_fp']) is int and 0<=p['y_fp']<=600)


def guards(w):
    return [r for r in w['entities']['entities'] if r['kind']=='card' and r['attributes'].get('role')=='guard']


def slots(w,pid,lane):
    occupied={r['attributes']['slot'] for r in guards(w) if r['owner']==pid and r['attributes']['lane']==lane}
    return [n for n in range(3) if n not in occupied]


def eligible(w,pid,lane,new):
    return sorted(r['id'] for r in guards(w) if r['owner']==pid and r['attributes']['lane']==lane) if slots(w,new,lane) else []


def transfer(w,key,pid,new,lane,mutate=False):
    r=e.entity(w,key)
    if not r or r not in guards(w) or r['owner']!=pid: return None
    if (new==pid and r['attributes']['lane']==lane) or (new!=pid and r['attributes']['lane']!=lane): return None
    free=slots(w,new,lane)
    if not free: return None
    before=copy_data(r)
    if mutate:
        r['owner']=new;r['attributes']['lane']=lane
        if r['attributes']['slot'] not in free: r['attributes']['slot']=free[0]
    return before


def validate(s,w,phase,active):
    power,t,p,pid=s['power_id'],s['target'],s['parameters'],s['player_id']
    r=e.entity(w,t.get('entity_id',''))
    if power=='PredatorOfRuin': return '' if t.get('lane') in LANES else 'lane_invalid'
    if power=='InevitableRuin':
        if not targetable(r): return 'castle_not_targetable'
        if r['owner']!=1-pid: return 'castle_not_enemy'
        return 'castle_not_damaged' if phase=='declaration' and r['attributes']['integrity']>=r['attributes']['max_integrity'] else ''
    if power=='WarMachine': return '' if r and r['owner']==pid and r['attributes'].get('combat_profile')=='siege_engine' and operational(r) else 'siege_engine_not_operational'
    if power in ('Rout','MusterTheFaithful','BreathOfLife'):
        return '' if set(t)=={'lane'} and t['lane'] in LANES and not p else 'rout_lane_invalid' if power=='Rout' else 'humbaba_lane_invalid'
    if power in ('Inferno','Pyroclasm'):
        if p: return 'kalligan_parameters_invalid'
        if power=='Pyroclasm': return '' if not t and any(a['declaration']['power_id']=='Inferno' and a['declaration']['player_id']==pid for a in active) else 'pyroclasm_requires_active_scorch'
        return '' if t.get('lane') in LANES and (set(t)=={'kind','lane'} and t['kind']=='lane' or set(t)=={'kind','lane','player_id'} and t['kind']=='guard' and type(t['player_id']) is int and t['player_id']==1-pid) else 'scorch_target_invalid'
    if power=='Web': return '' if spatial(t) and not p else 'web_position_invalid'
    if power=='Snare':
        legal=set(t)=={'player_id'} and type(t['player_id']) is int and t['player_id']==1-pid and not p
        if phase=='declaration': legal=legal and e.entity(w,w['players'][pid]['lord_entity_id'])['attributes']['threat']<1000000
        return '' if legal else 'snare_terms_invalid'
    if power in RECONFIG:
        legal=not p
        if power in ('Redirect','AllegianceShift'): legal=legal and spatial(t)
        else:
            legal=legal and set(t)==({'entity_id','owner_id','lane'} if power=='FalseOrders' else {'owner_id','lane'}) and type(t.get('owner_id')) is int and t['owner_id'] in (0,1) and t['lane'] in LANES
            if legal:
                legal=bool(transfer(w,t['entity_id'],t['owner_id'],t['owner_id'],t['lane'])) if power=='FalseOrders' else bool(eligible(w,t['owner_id'],t['lane'],1-t['owner_id']))
        return '' if legal else 'reconfiguration_target_unavailable'
    if power=='Consume':
        if phase=='firing' and not Battle(w,0,'',[],'').active(pid,'Kroni'): return 'kroni_source_banished'
        return '' if not p and set(t)=={'entity_id'} and r in guards(w) and r['owner']==1-pid else 'kroni_target_unavailable'
    if power=='Ravenous': return '' if not p and spatial(t) and t['field_position']['x_fp']==(0 if pid==0 else 2400) else 'ravenous_position_invalid'
    if power=='GravityOrb': return '' if spatial(t) and not p else 'gravity_orb_target_invalid'
    if power=='Projection':
        legal=set(t)=={'kind','zone','player_id'} and t.get('kind')=='guard_zone' and t.get('zone') in LANES and type(t.get('player_id')) is int and t['player_id']==1-pid and set(p)=={'spend'} and type(p['spend']) is int and 1<=p['spend']<=5
        if phase=='declaration': legal=legal and p['spend']<=w['players'][pid]['resources']['life_essence']
        return '' if legal else 'projection_zone_or_essence_invalid'
    if power in WISHES:
        legal=not p
        if power=='WishPower': legal=legal and set(t)=={'lane'} and t['lane'] in LANES
        elif power=='WishLongevity': legal=legal and set(t)=={'entity_id'} and targetable(r) and r['owner']==pid and r['attributes']['integrity']<r['attributes']['max_integrity']
        elif power=='WishResurrection': legal=legal and set(t)=={'kind','zone'} and t['kind']=='guard_zone' and t['zone'] in LANES
        elif power=='WishDeath': legal=legal and spatial(t)
        else: legal=legal and not t
        return '' if legal else 'wish_target_invalid'
    raise e.Unsupported('Unknown power '+power)


def members(w,target,radius,owner=-2):
    p=target['field_position']
    return sorted(r['id'] for r in w['entities']['entities'] if r['kind']=='marcher' and (owner==-2 or r['owner']==owner)
                  and r['attributes']['lane']==target['lane'] and (r['attributes']['x_fp']-p['x_fp'])**2+(r['attributes']['y_fp']-p['y_fp'])**2<=radius*radius)


def odradek_event(kind,d):
    message=''
    if kind=='GUARD_RECONFIGURED':
        a=d['after'];message=f"{d['power']}: {a['attributes']['suit']} {a['attributes']['value']} moves to player {a['owner']+1}'s {a['attributes']['lane']} Guards."
    elif kind=='RECONFIGURATION_RESOLVED': message=f"{d['power']}: {d['moved']} Guard(s) moved."
    elif kind=='NEUTRAL_TEAR_CREATED': message='Inversion: +1 Neutral Tear.'
    elif kind=='ALLEGIANCE_SHIFT_RESOLVED': message=f"{'Paradox Geometry' if d['player_id']==-1 else 'Allegiance Shift'}: {len(d['affected_ids'])} Marcher(s) changed allegiance."
    elif kind=='PSYCHIC_INTERLOCK': message=f"Psychic Interlock: {d['damage']} damage reflected{'' if d['target_alive'] else ' (attacker already defeated)'}."
    elif kind=='PARADOX_GEOMETRY': message='Paradox Geometry: '+('no valid targets' if d['kind']=='none' else d['kind']+' allegiance event')+'.'
    return e.event(kind,d,message)


def shift(b,target,new,identity):
    ids=members(b.w,target,180,1-new if new in (0,1) else -2);events=[]
    for key in ids:
        r=e.entity(b.w,key)
        fact=b.fact(dict(command_id=instance_id('allegiance',identity,key),kind='change_marcher_allegiance',target_id=key,new_owner=new if new in (0,1) else 1-r['owner']))
        events.append(e.event(fact['type'],fact['data']))
    events.append(odradek_event('ALLEGIANCE_SHIFT_RESOLVED',dict(declaration_id=identity,player_id=new,target=target,radius_fp=180,affected_ids=ids,round=b.number,hook='post_resolution_allegiance')))
    return events


def pulse(b,active,pulse_id,inner=False):
    target=active['target'];intensity=active['stages'][active['stage_index']]['intensity']
    ids=sorted(r['id'] for r in b.w['entities']['entities'] if (r['kind']=='marcher' and r['attributes']['lane']==target['lane'] if target['kind']=='lane'
               else r in guards(b.w) and r['owner']==target['player_id'] and r['attributes']['lane']==target['lane'] and r['attributes']['value']<=intensity))
    events=[]
    for key in ids:
        r=e.entity(b.w,key);absorbed=0
        command=dict(command_id=instance_id('hazard_hit',pulse_id,key),target_id=key)
        if target['kind']=='lane':
            absorbed=min(r['attributes']['armor'],intensity);r['attributes']['armor']-=absorbed
            command.update(kind='marcher_damage',damage=intensity-absorbed,cause='hazard')
        else: command['kind']='defeat_guard'
        fact=b.fact(command);events.append(e.event(fact['type'],fact['data']));events.extend(b.react(fact,inner=inner))
        events.append(e.event('HAZARD_HIT',dict(effect_id=active['effect_id'],pulse_id=pulse_id,entity_id=key,intensity=intensity,armor_absorbed=absorbed,round=b.number,hook=b.hook)))
    events.append(e.event('HAZARD_PULSED',dict(effect_id=active['effect_id'],power_id=active['declaration']['power_id'],player_id=active['declaration']['player_id'],target=target,intensity=intensity,pulse_id=pulse_id,affected_ids=ids,round=b.number,hook=b.hook)))
    return events


def resolve(rec,state,n):
    s=rec['declaration'];power=s['power_id'];pid=s['player_id'];t=s['target'];identity=s['declaration_id']
    w=state['world'];b=Ordinary(w,n,state['seed'],state['player_order'],rec['fire_hook']);events=[];payload={}
    if power in ('PredatorOfRuin','MusterTheFaithful'):
        for ordinal in range(3):
            a=recruit.profile('Vulture' if power=='PredatorOfRuin' else 'Penitent',t['lane'],pid,n,n);a['source_effect_id']=rec['effect_id']
            r=recruit.create(w,rec['effect_id'],ordinal,pid,a);recruit.place_spawn(w,r,state['seed'])
            events.append(e.event('MARCHER_SPAWNED',r))
    elif power=='InevitableRuin':
        r=e.entity(w,t['entity_id']);before=r['attributes']['integrity'];r['attributes'].update(integrity=0,status='defunct',artillery_target='');note_loss(r,before,n)
        events.append(e.event('CASTLE_DEFUNCT',dict(castle_id=r['id'],declaration_id=identity,player_id=pid,round=n,cause='Inevitable Ruin')))
    elif power=='WarMachine': events.extend(b.fire(t['entity_id'],rec['effect_id']))
    elif power=='Rout':
        ids=[];key=instance_id('persistent',identity,power)
        for r in w['entities']['entities']:
            if r['kind']=='marcher' and r['owner']==1-pid and r['attributes']['lane']==t['lane']:
                r['attributes'].update(rout_round=n,rout_effect_id=key,waiting=False,waiting_since_round=0,contact_tick=-1);ids.append(r['id'])
        payload['affected_ids']=ids;events.append(e.event('ROUT_APPLIED',dict(player_id=pid,round=n,lane=t['lane'],affected_ids=ids,effect_id=key,recovery_round=n+1)))
    elif power=='BreathOfLife':
        modifiers=RULES[power]['lane_aura'];payload['lane_aura']=copy_data(modifiers)
        events.append(e.event('LANE_AURA_STARTED',dict(effect_id=instance_id('persistent',identity,power),power_id=power,player_id=pid,round=n,lane=t['lane'],modifiers=modifiers)))
    elif power=='Inferno': payload['hazard']='scorch'
    elif power=='Pyroclasm':
        active=next(a for a in state['persistent']['active'] if a['declaration']['power_id']=='Inferno' and a['declaration']['player_id']==pid)
        events.extend(pulse(b,active,rec["effect_id"],inner=True))
    elif power=='Web':
        key=instance_id('persistent',identity,power);ids=members(w,t,270,1-pid)
        for uid in ids:
            r=e.entity(w,uid);absorbed=min(r['attributes']['armor'],1);r['attributes']['armor']-=absorbed
            fact=b.fact(dict(command_id=instance_id('web_hit',key,uid),kind='marcher_damage',target_id=uid,damage=1-absorbed,cause='hazard'))
            events.append(e.event(fact['type'],fact['data']));events.extend(b.react(fact,inner=True))
            events.append(e.event('WEB_HIT',dict(effect_id=key,entity_id=uid,armor_absorbed=absorbed,intensity=1,round=n,hook=rec['fire_hook'])))
        events.append(e.event('WEB_STARTED',dict(effect_id=key,player_id=pid,target=t,radius_fp=270,affected_ids=ids,round=n,hook=rec['fire_hook'])))
        payload['spatial_field']=copy_data(RULES[power]['spatial_field'])
    elif power=='Snare':
        w['data']['snare_rounds'][t['player_id']]=n
        events.append(e.event('SNARE_ACTIVE',dict(player_id=pid,target_player_id=t['player_id'],round=n,hook=rec['fire_hook'],declaration_id=identity,guard_limit=1)))
    elif power=='Redirect':
        ids=members(w,t,300);prior={key:copy_data(e.entity(w,key)) for key in ids};duels=w['data'].get('marching_duels',{})
        for lane,duel in list(duels.items()):
            if any(u['id'] in ids for u in duel['units']):
                for u in duel['units']:
                    r=e.entity(w,u['id'])
                    if r:r['attributes']['contact_tick']=-1
                del duels[lane]
        changes=[]
        for key in ids:
            r=e.entity(w,key);r['attributes']['lane']='Castle' if r['attributes']['lane']=='Lord' else 'Lord';changes.append(dict(before=prior[key],after=copy_data(r)))
        events.append(odradek_event('REDIRECT_RESOLVED',dict(declaration_id=identity,player_id=pid,round=n,hook=rec['fire_hook'],target=t,radius_fp=300,changes=changes)))
    elif power=='AllegianceShift': events.extend(shift(b,t,pid,identity))
    elif power in ('FalseOrders','Inversion'):
        ids=[t['entity_id']] if power=='FalseOrders' else eligible(w,t['owner_id'],t['lane'],1-t['owner_id']);changed=0
        for key in ids:
            before=transfer(w,key,t['owner_id'],t['owner_id'] if power=='FalseOrders' else 1-t['owner_id'],t['lane'],True)
            if before is None: continue
            changed+=1;events.append(odradek_event('GUARD_RECONFIGURED',dict(before=before,after=e.entity(w,key),power=power,declaration_id=identity,round=n,hook=rec['fire_hook'])))
        tear=int(power=='Inversion' and changed>0);w['data']['neutral_tears']+=tear
        if tear: events.append(odradek_event('NEUTRAL_TEAR_CREATED',dict(amount=tear,source=power,player_id=pid,round=n,hook=rec['fire_hook'])))
        events.append(odradek_event('RECONFIGURATION_RESOLVED',dict(power=power,player_id=pid,declaration_id=identity,round=n,hook=rec['fire_hook'],moved=changed,neutral_tears=tear)))
    elif power in ('Consume','Ravenous'):
        from . import kroni_actors as kroni
        if power=='Consume':
            events.append(kroni.devour_guard(w,e.entity(w,t['entity_id']),pid,n,'Consume'));events.extend(kroni.feed(w,pid,1,n,'Consume'));w['data']['kroni_fed'][pid]=n
        else:
            actor=kroni.create(identity,pid,n,b.lord(pid)['attributes']['hunger'],False,state['seed'],t,w['entities']['entities']);w['data']['kroni_actors'].append(actor)
            events.append(e.event('RAVENOUS_ARMED',dict(actor=actor,round=n,hook=rec['fire_hook']),'Ravenous: Kroni will cross the field during Marching.'))
    elif power=='GravityOrb':
        orb=dict(id=instance_id('persistent',identity,power),owner=pid,target=copy_data(t),round=n,consumed=0,rewarded=False);w['data']['valak_orbs'].append(orb)
        events.append(e.event('GRAVITY_ORB_STARTED',orb));payload['gravity_orb']=True
    elif power=='Projection':
        spend=s['parameters']['spend'];resources=w['players'][pid]['resources'];e.require(w['data']['valak_reserved'][pid]==spend,'projection_reservation_missing')
        before=resources['life_essence']+spend;w['data']['valak_reserved'][pid]=0
        candidates=sorted((r for r in guards(w) if r['owner']==1-pid and r['attributes']['lane']==t['zone'] and r['attributes']['value']<=spend),key=lambda r:(-r['attributes']['value'],r['attributes']['slot'],r['id']))
        victim=copy_data(candidates[0]) if candidates else {}
        if victim: events.extend(b.apply_fact(dict(command_id=instance_id('projection',identity,victim['id']),kind='defeat_guard',target_id=victim['id'])))
        events.append(e.event('VALAK_PROJECTION_RESOLVED',dict(player_id=pid,target=t,spend=spend,before=before,after=resources['life_essence'],victim=victim,whiff=not bool(victim),round=n)))
    elif power in WISHES:
        from .wishmaster import wish
        events.extend(wish(b,s))
    else: raise e.Unsupported('Unimplemented declared power '+power)
    from .development import reconcile
    reconcile(w)
    return dict(events=events,persistent_payload=payload)
