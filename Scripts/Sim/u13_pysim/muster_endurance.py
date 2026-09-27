"""Once per Muster cohort: 25 actual enemy HP damage plus projectile blocks."""
from . import economy as e
THRESHOLD = 25
KEY = 'humbaba_muster_endurance'

def credit(world, target, attacker, hp_before, hp_after, projectile_block, number, tick):
    a = target.get('attributes', {})
    if (target.get('kind') != 'marcher' or a.get('source_power_id') != 'MusterTheFaithful'
            or a.get('suit') != 'Penitent' or not a.get('source_effect_id') or hp_before <= 0):
        return []
    pid = target['owner']
    if attacker.get('owner') != 1-pid or world['players'][pid]['lord_id'] != 'Humbaba':
        return []
    origin_owner = a.get('muster_owner', pid)
    if origin_owner != pid: return []
    damage = max(0, min(hp_before, hp_before-hp_after))
    block = int(bool(projectile_block))
    if damage+block <= 0: return []
    group_id = a['source_effect_id']
    groups = world['data'].setdefault(KEY, {})
    group = groups.setdefault(group_id, dict(owner=pid, points=0, rewarded=False))
    if group['owner'] != pid or group['rewarded']: return []
    group['points'] = round(group['points']+damage+block, 8)
    facts = dict(player_id=pid, effect_id=group_id, round=number, tick=tick,
                 points=group['points'], hp_damage=damage, projectile_blocks=block,
                 source='EnduranceOfTheFaithful')
    events = [e.event('MUSTER_ENDURANCE_PROGRESS', facts)]
    lord = e.entity(world, world['players'][pid]['lord_entity_id'])
    if group['points'] >= THRESHOLD and lord['attributes']['alive']:
        group['rewarded'] = True
        world['players'][pid]['resources']['personal_tears'] += 1
        for kind in ('PERSONAL_TEAR_CREATED', 'MUSTER_ENDURANCE_REWARDED'):
            events.append(e.event(kind, dict(facts, amount=1), 'Endurance: Muster group earned 1 Personal Tear.'))
    return events
