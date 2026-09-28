"""Bounded public Humbaba support scenarios, never future combat outcomes."""
from math import hypot
from .lane_support import free_to_advance

KEY = 'humbaba_muster_endurance'

def cohorts(f, lane=None):
    result = []
    for identity, progress in sorted(f.v['data'].get(KEY, {}).items()):
        if progress.get('owner') != f.pid or progress.get('rewarded'): continue
        units = [r for r in f.rows if r['kind']=='marcher' and r['owner']==f.pid
                 and r['attributes'].get('source_effect_id')==identity
                 and r['attributes'].get('muster_owner',f.pid)==f.pid
                 and r['attributes'].get('source_power_id')=='MusterTheFaithful'
                 and r['attributes']['hp']>0 and not r['attributes']['waiting']
                 and (lane is None or r['attributes']['lane']==lane)]
        if units: result.append((progress['points'], units))
    return result

def reachable(f, row, target, ticks=200):
    a,b=row['attributes'],target['attributes']
    distance=hypot(a['x_fp']-b['x_fp'],a['y_fp']-b['y_fp'])
    own=ticks*a.get('step_fp',0) if not a.get('waiting') and a.get('movement_ready_round',0)<=f.v['round'] else 0
    enemy=ticks*b.get('step_fp',0) if not b.get('waiting') and b.get('movement_ready_round',0)<=f.v['round'] else 0
    return distance<=own+enemy+(400 if b.get('suit')=='Vulture' else 90)

def muster_score(f,lane):
    from u13_pysim.recruitment import profile
    probe=dict(kind='marcher',owner=f.pid,attributes=profile('Penitent',lane,f.pid,f.v['round'],f.v['round']))
    enemies=[r for r in f.units(f.enemy,lane) if reachable(f,probe,r)]
    allies=[r for r in f.units(f.pid,lane) if not r['attributes']['waiting']]
    shooters=sum(r['attributes'].get('suit')=='Vulture' for r in enemies)
    allied_shooters=sum(r['attributes'].get('suit')=='Vulture' for r in allies)
    # Cap bodies so a large doomed lane cannot crowd out a useful small fight.
    contact=6*min(3,len(enemies))+3*min(3,shooters)+3*min(3,allied_shooters if enemies else 0)
    enemy_attack=sum(min(8,r['attributes'].get('attack',1)) for r in enemies)
    support=3+sum(min(8,r['attributes'].get('attack',1)) for r in allies)
    overload=min(18,max(0,enemy_attack-support)*2)
    aura=f.active('BreathOfLife')
    windows=max(0,aura['activated_round']+2-f.v['round']) if aura and aura['target']['lane']==lane else 0
    return 27+contact-overload+9*windows

def breath_score(f,lane,base,units,ctx=None):
    # Preserve some gate/arrival utility, but credit speed most when it changes
    # a reachable window. Fixed positions and nominal travel, not a rollout.
    extra=0
    targets=f.units(f.enemy,lane)
    for row in units:
        a=row['attributes']
        if not free_to_advance(row,targets): continue
        ticks=sum(200 if n==f.v['round'] else 300 for n in (f.v['round'],f.v['round']+1)
                  if a['movement_ready_round']<=n)
        ordinary=ticks*a['step_fp'];boosted=ordinary*1.25
        gate=2400-a['x_fp'] if f.pid==0 else a['x_fp']
        changed=ordinary<gate<=boosted
        for enemy in targets:
            b=enemy['attributes']
            closing=0 if b.get('waiting') else ticks*b.get('step_fp',0)
            gap=hypot(a['x_fp']-b['x_fp'],a['y_fp']-b['y_fp'])-closing-90
            changed=changed or ordinary<gap<=boosted
        extra+=int(changed)
    excluded=set(ctx['consumed_supplicants']) if ctx else set()
    endurance=0
    for points,bodies in cohorts(f,lane):
        if points<15: continue
        healing=sum(min(1,max(0,r['attributes']['max_hp']-r['attributes']['hp']))
                    for r in bodies if r['id'] not in excluded and any(reachable(f,r,e) for e in targets))
        endurance+=min(12,healing*(4 if points<20 else 8))
    endurance=min(20,endurance)
    return dict(score=8*(base['immediate_healing']+base['next_regen_bonus'])
                +base['pressure_movement_windows']+6*min(4,extra)+endurance,
                incremental_arrivals=extra,endurance_support=endurance)

def survival_bonus(f,world,plan):
    if f.kind!='Humbaba' or not f.lord[f.pid]['attributes']['alive']:return 0
    from .defensive_plans import development,exposure
    history=[r for r in f.opponent['evidence'] if r['action']=='Hunt'][-3:]
    if not history and f.lord[f.enemy]['attributes']['lord_id']!='Orias':return 0
    if not hasattr(f,'_humbaba_survival'):
        mean=sum(r['strength'] for r in history)//len(history) if history else 15
        mean=max(9,min(30,mean));empty=dict(powers=[],order={});base,_=development(f,empty)
        f._humbaba_survival=[(p,exposure(f,base,empty,'Lord',p)) for p in (max(1,mean-6),mean,mean+6)]
    near=sum(points>=18 for points,_ in cohorts(f))
    value=36+min(24,12*near)
    return sum(value*(int(before['banished'])-int(exposure(f,world,plan,'Lord',p)['banished']))
               for p,before in f._humbaba_survival)//3
