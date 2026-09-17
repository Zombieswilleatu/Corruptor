"""Permanent absent-Lord arrivals, public protection and round-start erosion."""
from .primitives import draw
from . import economy as e
from .copying import copy_data

VERSION = 'U13_PERMANENT_BREACHES_V1'
LORDS = ('Gremory','Deimos','Humbaba','Kalligan','Orias','Odradek','Kroni','Valak','Kanifous')
THRESHOLDS = (5,9,13,17)
BENEFICIAL = ('Gremory','Kalligan','Kanifous')


def configure(w):
    w['data']['veil_breaches'] = dict(version=VERSION,arrivals=[],checked_round=0,veil_21_round=0,cascade_round=0,round_history=[])


def total(w):
    return w['data']['neutral_tears'] + sum(p['resources']['personal_tears'] for p in w['players'])


def arrival(w,lord):
    return next((r for r in w['data'].get('veil_breaches',{}).get('arrivals',[]) if r['lord_id']==lord),{})


def active(w,lord):
    return w['data'].get('breach_lord','')==lord or bool(arrival(w,lord))


def protected(w,lord,pid):
    row=arrival(w,lord)
    return bool(row and row['protection']>0 and w['players'][pid]['resources']['personal_tears']>=row['protection'])


def affects(w,lord,pid):
    if w['data'].get('breach_lord','')==lord:return True
    return bool(arrival(w,lord)) and not protected(w,lord,1-pid if lord in BENEFICIAL else pid)


def affected_players(w,lord):
    return [affects(w,lord,pid) for pid in (0,1)]


def applies_to(effect,pid):
    return effect[pid] if isinstance(effect,(list,tuple)) else effect


def source_valid(w,key):
    return key=='veil:Humbaba' and bool(arrival(w,'Humbaba'))


def observe(w,n):
    state=w['data'].get('veil_breaches')
    if state is not None and total(w)>=21 and state['veil_21_round']==0:state['veil_21_round']=n


def begin(w,n,seed):
    state=w['data'].get('veil_breaches')
    if state is None or w['data'].get('victory',{}).get('winner',-1)!=-1 or state['checked_round']>=n:return []
    state['checked_round']=n;observe(w,n)
    available=[lord for lord in LORDS if lord not in [p['lord_id'] for p in w['players']] and not arrival(w,lord)]
    admitted=[]
    while available:
        i=len(state['arrivals']);cascade=i>=len(THRESHOLDS)
        if (cascade and (total(w)<21 or n<21)) or (not cascade and total(w)<THRESHOLDS[i]):break
        row=dict(lord_id=available.pop(draw(seed,VERSION,'arrival',i,len(available))),threshold=21 if cascade else THRESHOLDS[i],protection=0 if cascade else i+1,round=n,veil=total(w))
        state['arrivals'].append(row);admitted.append(copy_data(row))
        if cascade:state['cascade_round']=n
    return admitted


def begin_effects(b):
    from .battle import targetable
    w,n=b.w,b.number
    if 'veil_breaches' not in w['data']:return []
    admitted=begin(w,n,b.seed);events=[]
    for row in admitted:
        detail=copy_data(row);detail['protected_players']=[protected(w,row['lord_id'],pid) for pid in (0,1)]
        events.append(e.event('VEIL_LORD_ARRIVED',detail))
    events.extend(b.sync_breach())
    source='';entry_round=0;entry=arrival(w,'Humbaba')
    if entry:source='veil:Humbaba';entry_round=entry['round']
    elif w['data'].get('breach_lord','')=='Humbaba':
        for lord in w['entities']['entities']:
            if lord['kind']=='lord' and lord['attributes'].get('lord_id')=='Humbaba' and not lord['attributes']['alive']:source=lord['id']
        entry_round=max(w['data']['humbaba_breach_entries'].values(),default=0)
    if not source or not entry_round:return events
    fresh=any(row['lord_id']=='Humbaba' for row in admitted)
    if not fresh and entry_round>=n:return events
    damage=4 if fresh else 1;key=f'stones:{n}:{source}'
    targets=sorted(c['id'] for c in w['entities']['entities'] if targetable(c) and c['attributes']['integrity']>0 and affects(w,'Humbaba',c['owner']))
    for identity in targets:events.extend(b.breach_damage(identity,source,key,damage))
    events.append(e.event('THE_STONES_FORGET',dict(source_id=source,entry_id=key,round=n,castle_ids=targets,damage_per_castle=damage)))
    return events


def finish(w,n):
    if 'veil_breaches' not in w['data']:return
    observe(w,n)
    w['data']['veil_breaches']['round_history'].append(dict(round=n,veil=total(w),kanifous_active=active(w,'Kanifous'),arrivals=len(w['data']['veil_breaches']['arrivals']),winner=w['data']['victory']['winner']))
