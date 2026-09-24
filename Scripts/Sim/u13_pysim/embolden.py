"""Shared defensive pressure rules, mirrored by U13Embolden.gd.

Combat stats retain fractional values for percentage experiments; board
coordinates and movement remain integer fixed-point. No random rounding.
"""
import math

KEY = 'embolden_experiment'
FIELDS = ('hp', 'max_hp', 'attack', 'armor', 'max_armor', 'regen', 'tumler_charge_base_armor')


def enabled(world):
    return world['data'].get(KEY, 0) > 0


def pressures(world, rows=None):
    percent = world['data'].get(KEY, 0)
    if type(percent) is not int or not 0 <= percent <= 20:
        raise ValueError('Embolden must be an integer from 0 to 20 per slot')
    occupied = {(pid,lane):set() for pid in (0,1) for lane in ('Lord','Castle')}
    for row in world['entities']['entities'] if rows is None else rows:
        a=row['attributes']
        if row['kind']=='card' and a.get('role')=='guard' and row['owner'] in (0,1):
            if a.get('lane') in ('Lord','Castle') and a.get('slot') in (0,1,2):
                occupied[row['owner'],a['lane']].add(a['slot'])
    if world['data'].get('embolden_ramp_experiment'):
        history=world['data'].get('embolden_guard_history',{}).get('slots')
        return {(pid,lane):sum(min(20,5+5*slot['age']) if slot['age'] else 0
                    for i,slot in enumerate(history[1-pid][lane]) if i not in occupied[1-pid,lane]) if history else 0
                for pid in (0,1) for lane in ('Lord','Castle')}
    return {(pid,lane):percent*(3-len(occupied[1-pid,lane])) for pid in (0,1) for lane in ('Lord','Castle')}


def number(value):
    value=round(value, 8)
    return int(value) if value.is_integer() else value


def apply(a, percent):
    before=a.get('_embolden_percent',0)
    if before==percent:
        # Unbuffed recipients can still take fractional attacks from buffed
        # enemies. Mark them so damage uses the experiment's precision too.
        a['_embolden_percent']=percent
        return
    ratio=(100+percent)/(100+before)
    # Preserve current wounds and depleted Armor proportionally. Rechecking a
    # phase cannot heal, refill Armor, compound the buff or change base speed.
    for field in FIELDS:
        if field in a:a[field]=number(a[field]*ratio)
    a['_embolden_percent']=percent


def refresh(world):
    if not enabled(world):return
    bonuses=pressures(world)
    for row in world['entities']['entities']:
        if row['kind']=='marcher':apply(row['attributes'],bonuses[row['owner'],row['attributes']['lane']])


def refresh_phase(phase):
    if not enabled(phase.w):return
    observe_guards(phase.w,phase.number,phase.s.background)
    s=phase.s
    bonuses=pressures(phase.w,s.background)
    for i in s.active():
        old=(s.extra[i] or {}).get('_embolden_percent',0)
        bonus=bonuses[s.owner[i],s.lane[i]]
        if old==bonus and '_embolden_percent' in (s.extra[i] or {}):continue
        row=s.row(i);apply(row['attributes'],bonus)
        from .marching_buffer import Buffer
        Buffer(phase).update(row['id'],row['owner'],row['attributes'])


def valid_stat(value):
    return type(value) in (int,float) and math.isfinite(value)


def clean_damage(value, a):
    return round(value,8) if '_embolden_percent' in a else value


def transform(a, fields):
    factor=(100+a.get('_embolden_percent',0))/100
    if factor!=1:
        for field in fields:a[field]=number(a[field]*factor)


def observe_guards(world, number, rows=None):
    """Age only fully empty rounds; even brief occupation cancels that round.

    A Guard lost during R4 gets an entire R5 to be replaced; +10 starts R6.
    Initial slots empty throughout R1 start +10 at R2. Filling resets at once.
    """
    if not world['data'].get('embolden_ramp_experiment'):return
    d=world['data'];history=d.get('embolden_guard_history')
    if history is None:
        history=d['embolden_guard_history']=dict(round=number,slots=[
            {lane:[dict(age=0,occupied=False) for _ in range(3)] for lane in ('Lord','Castle')} for _ in (0,1)])
    if number!=history['round']:
        if number!=history['round']+1:raise ValueError('Embolden history round discontinuity')
        for zones in history['slots']:
            for slots in zones.values():
                for slot in slots:slot.update(age=0 if slot['occupied'] else min(3,slot['age']+1),occupied=False)
        history['round']=number
    for row in world['entities']['entities'] if rows is None else rows:
        a=row['attributes']
        if row['kind']=='card' and a.get('role')=='guard' and row['owner'] in (0,1) and a.get('lane') in ('Lord','Castle') and a.get('slot') in (0,1,2):
            history['slots'][row['owner']][a['lane']][a['slot']].update(age=0,occupied=True)


VERSION = 'U13_DEFENSIVE_PRESSURE_V1'

def configure(world):
    world['data'].update(defensive_pressure_profile=VERSION,
        embolden_experiment=10, embolden_ramp_experiment=True,
        ward_conversion_experiment='regular')
