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
