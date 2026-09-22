"""Fixed guard arena; keyed initial allegiance bias, first physical collision."""
from .primitives import draw
from .kroni_actors import touches

MODE='guard_bounce'
TARGET={'mode':MODE}
VELOCITIES=((31,7),(29,13),(23,19),(19,23),(13,29),(7,31))
LIMIT=2048

def guards(w):
    return sorted((r for r in w['entities']['entities'] if r['kind']=='card' and r['attributes'].get('role')=='guard'),key=lambda r:r['id'])

def point(row):
    a=row['attributes'];slot=a['slot']
    return [80,640+130*slot if row['owner']==0 else 100+130*slot] if a['lane']=='Lord' else [720+100*slot,590 if row['owner']==0 else 410]

def route(rows, vx, vy):
    x,y=450,500;path=[[x,y]]
    for tick in range(LIMIT):
        ax,ay=x,y;nx,ny=x+vx,y+vy;bounce=False
        if nx<0 or nx>1000:nx=-nx if nx<0 else 2000-nx;vx=-vx;bounce=True
        if ny<0 or ny>1000:ny=-ny if ny<0 else 2000-ny;vy=-vy;bounce=True
        hits=[r for r in rows if touches(ax,ay,nx,ny,*point(r),45)]
        x,y=nx,ny
        if hits:
            hit=min(hits,key=lambda r:((point(r)[0]-ax)**2+(point(r)[1]-ay)**2,r['id']))
            path.append([x,y])
            return dict(victim_id=hit['id'],path=path,ticks=tick+1)
        if bounce:path.append([x,y])
    path.append([x,y])
    return dict(victim_id='',path=path,ticks=LIMIT)

def choose(w,pid,seed,key):
    enemy_first=draw(seed,key,'CONSUME_ENEMY_DIRECTION',0,100)<60
    side=1-pid if enemy_first else pid
    vx,vy=VELOCITIES[draw(seed,key,'CONSUME_ANGLE',0,len(VELOCITIES))]
    if draw(seed,key,'CONSUME_HORIZONTAL',0,2)==0:vx=-vx
    if side==1:vy=-vy
    rows=guards(w)
    result=route(rows,vx,vy) if rows else dict(victim_id='',path=[[450,500]],ticks=0)
    result.update(initial_enemy=enemy_first,initial_velocity=[vx,vy],mode=MODE)
    return result
