"""Bounded Scorch packet estimates; no hidden orders or Marching rollout.

Castle Scorch has already pulsed before planning. Lane Scorch is still due
at Marching start. Delayed placement/relocation uses only remaining stages.
"""
from u13_pysim import incoming_damage, recruitment, veil
from u13_pysim.castle_balance import FORGE_REPAIR, RAPID_CONSTRUCTION_REPAIR
from u13_pysim.copying import copy_data
from u13_pysim.battle import targetable
from u13_pysim.power_rules import RULES
from .diagnostics import fingerprint
from .lane_support import free_to_advance, travel
from .orias_tactics import _support


def castle_value(f, target, intensity, damage_before=0):
    row = f.by_id.get(target.get('entity_id'))
    if not row or row['owner'] != f.enemy or not targetable(row): return 0
    hp = max(0, row['attributes']['integrity']-damage_before)
    dealt = min(hp, intensity)
    return 8*dealt + (18 if hp and dealt == hp else 0) + (10 if hp >= 7 and hp-dealt < 7 else 0)


def bodies(f, lane, ctx=None):
    own = _support(f, lane, ctx)
    if ctx:
        # Unknown Wish suit: count the guaranteed ground body without assuming
        # a particular combat ability. Current monster/Wish powers are ground.
        for i in range(ctx['power_bodies_minimum'].get(lane, 0)):
            attrs = recruitment.profile('Butcher', lane, f.pid, f.v['round'], f.v['round']+1)
            own.append(dict(id='fire_power_body:'+str(i),kind='marcher',owner=f.pid,attributes=attrs,planned=True))
    return [copy_data(r) for r in own+f.units(f.enemy, lane) if not r['attributes'].get('flying',False)]


def packet(a, intensity, clock):
    """Apply only Scorch's deterministic Armor/HP packet to a local profile."""
    if a['hp'] <= 0: return dict(hp=0, armor=0, kills=0, score=0)
    amount = incoming_damage.amount(a, intensity, clock)
    armor = min(a['armor'], amount); hp = min(a['hp'], amount-armor)
    a['armor'] -= armor; a['hp'] -= hp
    killed = int(a['hp'] == 0)
    return dict(hp=hp, armor=armor, kills=killed, score=4*hp+2*armor+12*killed)


def _lane(f, target, stages, ctx=None, pre_pulses=()):
    rows = bodies(f, target['lane'], ctx); out = dict(score=0, hp=0, armor=0, enemy_kills=0, friendly_kills=0)
    for r in rows:
        a = r['attributes']; sign = 1 if r['owner'] == f.enemy else -1
        for amount in pre_pulses: packet(a, amount, f.v['round']*200)
        foes = f.units(1-r['owner'], target['lane'])
        for delay, intensity in stages:
            result = packet(a, intensity, (f.v['round']+delay)*200)
            # Future occupancy is uncertain. Public unopposed gate-reaching
            # troops get one quarter exposure, not a promised disappearance.
            distance = a['x_fp'] if r['owner'] == 1 else 2400-a['x_fp']
            moving = delay and free_to_advance(r, foes) and sum(travel(a,f.v['round']+step) for step in range(delay)) >= distance
            discount = 4 if moving else 1
            credit = result['score']*3**delay//(4**delay*discount)
            out['score'] += sign*credit
            out['hp'] += sign*result['hp']; out['armor'] += sign*result['armor']
            out['enemy_kills' if sign == 1 else 'friendly_kills'] += result['kills']
    return out


def _castle(f, target, stages, ctx=None, pre_damage=0):
    row=f.by_id.get(target.get('entity_id'))
    if not row or row['owner']!=f.enemy or not targetable(row): return dict(score=0)
    hp=max(0,row['attributes']['integrity']-(ctx['castle_hits'].get(target['entity_id'],0) if ctx else 0)-pre_damage)
    cap=row['attributes']['max_integrity']; value=0; previous=0
    repair=(RAPID_CONSTRUCTION_REPAIR if veil.affects(f.world,'Kalligan',f.enemy) else
            FORGE_REPAIR if f.lord[f.enemy]['attributes']['alive'] and f.lord[f.enemy]['attributes']['lord_id']=='Kalligan' else 0)
    for delay,intensity in stages:
        if hp<=0: break
        # Forge follows automatic Castle Scorch, so repairs intervene between
        # future stages, but not before the next round's first Castle pulse.
        if previous and delay>previous: hp=min(cap,hp+repair*(delay-previous))
        dealt=min(hp,intensity)
        score=8*dealt+(18 if dealt==hp else 0)+(10 if hp>=7 and hp-dealt<7 else 0)
        value+=score*3**delay//4**delay
        hp-=dealt;previous=delay
    return dict(score=value)



def forecast(f, target, stages, ctx=None, pre_pulses=()):
    return (_castle(f,target,stages,ctx,sum(pre_pulses)) if target['kind']=='castle'
            else _lane(f,target,stages,ctx,pre_pulses))


def inferno_value(f, target, ctx=None, plan=None):
    active = f.active('Inferno')
    stages = active['stages'][active['stage_index']+1:] if active else RULES['Inferno']['stages']
    schedule = [(i+1,s['intensity']) for i,s in enumerate(stages)]
    current = active['target'] if active else None
    # Current lane pulse is still due. Castle's automatic pulse already fired.
    pre = [active['stages'][active['stage_index']]['intensity']] if active and current['kind']=='lane' else []
    if active and plan and any(p['power_id']=='Pyroclasm' for p in plan['powers']):
        pre.append(active['stages'][active['stage_index']]['intensity'])
    stay = forecast(f,current,schedule,ctx,pre)['score'] if active else 0
    moved = forecast(f,target,schedule,ctx,pre if current==target else ())['score']
    return dict(score=moved-stay, reason='remaining_fire_relocation_gain' if active else 'delayed_fire_damage_and_losses',
                target=target, remaining_intensities=[s['intensity'] for s in stages],
                keep_score=stay, target_score=moved, timing='next_round_persistent_advancement',
                certainty='discounted_public_survivors_no_future_orders')


def pyro_value(f, ctx=None):
    active = f.active('Inferno')
    if not active: return dict(score=0,reason='requires_existing_fire')
    target = active['target']; intensity = active['stages'][active['stage_index']]['intensity']
    # Compare extra+automatic with automatic alone in lanes. A one-HP body
    # already due to burn is not another kill purchased by Pyroclasm.
    baseline = forecast(f,target,[(0,intensity)],ctx) if target['kind']=='lane' else dict(score=0)
    combined = forecast(f,target,[(0,intensity)]*(2 if target['kind']=='lane' else 1),ctx)
    score = combined['score']-baseline['score']
    # At the low first stage, preserve the next-round intensity-two option
    # when the same public cohort would give a substantially better pulse.
    future = 0
    if target['kind']=='lane' and active['stage_index']+1 < len(active['stages']):
        upcoming = active['stages'][active['stage_index']+1]['intensity']
        if upcoming > intensity:
            pre = (intensity,)
            future = forecast(f,target,[(1,upcoming)]*2,ctx,pre)['score']-forecast(f,target,[(1,upcoming)],ctx,pre)['score']
    reserve = max(0,future)
    lane = target.get('lane'); recruits = grounded_monsters = power_bodies = departed = 0
    if ctx and lane:
        from u13_pysim.monsters import profile
        departed = sum(r['id'] in ctx['consumed_supplicants'] and not r['attributes'].get('flying',False) for r in f.units(f.pid,lane))
        if ctx['recruit_lane']==lane:
            recruits=ctx['recruits']
            if ctx['monster'] and not profile(ctx['monster'],lane,f.pid,f.v['round'],f.v['round']+1)['flying']:
                grounded_monsters=ctx['monster_bodies_minimum']
        power_bodies=ctx['power_bodies_minimum'].get(lane,0)
    return dict(score=score-reserve, reason='extra_pulse_incremental_damage_and_losses', target=target,intensity=intensity,
                automatic_score=baseline['score'], combined_score=combined['score'], immediate_gain=score,
                next_stage_gain=future, cooldown_reserve=reserve,
                ordinary_recruits=recruits, grounded_monster_bodies_minimum=grounded_monsters,
                power_bodies_minimum=power_bodies,consumed_ground_supplicants=departed,
                unknown_extra_varn_bodies=bool(grounded_monsters and ctx['unknown_extra_varn_bodies']),
                timing='post_resolution_direct',certainty='public_packet_estimate_no_combat_or_death_reactions')


def value(f, name, target=None, ctx=None, plan=None):
    key=fingerprint([name,target,ctx,[p['power_id'] for p in plan['powers']] if plan else []])
    if not hasattr(f,'_kalligan_values'): f._kalligan_values={}
    if key not in f._kalligan_values:
        f._kalligan_values[key]=pyro_value(f,ctx) if name=='Pyroclasm' else inferno_value(f,target,ctx,plan)
    return copy_data(f._kalligan_values[key])
