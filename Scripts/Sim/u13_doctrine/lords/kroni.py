"""Kroni: feed on enemy Guards, reserve Ravenous for favorable field presence.

Passives: Hunger changes defense; Ward/empty-Pass costs are charged in common
scoring. Ravenous has friendly-fire exposure and an uncertain path, not a
promised victim count. Consume requires the source to survive until firing.
"""
from ..facts import LANES, power

LORD = 'Kroni'


def proposals(f):
    hunger = f.lord[f.pid]['attributes']['hunger']
    guards = sorted((r for lane in LANES for r in f.guards(f.enemy, lane)),
                    key=lambda r: (-r['attributes']['value'], r['id']))[:2]
    for row in guards:
        yield power('Consume', dict(entity_id=row['id']), 12+4*row['attributes']['value']+4*max(0, 3-hunger),
                    'delayed_guard_meal_requires_surviving_source')
    for lane in LANES:
        net = len(f.units(f.enemy, lane))-len(f.units(f.pid, lane))
        if net > 0:
            target = dict(lane=lane, field_position=dict(x_fp=0 if f.pid == 0 else 2400, y_fp=300))
            yield power('Ravenous', target, 9*net, 'enemy_heavy_lane_path_uncertain')


def coordinate(f, plan, context):
    """Respect the delayed meal's identity and the actor's new friendly exposure."""
    hunger = f.lord[f.pid]['attributes']['hunger']
    for source in plan['powers']:
        name, target = source['power_id'], source['target']
        if name == 'Consume':
            guard = f.by_id[target['entity_id']]
            removed = guard['id'] in context['guard_losses']
            credit = 12+4*guard['attributes']['value']+4*max(0, 3-hunger)
            yield dict(power=name, score_delta=-credit if removed else 0,
                       reason='attack_removes_consume_target' if removed else 'consume_target_remains',
                       target_id=guard['id'], timing='next_round_start', certainty='current_board_scenario')
        elif name == 'Ravenous':
            lane = target['lane']
            recruits = context['recruits'] if context['recruit_lane'] == lane else 0
            monsters = context['monster_bodies_minimum'] if context['recruit_lane'] == lane else 0
            power_bodies = context['power_bodies_minimum'].get(lane, 0)
            consumed = sum(r['id'] in context['consumed_supplicants'] for r in f.units(f.pid, lane))
            # Same nine-point body-count heuristic as the isolated proposal;
            # it now sees own planned arrivals and departures. Not kill counts.
            delta = 9*(consumed-recruits-monsters-power_bodies)
            yield dict(power=name, score_delta=delta,
                       reason='ravenous_new_friendly_exposure' if delta < 0 else
                              'ravenous_supplicants_leave_before_marching' if delta > 0 else 'ravenous_exposure_unchanged',
                       lane=lane, ordinary_recruits=recruits, monster_bodies_minimum=monsters,
                       power_bodies_minimum=power_bodies, consumed_supplicants=consumed,
                       timing='post_resolution_special_actors',
                       certainty='lane_exposure_only_not_predicted_casualties')
