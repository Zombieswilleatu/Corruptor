"""Independent constants for the existing U13 declared powers, not policy weights."""
from .copying import copy_data
from .primitives import instance_id
from .incoming_damage import ROUT_RETREAT_ATTACK_BONUS

RUIN_INTEGRITY = 8
LONGEVITY_INTEGRITY = 8


def rule(lord, hook, cooldown=0, delay=0, stages=None, **extra):
    stages = [] if stages is None else stages
    return dict(lord_id=lord, fire_hook=hook, cooldown_on='expiration' if stages else 'activation',
                cooldown_rounds=cooldown, delay_rounds=delay, cost={}, stages=stages,
                target_kind='', target_relation='any', visibility='public', **extra)


RULES = {
    'PredatorOfRuin': rule('Gremory','post_resolution_spawns',1,spawn_count=2),
    'InevitableRuin': rule('Gremory','round_start_scheduled',delay=1,discard_count=2,target_integrity=RUIN_INTEGRITY),
    'WarMachine': rule('Deimos','post_repair_artillery'),
    'Rout': rule('Deimos','post_resolution_movement_state',2,stages=[dict(movement='retreat'),dict(movement='half_speed')],retreat_regular_attack_bonus=ROUT_RETREAT_ATTACK_BONUS),
    'MusterTheFaithful': rule('Humbaba','post_resolution_spawns',1),
    'BreathOfLife': rule('Humbaba','post_resolution_movement_state',2,stages=[dict(active=True),dict(active=True)],lane_aura=dict(regen_bonus=1,speed_percent=25),activation_heal=1),
    'Inferno': rule('Kalligan','persistent_advancement',1,1,[dict(intensity=1),dict(intensity=2),dict(intensity=1)],persistent_relocatable=True,persistent_context=True),
    'Pyroclasm': rule('Kalligan','post_resolution_direct',1,persistent_context=True),
    'Web': rule('Orias','post_resolution_hazards',1,stages=[dict(fresh=True),dict(fresh=False)],spatial_field=dict(kind='web',radius_fp=270)),
    'Snare': rule('Orias','round_start_scheduled',delay=1,threat_gain=1),
    'Redirect': rule('Odradek','post_resolution_position',repeatable=True),
    'FalseOrders': rule('Odradek','round_start_scheduled',delay=1,repeatable=True),
    'AllegianceShift': rule('Odradek','post_resolution_allegiance',repeatable=True),
    'Inversion': rule('Odradek','round_start_scheduled',delay=1,repeatable=True),
    'Consume': rule('Kroni','round_start_scheduled',delay=1),
    'Ravenous': rule('Kroni','post_resolution_special_actors',2),
    'Projection': rule('Valak','post_resolution_direct'),
    'GravityOrb': rule('Valak','post_resolution_hazards',2,stages=[dict(name='active'),dict(name='active')]),
}
RULES['InevitableRuin']['target_kind'] = 'castle'
RULES['WarMachine'].update(target_kind='castle',target_relation='own')
RULES['Rout']['target_relation'] = 'enemy'
for _name in ('MusterTheFaithful','BreathOfLife'): RULES[_name]['target_relation'] = 'own'
for _cost,_name in enumerate(('Redirect','FalseOrders','AllegianceShift','Inversion'),1):
    RULES[_name]['cost'] = dict(reconfiguration=_cost)
for _name in ('WishPower','WishLongevity','WishResurrection','WishDeath','WishWealth'):
    RULES[_name] = rule('Kanifous','post_resolution_spawns' if _name=='WishPower' else 'post_resolution_direct')
RULES['WishResurrection']['fire_hook'] = 'end_marching_checks'
RULES['WishLongevity']['heal_integrity'] = LONGEVITY_INTEGRITY
for _name in ('WishPower','WishLongevity','WishResurrection','WishDeath','WishWealth'):
    RULES['Breach'+_name] = dict(copy_data(RULES[_name]),breach_wish=True)


def declaration(pid, number, power, target=None, *, index=0, discard_ids=None, parameters=None):
    r = RULES[power]
    cost = copy_data(r['cost'])
    if discard_ids is not None: cost['discard_ids'] = list(discard_ids)
    return dict(schema_version='U13_LORD_DECLARATION_V1',
                declaration_id=instance_id('declaration',f'{pid}:{number}',str(index)),
                player_id=pid,lord_id=r['lord_id'],power_id=power,declared_round=number,
                fire_round=number+r['delay_rounds'],fire_hook=r['fire_hook'],queue_index=index,
                visibility=r['visibility'],target=copy_data(target or {}),cost=cost,
                parameters=copy_data(parameters or {}))
