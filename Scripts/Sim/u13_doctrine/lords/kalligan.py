"""Kalligan: place Scorch where enemy exposure exceeds friendly exposure.

Timing: Pyroclasm requires a pre-existing Inferno; a newly declared Inferno is
not active this round. Relocation preserves lifetime and is scored as a move.
"""
from u13_pysim.monsters import profile
from u13_pysim.battle import targetable
from ..facts import LANES, power

LORD = 'Kalligan'


def castle_value(f, target, intensity, damage_before=0):
    row = f.by_id.get(target.get('entity_id'))
    if not row or row['owner'] != f.enemy or not targetable(row): return 0
    hp = max(0, row['attributes']['integrity']-damage_before)
    dealt = min(hp, intensity)
    return 8*dealt + (18 if hp and dealt == hp else 0) + (10 if hp >= 7 and hp-dealt < 7 else 0)


def exposure(f, target, intensity=2):
    if target['kind'] == 'castle': return castle_value(f, target, intensity)
    lane = target['lane']
    return 7*(sum(not r['attributes'].get('flying', False) for r in f.units(f.enemy, lane))
              -sum(not r['attributes'].get('flying', False) for r in f.units(f.pid, lane)))


def proposals(f):
    active = f.active('Inferno')
    # Placement is delayed; compare the same next-round intensity when moving.
    intensity = active['stages'][min(active['stage_index']+1,len(active['stages'])-1)]['intensity'] if active else 2
    targets = [dict(kind='lane', lane=lane) for lane in LANES]
    targets += [dict(kind='castle', entity_id=r['id']) for r in f.castles(f.enemy) if targetable(r) and r['attributes']['integrity']>0]
    for target in targets:
        value = exposure(f, target, intensity)
        if active: value -= exposure(f, active['target'], intensity)
        if value > 0:
            yield power('Inferno', target, value, 'relocate_for_net_exposure' if active else 'delayed_scorch_net_exposure')
    if active:
        intensity = active['stages'][active['stage_index']]['intensity']
        value = exposure(f, active['target'], intensity)
        if value > 0:
            yield power('Pyroclasm', {}, value, 'pulse_current_scorch_intensity')


def coordinate(f, plan, context):
    """Price one optional pulse after own recruitment, before Marching.

    Lane exposure keeps the existing seven-point body heuristic. It is neither
    predicted HP loss nor a casualty count; armor, reactions and enemy orders
    can change the outcome. Inferno's delayed placement remains a separate term.
    """
    if not any(s['power_id'] == 'Pyroclasm' for s in plan['powers']): return
    active = f.active('Inferno')
    if not active: return
    target = active['target']; lane = target.get('lane')
    intensity = active['stages'][active['stage_index']]['intensity']
    before = exposure(f, target, intensity)
    recruits = monsters = power_bodies = departed = 0
    eligible_before = eligible_after = []
    if target['kind'] == 'castle':
        damage_before = context['castle_hits'].get(target['entity_id'], 0)
        after = castle_value(f, target, intensity, damage_before)
    else:
        departed = sum(r['id'] in context['consumed_supplicants'] and not r['attributes'].get('flying', False)
                       for r in f.units(f.pid, lane))
        if context['recruit_lane'] == lane:
            recruits = context['recruits']
            name = context['monster']
            if name and not profile(name, lane, f.pid, f.v['round'], f.v['round']+1)['flying']:
                monsters = context['monster_bodies_minimum']
        power_bodies = context['power_bodies_minimum'].get(lane, 0)
        after = before+7*(departed-recruits-monsters-power_bodies)
    yield dict(power='Pyroclasm', score_delta=after-before,
               reason='pulse_new_friendly_exposure' if target['kind'] == 'lane' and after < before else
                      'attack_changes_castle_pulse_value' if after < before else
                      'pulse_supplicants_depart' if after > before else 'pulse_exposure_unchanged',
               target=target, intensity=intensity, exposure_before=before, exposure_after=after,
               eligible_before=eligible_before, eligible_after=eligible_after,
               ordinary_recruits=recruits, grounded_monster_bodies_minimum=monsters,
               power_bodies_minimum=power_bodies, consumed_ground_supplicants=departed,
               unknown_extra_varn_bodies=bool(monsters and context['unknown_extra_varn_bodies']),
               timing='post_resolution_direct', certainty='conditional_own_attack' if target['kind']=='castle' else 'public_exposure_not_predicted_damage')
