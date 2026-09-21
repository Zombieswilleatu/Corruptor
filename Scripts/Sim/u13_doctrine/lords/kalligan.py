"""Kalligan: useful fire packets, remaining lifetime and optional pulse timing."""
from u13_pysim.battle import targetable
from ..facts import LANES, power
from ..kalligan_tactics import castle_value, value

LORD = 'Kalligan'


def proposals(f):
    targets = [dict(kind='lane',lane=lane) for lane in LANES]
    targets += [dict(kind='castle',entity_id=r['id']) for r in f.castles(f.enemy) if targetable(r) and r['attributes']['integrity']>0]
    for target in targets:
        result=value(f,'Inferno',target)
        if result['score']>0 or (target['kind']=='lane' and any(not r['attributes'].get('flying',False) for r in f.units(f.enemy,target['lane']))):
            yield power('Inferno',target,result['score'],result['reason'])
    if f.active('Inferno'):
        result=value(f,'Pyroclasm')
        target=f.active('Inferno')['target']
        if result['score']>0 or (target['kind']=='lane' and any(not r['attributes'].get('flying',False) for r in f.units(f.enemy,target['lane']))):
            yield power('Pyroclasm',{},result['score'],result['reason'])


def coordinate(f,plan,ctx):
    for source in plan['powers']:
        name=source['power_id']
        if name not in ('Inferno','Pyroclasm'): continue
        target=source['target']; baseline=value(f,name,target)
        adjusted=value(f,name,target,ctx,plan)
        yield dict(power=name,score_delta=adjusted['score']-baseline['score'],
                   exposure_before=baseline['score'],exposure_after=adjusted['score'],**adjusted)
