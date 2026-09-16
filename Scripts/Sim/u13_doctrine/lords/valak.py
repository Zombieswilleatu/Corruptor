"""Valak: minimum sufficient Projection spend; Gravity avoids allied clusters.

Resources: spent Essence is unavailable to automatic Lord screening. Neither
Gravity's future victims nor its earned Essence are treated as guaranteed.
"""
from ..facts import LANES, power

LORD = 'Valak'


def proposals(f):
    essence = f.resources['life_essence']
    for lane in LANES:
        target, net = f.cluster(lane, 300)
        if target and net > 0:
            yield power('GravityOrb', target, 12*net, 'gravity_enemy_cluster_friendly_fire_cost')
        guards = [r for r in f.guards(f.enemy, lane) if r['attributes']['value'] <= min(5, essence)]
        if guards:
            victim = min(guards, key=lambda r: (-r['attributes']['value'], r['id']))
            spend = victim['attributes']['value']
            yield power('Projection', dict(kind='guard_zone', zone=lane, player_id=f.enemy),
                        10+4*spend-3*spend, 'minimum_essence_for_visible_guard', spend=spend)
