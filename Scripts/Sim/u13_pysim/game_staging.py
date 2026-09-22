"""Protected full-game recruitment; same lane-local rule as U13LaneStaging."""
from . import economy as e
from .copying import copy_data

VERSION = 'U13_GAME_STAGING_V3_CAP'
MANUAL_VERSION = 'U13_GAME_STAGING_V2_MANUAL'
LEGACY_VERSION = 'U13_GAME_STAGING_V1'
LANES = ('Lord', 'Castle')
MODES = ('Auto', 'Hold', 'March')


def configure(w):
    w['data']['game_staging'] = dict(version=VERSION, lanes={lane: dict(
        version='U13_LANE_STAGING_V1', capacity=15, units=[], decisions=[], prepared_round=0, march_round=[0, 0]) for lane in LANES})


def enabled(w):
    return w.get('data', {}).get('game_staging', {}).get('version') in (VERSION, MANUAL_VERSION, LEGACY_VERSION)


def rows(w):
    return [u for tray in w.get('data', {}).get('game_staging', {}).get('lanes', {}).values() for u in tray['units']]


def order_valid(w, order):
    if 'staging_ids' in order:
        ids=order['staging_ids']
        if 'staging' not in order or type(ids) is not dict: return False
        for lane, selected in ids.items():
            if lane not in LANES or type(selected) is not list or any(type(uid) is not str for uid in selected) or len(set(selected)) != len(selected): return False
    if 'staging' not in order: return True
    return (enabled(w) and type(order['staging']) is dict
            and all(k in LANES and v in MODES for k, v in order['staging'].items()))


def deploy(w, tray, chosen, n):
    chosen.sort(key=lambda u: (rank(u),u['id']))
    for i,u in enumerate(chosen):
        column,row=i%10,i//10
        u['attributes'].update(x_fp=max(0,100-row*60) if u['owner']==0 else min(2400,2300+row*60),
            y_fp=(column+1)*600//(min(10,len(chosen)-row*10)+1),movement_ready_round=n,deployed_round=n)
        tray['units'].remove(u)
        w['entities']['entities'].append(u)


def make_room(w, tray, pid, n, incoming):
    needed=max(0,sum(u['owner']==pid for u in tray['units'])+min(incoming,tray['capacity'])-tray['capacity'])
    if needed==0:return []
    ready=sorted((u for u in tray['units'] if u['owner']==pid and u['attributes']['staged_round']<n),key=lambda u:(u['attributes']['staged_round'],u['id']))
    chosen=ready[:needed]
    deploy(w,tray,chosen,n)
    return [u['id'] for u in chosen]


def overflow_event(lane,pid,n,ids):
    return e.event('STAGING_OVERFLOW_RELEASED',dict(round=n,lane=lane,player_id=pid,unit_ids=ids,capacity=15))


def upgrade_if_bounded(w):
    if all(sum(u['owner']==pid for u in tray['units'])<=tray['capacity'] for tray in w['data']['game_staging']['lanes'].values() for pid in (0,1)):
        for tray in w['data']['game_staging']['lanes'].values():tray.setdefault('march_round',[0,0])
        w['data']['game_staging']['version']=VERSION


def enforce_capacity(w,n):
    events=[]
    for lane in LANES:
        tray=w['data']['game_staging']['lanes'][lane]
        for pid in (n%2,1-n%2):
            released=make_room(w,tray,pid,n,0)
            if released:events.append(overflow_event(lane,pid,n,released))
    w['entities']['entities'].sort(key=lambda u:u['id'])
    upgrade_if_bounded(w)
    return events


def capture(w, events, n):
    if not enabled(w): return []
    ids={r['event']['data']['id'] for r in events if r['event']['type']=='MARCHER_SPAWNED'}
    stored=[];rejected=[];additions=[]
    for lane in LANES:
        tray=w['data']['game_staging']['lanes'][lane]
        for pid in (n%2,1-n%2):
            incoming=sorted((u for u in w['entities']['entities'] if u['kind']=='marcher' and u['attributes']['lane']==lane and u['owner']==pid and u['id'] in ids),key=lambda u:('monster_id' not in u['attributes'],u['id']))
            released=make_room(w,tray,pid,n,len(incoming))
            if released:additions.append(overflow_event(lane,pid,n,released))
            room=max(0,tray['capacity']-sum(u['owner']==pid for u in tray['units']))
            admitted=incoming[:room];excess=[u['id'] for u in incoming[room:]]
            for u in admitted:
                u['attributes'].update(staged_round=n,birth_round=n,movement_ready_round=n+1)
            admitted_ids={u['id'] for u in admitted}
            tray['units'].extend(u for u in w['entities']['entities'] if u['id'] in admitted_ids)
            stored.extend(u['id'] for u in admitted);rejected.extend(excess)
            remove={u['id'] for u in incoming}
            w['entities']['entities']=[u for u in w['entities']['entities'] if u['id'] not in remove]
            if excess:additions.append(e.event('STAGING_RECRUITMENT_CAPPED',dict(round=n,lane=lane,player_id=pid,count=len(excess),capacity=15)))
    events[:]=[r for r in events if r['event']['type']!='MARCHER_SPAWNED' or r['event']['data']['id'] not in rejected]
    for row in events:
        if row['event']['type']=='MONSTER_SUMMONED':
            for fact in [row['event']]+row['views']:
                fact['data']['unit_ids']=[uid for uid in fact['data']['unit_ids'] if uid not in rejected]
    events[:]=[r for r in events if r['event']['type']!='MONSTER_SUMMONED' or r['event']['data']['unit_ids']]
    if stored:additions.append(e.event('RECRUITS_STAGED',dict(round=n,unit_ids=stored)))
    w['entities']['entities'].sort(key=lambda u:u['id'])
    upgrade_if_bounded(w)
    return additions


def strength(units, opponents):
    butchers = sum(u['attributes']['suit'] == 'Butcher' for u in opponents)
    return sum((u['attributes']['hp']+u['attributes']['armor']) * (u['attributes']['attack']+1+
               int(u['attributes']['suit'] == 'Vulture' and butchers*2 >= max(1,len(opponents)))) for u in units)


def decision(field, tray, pid, n, mode):
    ready = [u for u in tray['units'] if u['owner'] == pid and u['attributes']['staged_round'] < n]
    local = [u for u in field if (u['attributes']['x_fp'] if pid == 0 else 2400-u['attributes']['x_fp']) <= 1800
             and not u['attributes']['waiting'] and not u['attributes'].get('hidden',False)]
    enemies, allies = [u for u in local if u['owner'] != pid], [u for u in local if u['owner'] == pid]
    force, pressure = strength(ready+allies,enemies), strength(enemies,ready+allies)
    release = bool(ready) and (mode == 'March' or (mode == 'Auto' and (force*5 >= pressure*4 or len(ready) >= tray['capacity'])))
    reason = 'New units wait one full round.' if not ready else 'Holding by choice.'
    if release: reason = 'March: reserves full.' if mode == 'Auto' and len(ready) >= tray['capacity'] else 'March: force ready.'
    elif mode == 'Auto' and ready: reason = f'Holding for reinforcements: pressure {pressure} / force {force}.'
    return dict(owner=pid, release=release, reason=reason, force=force, pressure=pressure, released=0, overflow=0)


def rank(u):
    a=u['attributes']
    if a['suit'] == 'Penitent' or a.get('monster_id') in ('Lemek','Kurchin'): return 0
    if a['suit'] == 'Vulture' or a.get('monster_id') in ('Kopita','Sooge','Sinodek'): return 2
    return 1


def release_due(w, n):
    if not enabled(w): return []
    events = enforce_capacity(w,n)
    for lane in LANES:
        tray = w['data']['game_staging']['lanes'][lane]
        due = list(tray.get('march_round', [0, 0]))
        if not any(0 < value <= n for value in due): continue
        decisions = [dict(owner=pid, release=0 < due[pid] <= n, reason='Waiting for MARCH.',
                          force=0, pressure=0, released=0, overflow=0) for pid in (0, 1)]
        for pid in (n % 2, 1 - n % 2):
            if not decisions[pid]['release']: continue
            chosen = sorted((u for u in tray['units'] if u['owner'] == pid and u['attributes']['staged_round'] < n), key=lambda u: (rank(u), u['id']))
            for i, u in enumerate(chosen):
                column, row = i % 10, i // 10
                u['attributes'].update(x_fp=max(0, 100-row*60) if pid == 0 else min(2400, 2300+row*60),
                    y_fp=(column+1)*600//(min(10, len(chosen)-row*10)+1), movement_ready_round=n, deployed_round=n)
                tray['units'].remove(u)
                w['entities']['entities'].append(u)
            decisions[pid]['released'] = len(chosen)
            decisions[pid]['reason'] = 'MARCH: staged group deployed at round opening.'
            due[pid] = 0
        tray.update(decisions=decisions, march_round=due)
        events.append(e.event('STAGING_RELEASE', dict(round=n, lane=lane, decisions=copy_data(decisions))))
    w['entities']['entities'].sort(key=lambda u: u['id'])
    return events


def prepare(w, n, orders):
    if not enabled(w): return []
    events = enforce_capacity(w,n)
    for lane in LANES:
        tray = w['data']['game_staging']['lanes'][lane]
        tray.setdefault('march_round', [0, 0])
        if tray['prepared_round'] >= n: continue
        due = list(tray.get('march_round', [0, 0]))
        decisions = [dict(owner=pid, release=0 < due[pid] <= n, reason='Waiting for MARCH.',
                          force=0, pressure=0, released=0, overflow=0) for pid in (0, 1)]
        for pid in (n%2, 1-n%2):
            if decisions[pid]['release']:
                chosen = sorted((u for u in tray['units'] if u['owner'] == pid and u['attributes']['staged_round'] < n), key=lambda u:(rank(u),u['id']))
                for i,u in enumerate(chosen):
                    column,row = i%10,i//10
                    u['attributes'].update(x_fp=max(0,100-row*60) if pid == 0 else min(2400,2300+row*60),
                        y_fp=(column+1)*600//(min(10,len(chosen)-row*10)+1), movement_ready_round=n, deployed_round=n)
                    tray['units'].remove(u)
                    w['entities']['entities'].append(u)
                decisions[pid]['released'] = len(chosen)
                decisions[pid]['reason'] = 'MARCH: staged group deployed.'
                due[pid] = 0
            if orders[pid].get('staging',{}).get(lane,'Hold') == 'March':
                chosen = sorted((u for u in tray['units'] if u['owner'] == pid and u['attributes']['staged_round'] < n
                    and (lane not in orders[pid].get('staging_ids',{}) or u['id'] in orders[pid]['staging_ids'][lane])), key=lambda u:(rank(u),u['id']))
                for i,u in enumerate(chosen):
                    column,row = i%10,i//10
                    u['attributes'].update(x_fp=max(0,100-row*60) if pid == 0 else min(2400,2300+row*60),
                        y_fp=(column+1)*600//(min(10,len(chosen)-row*10)+1), movement_ready_round=n, deployed_round=n)
                    tray['units'].remove(u)
                    w['entities']['entities'].append(u)
                decisions[pid]['release'] = bool(chosen)
                decisions[pid]['released'] += len(chosen)
                decisions[pid]['reason'] = 'MARCH: visible reserves deployed; new recruits stay staged.'
        tray.update(decisions=decisions,prepared_round=n,march_round=due)
        events.append(e.event('STAGING_RELEASE',dict(round=n,lane=lane,decisions=copy_data(decisions))))
    w['entities']['entities'].sort(key=lambda u:u['id'])
    return events


def bot_order(world, n, pid):
    if not enabled(world): return {}
    result = {}
    for lane in LANES:
        tray = world['data']['game_staging']['lanes'][lane]
        field = [u for u in world['entities']['entities'] if u['kind'] == 'marcher' and u['attributes']['lane'] == lane]
        if decision(field, tray, pid, n, 'Auto')['release']:
            result[lane] = 'March'
    return result
