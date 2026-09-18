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


def coordinate(f, plan, context):
    """Projection fires after attacks; charge Essence even when none is left."""
    lost = set(context['guard_losses'])
    for source in plan['powers']:
        if source['power_id'] != 'Projection': continue
        lane, spend = source['target']['zone'], source['parameters']['spend']
        eligible = [r for r in f.guards(f.enemy, lane) if r['attributes']['value'] <= spend]
        remaining = [r for r in eligible if r['id'] not in lost]
        before = max((r['attributes']['value'] for r in eligible), default=0)
        after = max((r['attributes']['value'] for r in remaining), default=0)
        # Proposals already charge three per Essence. Remove only material
        # credit no longer supported by this public-board scenario.
        benefit = lambda value: 10+4*value if value else 0
        yield dict(power='Projection', score_delta=benefit(after)-benefit(before),
                   reason='attack_removes_projection_targets' if before and not after else
                          'attack_reduces_projection_target' if after < before else 'projection_target_remains',
                   eligible_before=[r['id'] for r in eligible], eligible_after=[r['id'] for r in remaining],
                   spend=spend, target_value_before=before, target_value_after=after,
                   timing='post_resolution_direct', certainty='current_board_scenario')
