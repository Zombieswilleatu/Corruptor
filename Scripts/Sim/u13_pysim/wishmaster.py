"""Kanifous wishes, delayed Prices and neutral lamps. All choices are keyed."""
import math
import struct
from . import economy as e, recruitment as recruit
from .copying import copy_data
from .primitives import draw, instance_id


def event(kind,data):
    return e.event(kind,data,kind.replace('_',' ').title())


def record_loss(w, unit):
    if unit.get('kind') == 'marcher' and not any(row['id'] == unit['id'] for row in w['data']['kanifous_losses']):
        w['data']['kanifous_losses'].append(copy_data(unit))


def record_losses(w, events):
    for row in events:
        fact = row['event']; d = fact['data']; kind = fact['type']
        key = {'MARCHER_DEFEATED': 'victim', 'MARCHER_DEVOURED': 'before',
               'GRAVITY_ORB_CONSUMED': 'unit', 'WISHMASTER_REJECTED': 'unit'}.get(kind)
        if key: record_loss(w, d.get(key, {}))
        elif kind == 'KANIFOUS_WISH_RESOLVED' and d['power'] == 'WishDeath':
            for unit in d['victims']: record_loss(w, unit)


def wish(b,s):
    from .powers import members
    w,n,pid,t,power,key=b.w,b.number,s['player_id'],s['target'],s['power_id'],s['declaration_id'];count=0;victims=[];events=[]
    if power=='WishPower':
        roll=draw(b.seed,key,'WISH_COUNT',0,100)
        for i in range(1 if roll<70 else 2 if roll<95 else 3):
            suit=recruit.SUITS[draw(b.seed,key,'WISH_SUIT',i,4)];a=recruit.profile(suit,t['lane'],pid,n,n)
            r=recruit.create(w,key,i,pid,a);recruit.place_spawn(w,r,b.seed);count+=1
    elif power=='WishLongevity':
        r=e.entity(w,t['entity_id']);r['attributes'].update(integrity=r['attributes']['max_integrity'],status='standing',construction_state='active')
        if w['data']['construction_targets'][pid]==r['id']:w['data']['construction_targets'][pid]=''
        count=1
    elif power=='WishResurrection':
        for lost in w['data']['kanifous_losses']:
            if w['data']['kanifous_loss_round'] != n or lost['kind'] != 'marcher' or lost['owner'] != pid or lost['attributes']['lane'] != t['lane']: continue
            old = lost['attributes']; a = recruit.profile(old['suit'], t['lane'], pid, n, n+1)
            a.update(x_fp=old['x_fp'], y_fp=old['y_fp'])
            r = recruit.create(w, key, count, pid, a)
            recruit.place_near_spawn(w, r, a)
            events.append(event('MARCHER_RESURRECTED', dict(player_id=pid, before=lost, unit=r, round=n, hook='end_marching_checks')))
            count += 1
    elif power=='WishDeath':
        for key2 in members(w,t,100):victims.append(copy_data(e.entity(w,key2)));recruit.retire(w,key2);count+=1
    elif power=='WishWealth':
        roll=draw(b.seed,key,'WEALTH_COUNT',0,100)
        for i in range(1 if roll<20 else 2 if roll<70 else 3):count+=int(e.draw(w,pid,b.seed,key+':'+str(i))['drawn'])
    if count:
        price=dict(id=instance_id('price',key,'main'),owner=pid,created_round=n,due_round=n+1+draw(b.seed,key,'PRICE_DELAY',0,3))
        w['data']['kanifous_prices'].append(price);events.append(event('KANIFOUS_PRICE_SCHEDULED',price))
    events.append(event('KANIFOUS_WISH_RESOLVED',dict(player_id=pid,power=power,target=t,count=count,success=count>0,round=n,victims=victims)))
    record_losses(w, events)
    return events


def price(b,debt):
    w,n,pid=b.w,b.number,debt['owner'];weights=dict(Cards=30,Blood=30,Guards=15,Stone=15,Soul=5,Ruin=4,Wishmaster=1);groups={k:[] for k in weights}
    for r in w['entities']['entities']:
        if r['owner']!=pid:continue
        a=r['attributes']
        if r['kind']=='card':
            if r['id'] in e.zones(w)['hands'][pid]:groups['Cards'].append(r['id'])
            elif a.get('role')=='guard':groups['Guards'].append(r['id'])
        elif r['kind']=='marcher':groups['Blood'].append(r['id'])
        elif r['kind']=='castle' and a['status']=='standing' and a.get('construction_state','active')=='active':groups['Stone'].append(r['id']);groups['Ruin'].append(r['id'])
        elif r['kind']=='lord' and a['alive'] and a['lord_id']=='Kanifous':groups['Wishmaster'].append(r['id'])
    if w['players'][pid]['resources']['souls']>0:groups['Soul'].append(pid)
    pool=[k for k,weight in weights.items() if groups[k] for _ in range(weight)]
    if not pool:return True,[event('KANIFOUS_PRICE_DEFERRED',dict(id=debt['id'],outcome='Deferred',player_id=pid,round=n,due_round=n+1))]
    outcome=pool[draw(b.seed,debt['id'],'PRICE_OUTCOME',0,len(pool))];targets=sorted(groups[outcome]);chosen=[]
    for i in range(min(len(targets),2 if outcome in ('Cards','Blood') else 1)):chosen.append(targets.pop(draw(b.seed,debt['id'],'PRICE_TARGET',i,len(targets))))
    taken=[];events=[]
    for key in chosen:
        if type(key) is not str:continue
        r=e.entity(w,key);a=r['attributes']
        if r['kind']=='castle':label=f"{a.get('castle_type','Castle')} (slot {a.get('castle_slot',0)+1})"
        elif r['kind']=='lord':label=a.get('lord_id','Lord')
        else:label=f"{a.get('value','')} {a.get('suit','Card')} · {'Marcher' if r['kind']=='marcher' else a.get('role','card')} · {a.get('lane',a.get('guard_zone',''))}"
        taken.append(label)
    if outcome=='Cards':
        for key in chosen:e.zones(w)['hands'][pid].remove(key);e.zones(w)['discard'].append(key);e.entity(w,key)['owner']=-1
    elif outcome=='Blood':
        for key in chosen:
            record_loss(w, e.entity(w,key)); recruit.retire(w,key)
    elif outcome=='Soul':w['players'][pid]['resources']['souls']-=1
    elif outcome in ('Stone','Ruin'):
        r=e.entity(w,chosen[0]);a=r['attributes'];a['integrity']=max(0,a['integrity']-5) if outcome=='Stone' else 0;a['status']='standing' if a['integrity'] else 'defunct'
        if not a['integrity']:
            a['artillery_target']='';a['status']='ruined';events.append(event('CASTLE_RUINED',dict(player_id=pid,castle_id=r['id'],round=n,cause='Wish Price')))
    else:
        fact=b.fact(dict(command_id=debt['id'],kind='defeat_guard' if outcome=='Guards' else 'banish_lord',target_id=chosen[0]));reactions=b.react(fact)
        if outcome=='Wishmaster':
            breach=b.fact(dict(command_id=debt['id']+':breach',kind='set_breach',lord_id='Kanifous',source_id=chosen[0]));events.append(e.event(breach['type'],breach['data']))
        events.append(e.event(fact['type'],fact['data']));events.extend(reactions)
    if outcome in ('Stone','Soul','Ruin','Wishmaster'):w['data']['neutral_tears']+=1
    events.append(event('KANIFOUS_PRICE_RESOLVED',dict(id=debt['id'],outcome=outcome,targets=chosen,taken=taken,player_id=pid,round=n)))
    return False,events


def advance(b):
    w,n,hook=b.w,b.number,b.hook;rows=w['data']['kanifous_objects'];events=[]
    if hook=='round_start_automatic':
        w['data']['kanifous_losses']=[];w['data']['kanifous_loss_round']=n
        for pid in (0,1):
            if not b.active(pid,'Kanifous'):continue
            key=instance_id('wishmaster',str(pid),str(n));target=dict(lane=('Lord','Castle')[draw(b.seed,key,'SMOKE_LANE',0,2)],field_position=dict(x_fp=600+draw(b.seed,key,'SMOKE_X',0,1201),y_fp=180+draw(b.seed,key,'SMOKE_Y',0,241)))
            row=dict(id=key,owner=pid,phase='smoke',created_round=n,due_round=n+1,target=target);rows.append(row);events.append(event('WISHMASTER_SMOKE_CREATED',row))
    elif hook=='marching_start':
        for row in rows:
            if row['phase']!='smoke' or row['due_round']!=n:continue
            p=row['target']['field_position']
            for attempt in range(128):
                dx=draw(b.seed,row['id'],'LAMP_X',attempt,1081)-540;dy=draw(b.seed,row['id'],'LAMP_Y',attempt,1081)-540
                if dx*dx+dy*dy<=540*540 and 0<=p['x_fp']+dx<=2400 and 0<=p['y_fp']+dy<=600:p['x_fp']+=dx;p['y_fp']+=dy;break
            row['phase']='lamp';events.append(event('WISHMASTER_LAMP_SPAWNED',row))
    elif hook=='end_marching_checks':
        for row in rows:
            if row['phase']=='lamp':events.append(event('WISHMASTER_LAMP_EXPIRED',row))
        w['data']['kanifous_objects']=[r for r in rows if r['phase']=='smoke']
    if hook=='round_start_automatic':
        remaining=[]
        for debt in w['data']['kanifous_prices']:
            if debt['due_round']>n:remaining.append(debt);continue
            deferred,produced=price(b,debt);events.extend(produced)
            if deferred:remaining.append(debt)
        w['data']['kanifous_prices']=remaining
    return events


def ignored(s,i,j):
    return s.ids[j] in (s.extra[i] or {}).get('ghost_bypassed',[]) or s.ids[i] in (s.extra[j] or {}).get('ghost_bypassed',[])


def bypass(buffer,n,tick):
    # Every full world has the Kanifous profile. Ordinary ticks must not copy
    # every Marcher just to discover that none can use a ghost wish.
    if not buffer.has_ghost_wishes():return []
    events=[];units=buffer.rows()
    for source in units:
        u=buffer.get(source['id']);a=u['attributes']
        if a.get('ghost_wishes',0)==0:continue
        for other in units:
            b=other['attributes']
            if other['owner']==u['owner'] or b['lane']!=a['lane'] or other['id'] in a.get('ghost_bypassed',[]) or u['id'] in b.get('ghost_bypassed',[]) or (a['x_fp']-b['x_fp'])**2+(a['y_fp']-b['y_fp'])**2>180*180:continue
            a['ghost_wishes']-=1;a.setdefault('ghost_bypassed',[]).append(other['id']);a['waiting']=False;a['contact_tick']=-1;buffer.update(u['id'],u['owner'],a)
            events.append(event('WISHMASTER_VULTURE_BYPASS',dict(unit_id=u['id'],other_id=other['id'],round=n,tick=tick)))
            if not a['ghost_wishes']:break
    return events


def attack_amount(s,i):
    extra=s.extra[i]
    return s.attack[i]*(2 if extra and extra.pop('blood_wish',False) else 1)


def nearest_lamp(x,y,lane,rows):
    selected=None;best=180*180
    for row in rows:
        if row['phase']!='lamp' or row['target']['lane']!=lane:continue
        p=row['target']['field_position'];d=(x-p['x_fp'])**2+(y-p['y_fp'])**2
        if d<best or d==best and (selected is None or row['id']<selected['id']):selected=row;best=d
    return (selected['target']['field_position'],best) if selected else (None,best)


def f32(x):return struct.unpack('<f',struct.pack('<f',x))[0]


def contact_time(a,b,p):
    px,py=f32(a['x_fp']-p['x_fp']),f32(a['y_fp']-p['y_fp']);dx,dy=f32(b['x_fp']-a['x_fp']),f32(b['y_fp']-a['y_fp'])
    c=f32(f32(px*px)+f32(py*py))-65*65
    if c<=0:return 0.0
    length=f32(f32(dx*dx)+f32(dy*dy));dot=f32(f32(px*dx)+f32(py*dy));discriminant=dot*dot-length*c
    if length==0 or discriminant<0:return -1.0
    t=(-dot-math.sqrt(discriminant))/length
    return t if 0<=t<=1 else -1.0


def claim(rows,buffer,before,seed,n,tick):
    events=[];candidates=[]
    for lamp in rows:
        if lamp['phase']!='lamp':continue
        for old in before:
            unit=buffer.get(old['id'])
            if not unit or unit['attributes']['lane']!=lamp['target']['lane']:continue
            at=contact_time(old['attributes'],unit['attributes'],lamp['target']['field_position'])
            if at>=0:candidates.append((at,unit['id'],lamp['id'],lamp))
    candidates.sort(key=lambda r:r[:3]);used=set()
    for _,key,_,lamp in candidates:
        unit=buffer.get(key)
        if lamp['id'] in used or not unit:continue
        used.add(lamp['id']);info=dict(lamp_id=lamp['id'],unit=copy_data(unit),round=n,tick=tick,target=copy_data(lamp['target']));events.append(event('WISHMASTER_LAMP_CLAIMED',info))
        if draw(seed,lamp['id']+':'+key,'WISHMASTER_REJECTION',0,10)==0:buffer.retire_id(key);events.append(event('WISHMASTER_REJECTED',info));continue
        a=unit['attributes']
        if a['suit']=='Butcher':a['blood_wish']=True
        elif a['suit']=='Penitent':a['armor']+=2
        elif a['suit']=='Vulture':a['ghost_wishes']=2
        else:
            attrs=recruit.profile('Wright',a['lane'],unit['owner'],n,n);attrs.update(x_fp=a['x_fp'],y_fp=a['y_fp'])
            clone=buffer.spawn_near(lamp['id'],unit['owner'],attrs);events.append(event('WISHMASTER_WRIGHT_CREATED',dict(lamp_id=lamp['id'],unit=clone,round=n,tick=tick)))
        buffer.update(key,unit['owner'],a);events.append(event('WISHMASTER_WISH_GRANTED',info))
    rows[:]=[r for r in rows if r['id'] not in used]
    return events
