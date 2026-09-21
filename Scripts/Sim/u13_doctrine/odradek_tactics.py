"""Public field-value estimates and bounded target samples for Odradek."""
from u13_pysim import monsters, recruitment
from u13_pysim.copying import copy_data
from .facts import LANES
from .orias_tactics import _support


def inside(row,target,radius):
    a,p=row['attributes'],target['field_position']
    return a['lane']==target['lane'] and (a['x_fp']-p['x_fp'])**2+(a['y_fp']-p['y_fp'])**2<=radius*radius


def strength(row):
    a=row['attributes'];hp=a['hp'];cap=max(1,a.get('max_hp',hp));health=min(hp,cap)
    ability=(3 if a.get('monster_id') in ('Kopita','Fyra','Sinodek','BottleTree') else
             2 if a.get('monster_id') in ('Kurchin','Muno','Lemek','Tumler','Dotra','Sooge') else 0)
    ability+=int(a.get('flying',False))+int(a.get('suit')=='Vulture')+min(2,a.get('regen',0))
    return 3+min(6,hp)+min(3,a.get('armor',0))+(min(4,2*a.get('attack',0))+min(4,ability))*health//cap


def field(f,ctx=None):
    rows=[]
    for lane in LANES:
        rows.extend(_support(f,lane,ctx));rows.extend(f.units(f.enemy,lane))
        if ctx:
            for i in range(ctx['power_bodies_minimum'].get(lane,0)):
                a=recruitment.profile('Butcher',lane,f.pid,f.v['round'],f.v['round']+1)
                a.update(x_fp=60 if f.pid==0 else 2340,y_fp=300)
                rows.append(dict(id='odradek_power_body:'+lane+str(i),kind='marcher',owner=f.pid,attributes=a,planned=True))
    return sorted(copy_data(rows),key=lambda r:r['id'])


def redirect(rows,target):
    moved=[]
    for r in rows:
        if inside(r,target,300):
            r['attributes']['lane']='Castle' if r['attributes']['lane']=='Lord' else 'Lord'
            r['attributes']['contact_tick']=-1
            moved.append(r['id'])
    return moved


def quality(f,rows):
    # Six fixed forward bands keep work linear in army size. Nearby friendly
    # support can contest a threat; a distant army cannot cancel gate pressure.
    cells={lane:[[0,0] for _ in range(6)] for lane in LANES}
    for r in rows:
        a=r['attributes'];index=min(5,max(0,a['x_fp']//400))
        cells[a['lane']][index][r['owner']]+=strength(r)
    risks=[{},{}]
    for defender in (0,1):
        for lane in LANES:
            total=0
            for index,cell in enumerate(cells[lane]):
                support=cell[defender]
                for adjacent in (index-1,index+1):
                    if 0<=adjacent<6:support+=cells[lane][adjacent][defender]//2
                distance=index if defender==0 else 5-index
                urgency=3 if distance==0 else 2 if distance<=2 else 1
                total+=max(0,cell[1-defender]-support)*urgency
            risks[defender][lane]=total
    danger=max(risks[f.pid].values());pressure=max(risks[f.enemy].values())
    return dict(score=pressure//4-danger//2,danger=danger,pressure=pressure)


def redirect_value(f,target,rows=None):
    rows=field(f) if rows is None else copy_data(rows)
    before=quality(f,rows);moved=redirect(rows,target);after=quality(f,rows)
    return dict(score=after['score']-before['score'],eligible_after=moved,
                pressure_before=before['danger'],pressure_after=after['danger'],
                attack_before=before['pressure'],attack_after=after['pressure'],
                reason='redirect_improves_position' if after['score']>before['score'] else 'redirect_only_relocates_pressure' if after['score']==before['score'] else 'redirect_worsens_position')


def capture(f,rows,target):
    captured=[];blocked=[]
    for r in sorted(rows,key=lambda r:r['id']):
        if r['owner']!=f.enemy or not inside(r,target,180):continue
        name=r['attributes'].get('monster_id','')
        if monsters.limited(name) and monsters.living(rows,f.pid,name,r['id']):
            blocked.append(r['id']);continue
        r['owner']=f.pid
        r['attributes'].update(direction=1 if f.pid==0 else -1,waiting=False,waiting_since_round=0,contact_tick=-1)
        captured.append(r['id'])
    return captured,blocked


def shift_value(f,target,rows=None):
    rows=field(f) if rows is None else copy_data(rows)
    before=quality(f,rows);ids,blocked=capture(f,rows,target)
    material=2*sum(strength(r) for r in rows if r['id'] in ids)
    positional=(quality(f,rows)['score']-before['score'])//2
    return dict(score=material+positional,material=material,position=positional,
                eligible_after=ids,blocked_limited=blocked,reason='steal_health_abilities_and_position')


def targets(f,lane,name):
    rows=field(f);candidates=[r for r in rows if r['attributes']['lane']==lane and
                            (name=='Redirect' or r['owner']==f.enemy)]
    if not candidates:return
    ordered=sorted(candidates,key=lambda r:(r['attributes']['x_fp'],r['attributes']['y_fp'],r['id']))
    sample=[ordered[i*(len(ordered)-1)//5] for i in range(6)]
    sample.append(min(candidates,key=lambda r:(-strength(r),r['id'])))
    points={(r['attributes']['x_fp'],r['attributes']['y_fp']) for r in sample}
    points.add((sum(r['attributes']['x_fp'] for r in candidates)//len(candidates),sum(r['attributes']['y_fp'] for r in candidates)//len(candidates)))
    evaluate=shift_value if name=='AllegianceShift' else redirect_value
    scored=[]
    for x,y in sorted(points):
        target=dict(lane=lane,field_position=dict(x_fp=x,y_fp=y));value=evaluate(f,target,rows)
        if value['eligible_after']:scored.append((value['score'],x,y,target,value))
    seen=set();retained=0
    for _,_,_,target,value in sorted(scored,key=lambda r:(-r[0],r[1],r[2])):
        identity=tuple(value['eligible_after'])
        if identity in seen:continue
        seen.add(identity);yield target,value
        retained+=1
        if retained==2:return
