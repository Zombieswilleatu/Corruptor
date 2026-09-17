"""Deterministic monster abilities; mirror of the native rules, not animation time."""
from . import monsters as rules
from .copying import copy_data
from .primitives import draw, instance_id

T = rules.TUNING


def event(kind, data):
    fact = dict(type=kind, text='', data=copy_data(data))
    return dict(event=fact, views=[copy_data(fact), copy_data(fact)])


def distance(a, b):
    return (a['x_fp']-b['x_fp'])**2 + (a['y_fp']-b['y_fp'])**2


def enemies(unit, rows, radius=4000):
    return [r for r in rows if r['owner']!=unit['owner'] and r['attributes']['lane']==unit['attributes']['lane']
            and not r['attributes'].get('hidden',False) and distance(unit['attributes'],r['attributes'])<=radius**2]


def nearest(unit, rows, radius=4000):
    return min(enemies(unit,rows,radius),key=lambda r:distance(unit['attributes'],r['attributes']),default={})


def preferred(unit, rows):
    taunts=[r for r in enemies(unit,rows,T['taunt_radius']) if r['attributes'].get('monster_id')=='Kurchin']
    if taunts:return nearest(unit,taunts)
    a=unit['attributes']
    if a.get('monster_id')=='Tumler':
        return next((r for r in enemies(unit,rows) if r['id']==a.get('hunt_target','')), {})
    return {}


def slowed(a,fields):
    return not a.get('flying',False) and any(f['kind']=='pool' and f['lane']==a['lane'] and distance(a,f)<=T['pool_radius']**2 for f in fields)


def deaths(w,n,tick=-1):
    if not rules.enabled(w):return []
    state=w['data']['monsters'];events=[]
    for lost in w['data'].get('kanifous_losses',[]):
        a=lost['attributes']
        if a.get('monster_id')!='Lemek' or lost['id'] in state['death_ids']:continue
        state['death_ids'].append(lost['id'])
        f=dict(kind='pool',id=lost['id']+':pool',owner=lost['owner'],lane=a['lane'],x_fp=a['x_fp'],y_fp=a['y_fp'],expires_round=n+1)
        state['fields'].append(f);details=dict(field=f,round=n)
        if tick>=0:details['tick']=tick
        events.append(event('MONSTER_FIELD_CREATED',details))
    return events


def end_round(w,n):
    if not rules.enabled(w):return []
    events=[]
    for unit in w['entities']['entities']:
        a=unit['attributes']
        if unit['kind']!='marcher' or 'charm_owner' not in a:continue
        owner=a.pop('charm_owner');unit['owner']=owner
        a.update(direction=1 if owner==0 else -1,waiting=False,waiting_since_round=0,contact_tick=-1)
        events.append(event('MONSTER_CHARM_ENDED',dict(unit_id=unit['id'],owner=owner,round=n)))
    if events:w['data']['marching_duels']={}
    return events


def on_hit(buffer,source,target_id,damage,c,tick):
    target=buffer.get(target_id)
    if not target:return []
    name=source['attributes'].get('monster_id','');key=f"{source['id']}:{c['round']}:{tick}:{target_id}";a=target['attributes']
    if name=='Varn' and damage>0 and draw(c['seed'],key,'POISON',0,100)<T['varn_poison_chance']:
        credited=copy_data(source);credited['attributes'].pop('poison_source',None);credited['attributes'].pop('poison_until_round',None)
        a.update(poison_until_round=c['round']+2,poison_source=credited);buffer.update(target_id,target['owner'],a)
        return [event('MONSTER_POISONED',dict(unit_id=target_id,source_id=source['id'],round=c['round'],tick=tick))]
    if name=='Fyra' and 'charm_owner' not in a and draw(c['seed'],key,'CHARM',0,100)<T['fyra_charm_chance']:
        monster=a.get('monster_id','')
        if rules.limited(monster) and rules.living(buffer.rows(),source['owner'],monster):return []
        a.update(charm_owner=target['owner'],direction=1 if source['owner']==0 else -1,waiting=False,waiting_since_round=0,contact_tick=-1)
        buffer.update(target_id,source['owner'],a)
        return [event('MONSTER_CHARMED',dict(unit_id=target_id,source_id=source['id'],owner=source['owner'],round=c['round'],tick=tick))]
    return []


def step(w,buffer,c,tick,reaction):
    events=[]
    if not rules.enabled(w):return dict(action='resolved',world=w,events=events,fleeing={})
    state=w['data']['monsters'];n=c['round'];clock=n*200+tick;hits=[];fleeing={}
    if tick==0:
        state['phase_round']=n;state['fields']=[f for f in state['fields'] if f['expires_round']>=n]
        for unit in buffer.rows():
            a=unit['attributes']
            if a.get('poison_until_round',0)>=n:
                hits.append(dict(source=a['poison_source'],target=unit['id'],amount=1,bypass=True,ability='Poison'))
            elif 'poison_until_round' in a:
                del a['poison_until_round'];del a['poison_source']
            if not a.get('monster_id','') or a['movement_ready_round']>n:
                buffer.update(unit['id'],unit['owner'],a);continue
            key=f"{unit['id']}:{n}"
            if a['monster_id']=='Dotra':
                a['hidden']=draw(c['seed'],key,'HIDE',0,100)<(50 if a.get('hidden',False) else T['dotra_hide_chance'])
                events.append(event('MONSTER_CONCEALMENT',dict(unit_id=unit['id'],hidden=a['hidden'],round=n,tick=tick)))
            elif a['monster_id']=='Sooge':
                if a['sprite_form']!='turret' and a.get('sooge_root_round',0)<n:
                    chance=rules.root_chance(a)
                    a.update(sooge_root_attempts=a.get('sooge_root_attempts',0)+1,sooge_root_round=n)
                    if draw(c['seed'],key,'ROOT',0,100)<chance:
                        a.update(sprite_form='turret',attack=3,armor=6,max_armor=6,step_fp=0)
                        events.append(event('MONSTER_ROOTED',dict(unit_id=unit['id'],round=n,tick=tick)))
            elif a['monster_id']=='Sinodek':
                if draw(c['seed'],key,'PORTAL',0,100)<T['sinodek_portal_chance']:
                    f=dict(kind='portal',id=key+':portal',owner=unit['owner'],lane=a['lane'],x_fp=max(0,min(2400,a['x_fp']+a['direction']*T['portal_ahead'])),y_fp=a['y_fp'],expires_round=n)
                    state['fields'].append(f);events.append(event('MONSTER_FIELD_CREATED',dict(field=f,round=n)))
            buffer.update(unit['id'],unit['owner'],a)
    for original in buffer.rows():
        unit=buffer.get(original['id']);a=unit['attributes']
        if a['movement_ready_round']>n or 'monster_id' not in a:continue
        rows=buffer.rows();name=a['monster_id']
        if name=='Tumler':
            choices=enemies(unit,rows)
            if not any(r['id']==a.get('hunt_target','') for r in choices):
                supports=[r for r in choices if r['attributes']['suit']=='Vulture' or r['attributes'].get('monster_id') in ('Kopita','Fyra','Sooge','Sinodek')]
                a['hunt_target']=nearest(unit,supports or choices).get('id','')
        elif name=='Kopita' and tick==0:
            healing=a.get('kopita_pulses',0)%2==0;a['kopita_pulses']=a.get('kopita_pulses',0)+1
            for other in rows:
                b=other['attributes']
                if b['lane']!=a['lane'] or distance(a,b)>T['kopita_radius']**2:continue
                if healing and other['owner']==unit['owner']:
                    b['hp']=min(b['max_hp'],b['hp']+1)
                    if other['id']==unit['id']:a['hp']=b['hp']
                    buffer.update(other['id'],other['owner'],b)
                elif not healing and other['owner']!=unit['owner']:
                    hits.append(dict(source=unit,target=other['id'],amount=1,bypass=False,ability='Kopita'))
            events.append(event('MONSTER_PULSE',dict(unit_id=unit['id'],healing=healing,round=n,tick=tick)))
        elif name=='Muno' and a.get('muno_round',0)!=n:
            target=nearest(unit,rows,T['muno_radius'])
            if target:
                a['muno_round']=n;hits.append(dict(source=unit,target=target['id'],amount=a['attack'],bypass=False,ability='Muno'))
        elif name=='Dotra' and a.get('hidden',False):
            target=nearest(unit,rows,T['dotra_ambush_radius'])
            if target:
                a['hidden']=False;hits.append(dict(source=unit,target=target['id'],amount=5,bypass=False,ability='Ambush'))
        elif name=='Sooge' and a['sprite_form']=='turret' and a.get('beam_next_tick',0)<=clock:
            target=nearest(unit,rows,T['beam_range'])
            if target:
                vx=target['attributes']['x_fp']-a['x_fp'];vy=target['attributes']['y_fp']-a['y_fp'];length2=max(1,vx*vx+vy*vy)
                a['beam_next_tick']=clock+8
                events.append(event('MONSTER_BEAM_FIRED',dict(attacker=unit,target=target,range_fp=T['beam_range'],round=n,tick=tick)))
                for other in rows:
                    b=other['attributes']
                    if other['id']==unit['id'] or b['lane']!=a['lane']:continue
                    dx=b['x_fp']-a['x_fp'];dy=b['y_fp']-a['y_fp'];cross=dx*vy-dy*vx
                    if dx*vx+dy*vy>=0 and dx*dx+dy*dy<=T['beam_range']**2 and cross*cross<=T['beam_half_width']**2*length2:
                        hits.append(dict(source=unit,target=other['id'],amount=1 if other['owner']==unit['owner'] else 3,bypass=False,ability='Beam'))
        buffer.update(unit['id'],unit['owner'],a)
    for hit in hits:
        result=damage(w,buffer,hit,c,tick,reaction)
        if result['action']=='invalid':return result
        w=result['world'];events.extend(result['events'])
    state=w['data']['monsters']
    for f in state['fields']:
        if f['kind']!='portal':continue
        for unit in buffer.rows():
            a=unit['attributes']
            if a['lane']!=f['lane']:continue
            gap=distance(a,f)
            if gap<=T['portal_radius']**2:
                buffer.retire_id(unit['id']);events.append(event('MONSTER_BANISHED',dict(unit=unit,portal_id=f['id'],round=n,tick=tick)))
            elif gap<=T['portal_fear_radius']**2 and a['step_fp']>0 and a['movement_ready_round']<=n:
                dx=a['x_fp']-f['x_fp'];dy=a['y_fp']-f['y_fp']
                if abs(dx)>=abs(dy):a['x_fp']=max(0,min(2400,a['x_fp']+(1 if dx>=0 else -1)*a['step_fp']))
                else:a['y_fp']=max(0,min(600,a['y_fp']+(1 if dy>=0 else -1)*a['step_fp']))
                a['contact_tick']=-1;buffer.update(unit['id'],unit['owner'],a);fleeing[unit['id']]=True
    w['entities']=buffer.snapshot();events.extend(deaths(w,n))
    return dict(action='resolved',world=w,events=events,fleeing=fleeing)


def damage(w,buffer,hit,c,tick,reaction):
    events=[];target=buffer.get(hit['target'])
    if not target:return dict(action='resolved',world=w,events=events)
    before=copy_data(target);a=target['attributes'];absorbed=0 if hit['bypass'] else min(a['armor'],hit['amount']);dealt=hit['amount']-absorbed
    a['armor']-=absorbed;a['hp']=max(0,a['hp']-dealt);a['movement_ready_round']=min(a['movement_ready_round'],c['round'])
    if a['hp']==0:buffer.retire_id(target['id'])
    else:buffer.update(target['id'],target['owner'],a)
    events.append(event('MONSTER_ATTACK',dict(attacker=hit['source'],target=before,ability=hit['ability'],damage_dealt=dealt,hp_after=a['hp'],round=c['round'],tick=tick)))
    w['entities']=buffer.snapshot()
    if a['hp']==0:
        fact=event('MARCHER_DEFEATED',dict(event_id=instance_id('monster_kill',f"{c['round']}:{tick}:{hit['source']['id']}",target['id']),round=c['round'],hook='marching',tick=tick,victim=before,attacker=hit['source'],cause='combat',damage_dealt=dealt))['event']
        events.append(dict(event=fact,views=[copy_data(fact),copy_data(fact)]))
        result=reaction(w,fact,c['seed'],c['player_order']) if reaction else dict(action='resolved',world=w,events=[])
        if result.get('action')!='resolved':return dict(action='invalid',reason='monster_reaction_invalid')
        w=result['world'];events.extend(result['events']);buffer.restore(w['entities'])
    return dict(action='resolved',world=w,events=events)


def steer(unit,destination,rows,fields):
    a=unit['attributes']
    if a.get('monster_id')!='Tumler' or not destination:return destination
    obstacles=[dict(x_fp=r['attributes']['x_fp'],y_fp=r['attributes']['y_fp'],radius=180) for r in enemies(unit,rows,340)
               if r['id']!=a.get('hunt_target','') and distance(r['attributes'],destination)!=0]
    obstacles.extend(dict(x_fp=f['x_fp'],y_fp=f['y_fp'],radius=240) for f in fields
                     if f['kind']=='pool' and f['lane']==a['lane'] and distance(a,f)<=400*400)
    for obstacle in obstacles:
        if (obstacle['x_fp']-a['x_fp'])*(destination['x_fp']-a['x_fp'])<0 or abs(obstacle['y_fp']-a['y_fp'])>=obstacle['radius']:continue
        side=-1 if a['y_fp']<=obstacle['y_fp'] else 1
        y=max(30,min(570,obstacle['y_fp']+side*obstacle['radius']))
        if abs(y-obstacle['y_fp'])<obstacle['radius']//2:y=max(30,min(570,obstacle['y_fp']-side*obstacle['radius']))
        return dict(x_fp=obstacle['x_fp'],y_fp=y)
    return destination
