"""Kroni's owned Hunger state and integer swept actors, separate from doctrine."""
import math
from . import economy as e
from .copying import copy_data
from .primitives import draw, instance_id
from .recruitment import retire
from .marching_spatial import half_away


def feed(w,pid,amount,n,cause):
    a=e.entity(w,w['players'][pid]['lord_entity_id'])['attributes'];before=a['hunger'];after=max(0,min(1000000,before+amount));a['hunger']=after
    events=[e.event('KRONI_HUNGER_CHANGED',dict(player_id=pid,before=before,after=after,round=n,cause=cause),f'{cause}: Hunger {before} → {after}.')]
    if after>=3 and not a['hunger_milestone']:
        a['hunger_milestone']=True;w['players'][pid]['resources']['personal_tears']+=1
        events.append(e.event('KRONI_HUNGER_MILESTONE',dict(player_id=pid,round=n,amount=1),'Hunger: +1 personal Tear (once per game).'))
    return events


def devour_guard(w,victim,pid,n,cause):
    before=copy_data(victim);retire(w,victim['id'])
    return e.event('GUARD_DEVOURED',dict(before=before,player_id=pid,round=n,cause=cause),f"{cause} devours {before['attributes']['suit']} {before['attributes']['value']}.")


def touches(ax,ay,bx,by,px,py,r):
    dx,dy=bx-ax,by-ay;qx,qy=px-ax,py-ay;dot=qx*dx+qy*dy;length=dx*dx+dy*dy
    if dot<=0 or length==0: return qx*qx+qy*qy<=r*r
    if dot>=length: return (px-bx)**2+(py-by)**2<=r*r
    return (qx*dy-qy*dx)**2<=r*r*length


def weighted(routes,seed,key,purpose):
    roll=draw(seed,key,purpose,0,sum(16+v*v for v in routes))
    for v in routes:
        roll-=16+v*v
        if roll<0:return v
    return routes[-1]


def path(ax,ay,bx,by):
    if 0<=by<=1200:return by,[[ax,ay,bx,by]],False
    wall=0 if by<0 else 1200
    contact=ax+half_away(float(bx-ax)*float(wall-ay)/float(by-ay));by=-by if by<0 else 2400-by
    return by,[[ax,ay,contact,wall],[contact,wall,bx,by]],True


def favored(actor,units):
    enemies=[u for u in units if u['kind']=='marcher' and u['owner']==1-actor['owner']];routes=[]
    if len(enemies)<2:return routes
    for side in (-1,1):
        for magnitude in range(1,25):
            x,y,vy=actor['x_fp'],actor['y_fp'],side*magnitude;hit=set()
            for tick in range(200):
                bx=max(0,min(2400,x+actor['vx_fp']));by,segments,bounce=path(x,y,bx,y+vy)
                if bounce:vy=-vy
                for u in enemies:
                    a=u['attributes'];lateral=a['y_fp']+(600 if a['lane']=='Castle' else 0)
                    if u['id'] not in hit and any(touches(*s,a['x_fp'],lateral,actor['radius_fp']) for s in segments): hit.add(u['id'])
                if len(hit)>=2:routes.append(side*magnitude);break
                x,y=bx,by
                if x==(2400 if actor['owner']==0 else 0):break
    return routes


def create(identity,pid,n,hunger,breach=False,seed='kroni-actor-fixture',start=None,units=()):
    actor=dict(id=identity,owner=pid,round=n,breach=breach,x_fp=0 if pid==0 else 2400,y_fp=300,
               vx_fp=16 if pid==0 else -16,vy_fp=1,radius_fp=half_away(220*[1.0,1.1,1.2,1.35][max(0,min(3,hunger))]),
               hunger=hunger,age=0,active=True,consumed=0,rewarded=False,fleeing={},nearby=[],fled_this_tick=[],launch_mode='breach' if breach else 'random')
    if not breach:
        if start: actor['y_fp']=start['field_position']['y_fp']+(600 if start['lane']=='Castle' else 0)
        key=instance_id(identity,str(n),'ravenous_launch')
        actor['vy_fp']=weighted(range(1,25),seed,key,'RAVENOUS_ANGLE')*(-1 if draw(seed,key,'RAVENOUS_SIDE',0,2)==0 else 1)
        if draw(seed,identity+':'+str(n),'RAVENOUS_BIAS',0,4)<3:
            actor['launch_mode']='fallback';candidates=favored(actor,units)
            if candidates: actor['launch_mode']='favored';actor['vy_fp']=weighted(candidates,seed,identity+':'+str(n),'RAVENOUS_FAVORED_ROUTE')
    else:
        actor['x_fp']=draw(seed,identity,'BREACH_FORWARD',0,2401);actor['y_fp']=draw(seed,identity,'BREACH_LATERAL',0,1201)
        actor['vx_fp'],actor['vy_fp']=[[24,0],[17,17],[0,24],[-17,17],[-24,0],[-17,-17],[0,-24],[17,-17]][draw(seed,identity,'BREACH_DIRECTION',0,8)]
    return actor


def flee_slice(actor,buffer,ms,collapse):
    changes=[]
    for identity in list(actor['fleeing']):
        unit=buffer.get(identity)
        if not unit:del actor['fleeing'][identity];continue
        state=actor['fleeing'][identity];a=copy_data(unit['attributes']);origin=600 if a['lane']=='Castle' else 0
        lateral=a['y_fp']+origin;dx=a['x_fp']-actor['x_fp'];dy=lateral-actor['y_fp'];reach=actor['radius_fp']*2
        if actor['active'] and dx*dx+dy*dy<=reach*reach:state['remaining_ms']=1100
        duration=min(ms,state['remaining_ms'])
        if dx==dy==0:dx,dy=[[1,0],[1,1],[0,1],[-1,1],[-1,0],[-1,-1],[0,-1],[1,-1]][draw(actor['id'],unit['id'],'FLEE_OVERLAP',0,8)]
        length=math.sqrt(float(dx*dx+dy*dy));distance=float(a['step_fp']*30*duration)/float(100*30)
        if collapse:distance*=0.5
        mx=float(dx)/length*distance+float(state['carry_x']);my=float(dy)/length*distance+float(state['carry_y'])
        sx,sy=half_away(mx),half_away(my);state['carry_x'],state['carry_y']=mx-sx,my-sy
        a['x_fp']=max(0,min(2400,a['x_fp']+sx));a['y_fp']=max(origin,min(origin+600,lateral+sy))-origin;a['contact_tick']=-1
        if a['x_fp']!=(2400 if unit['owner']==0 else 0):a.update(waiting=False,waiting_since_round=0)
        buffer.update(identity,unit['owner'],a);state['unit']=buffer.get(identity)
        changes.append(dict(before=unit,after=state['unit'],duration_ms=duration));state['remaining_ms']-=duration
        if state['remaining_ms']<=0:del actor['fleeing'][identity]
    return changes


def flee(actor,buffer,ms,collapse):
    merged={};remaining=ms
    while remaining>0 and actor['fleeing']:
        step=min(30,remaining)
        for change in flee_slice(actor,buffer,step,collapse):
            key=change['before']['id']
            if key not in merged:merged[key]=change
            else:merged[key]['after']=change['after'];merged[key]['duration_ms']+=change['duration_ms']
        remaining-=step
    return list(merged.values())


def notice(actor,buffer):
    nearby=[];started=[];reach=actor['radius_fp']*2
    for u in buffer.rows():
        a=u['attributes'];dy=a['y_fp']+(600 if a['lane']=='Castle' else 0)-actor['y_fp'];dx=a['x_fp']-actor['x_fp']
        if dx*dx+dy*dy>reach*reach or a['step_fp']==0:continue
        key=u['id'];nearby.append(key)
        if key in actor['fleeing']:actor['fleeing'][key]['remaining_ms']=1100;continue
        actor['fleeing'][key]=dict(remaining_ms=1100,carry_x=0.0,carry_y=0.0,unit=u);started.append(key)
    actor['nearby']=nearby
    return started


def step(actors,buffer,n,tick,collapse):
    events=[]
    for actor in actors:
        actor['fled_this_tick']=list(actor['fleeing']);flee(actor,buffer,30,collapse)
        if not actor['active']:continue
        ax,ay=actor['x_fp'],actor['y_fp'];bx=max(0,min(2400,ax+actor['vx_fp']));by,segments,bounce=path(ax,ay,bx,ay+actor['vy_fp'])
        if bounce:actor['vy_fp']=-actor['vy_fp'];events.append(e.event('KRONI_WALL_BOUNCE',dict(actor_id=actor['id'],round=n,tick=tick)))
        actor['x_fp'],actor['y_fp']=bx,by;actor['age']+=1
        started=notice(actor,buffer)
        if started:events.append(e.event('KRONI_FLEE_STARTED',dict(actor_id=actor['id'],units=started,round=n,tick=tick,duration_ms=1100)))
        for unit in buffer.rows():
            a=unit['attributes'];lateral=a['y_fp']+(600 if a['lane']=='Castle' else 0)
            if any(touches(*s,a['x_fp'],lateral,actor['radius_fp']) for s in segments):
                buffer.retire_id(unit['id']);actor['consumed']+=1;actor['fleeing'].pop(unit['id'],None);bite=copy_data(actor)
                fled=flee(actor,buffer,550,collapse)
                events.append(e.event('MARCHER_DEVOURED',dict(actor_id=actor['id'],actor=bite,before=unit,round=n,tick=tick,breach=actor['breach'],flee=fled,chomp_ms=550),'Insatiable Hunger devours a Marcher.' if actor['breach'] else 'Ravenous devours a Marcher.'));break
        if actor['breach']:
            if bx in (0,2400):actor['vx_fp']=-actor['vx_fp']
            actor['active']=actor['age']<33
        else:actor['active']=bx!=(2400 if actor['owner']==0 else 0)
        if not actor['active']:events.append(e.event('KRONI_ACTOR_FINISHED',dict(actor=actor,round=n,tick=tick)))
    return events
