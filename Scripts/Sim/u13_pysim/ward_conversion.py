"""Opt-in conversion of only the newly recruited, Ward-defeated attack cohort."""
from . import economy as e, game_staging, recruitment, embolden
from .copying import copy_data


def record(world, pid, order, number, events):
    if not world['data'].get('ward_conversion_experiment') or order.get('action') not in ('Hunt','Siege'):return
    cohorts=world['data'].setdefault('ward_conversion_cohorts',[{},{}])
    cohorts[pid]=dict(round=number,lane=order['lane'],unit_ids=[r['event']['data']['id']
        for r in events if r['event']['type']=='MARCHER_SPAWNED'])


def convert(world, attacker, order, number, seed):
    mode=world['data'].get('ward_conversion_experiment')
    if not mode:return []
    if mode not in ('all','regular'):raise ValueError('Unknown Ward conversion mode')
    cohort=world['data'].get('ward_conversion_cohorts',[{},{}])[attacker]
    if cohort.get('round')!=number or cohort.get('lane')!=order['lane'] or cohort.get('consumed'):return []
    cohort['consumed']=True
    ids=set(cohort['unit_ids']);field=world['entities']['entities']
    eligible=lambda u:(u['id'] in ids and u['kind']=='marcher' and u['owner']==attacker
        and u['attributes']['hp']>0 and (mode=='all' or 'monster_id' not in u['attributes']))
    chosen=[u for u in field if eligible(u)]
    for tray in world['data'].get('game_staging',{}).get('lanes',{}).values():
        taken=[u for u in tray['units'] if eligible(u)]
        taken_ids={u['id'] for u in taken}
        tray['units'][:]=[u for u in tray['units'] if u['id'] not in taken_ids]
        field.extend(taken);chosen.extend(taken)
    if not chosen:return []
    defender=1-attacker
    for u in sorted(chosen,key=lambda u:(game_staging.rank(u),u['id'])):
        a=u['attributes'];embolden.apply(a,0)
        u['owner']=defender
        a.update(direction=1 if defender==0 else -1,movement_ready_round=number,
            deployed_round=number,ward_converted_round=number)
        a.pop('staged_round',None)
        recruitment.place_spawn(world,u,seed)
    field.sort(key=lambda u:u['id'])
    return [e.event('WARD_RECRUITS_CONVERTED',dict(round=number,lane=order['lane'],
        attacker_id=attacker,player_id=defender,mode=mode,
        regular_count=sum('monster_id' not in u['attributes'] for u in chosen),
        monster_count=sum('monster_id' in u['attributes'] for u in chosen),
        units=copy_data(chosen)))]
