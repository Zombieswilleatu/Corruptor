"""Odradek: buy material swings with Reconfiguration, not empty spatial casts.

Passives: Interlock is not assumed to trigger. Redirect moves both sides;
Allegiance Shift takes enemies only. Guard changes are delayed one round.
"""
from ..facts import LANES, power

LORD = 'Odradek'


def proposals(f):
    # Avoid spending the one-point income forever while a visible material
    # swing needs three/four. This is a saving rule, not a random activation rate.
    reserve = 3 if any(f.cluster(lane, 180, friendly_penalty=0)[1] >= 2 for lane in LANES) else 0
    if not reserve and any(len(f.guards(f.enemy, lane)) >= 2 and len(f.free(f.pid, lane)) >= 2 for lane in LANES):
        reserve = 4
    saving = f.resources['reconfiguration'] < reserve
    for lane in LANES:
        target, count = f.cluster(lane, 180, friendly_penalty=0)
        if target:
            yield power('AllegianceShift', target, 25*count, 'take_visible_enemy_cluster')
        target, count = f.cluster(lane, 300)
        other = 'Castle' if lane == 'Lord' else 'Lord'
        if target and count > 0 and f.lane_need(lane) > f.lane_need(other):
            yield power('Redirect', target, 0 if saving else 10*count,
                        'save_reconfiguration_for_material_swing' if saving else 'move_pressure_to_stronger_defended_lane')
        guards = sorted(f.guards(f.enemy, lane), key=lambda r: (-r['attributes']['value'], r['id']))
        if guards and f.free(f.pid, lane):
            count = min(len(guards), len(f.free(f.pid, lane)))
            yield power('Inversion', dict(owner_id=f.enemy, lane=lane), 20*count, 'delayed_guard_ownership_plus_neutral_tear')
        if guards and f.free(f.enemy, other) and len(guards) > len(f.guards(f.enemy, other)):
            yield power('FalseOrders', dict(entity_id=guards[0]['id'], owner_id=f.enemy, lane=other),
                        0 if saving else 8+2*guards[0]['attributes']['value'],
                        'save_reconfiguration_for_material_swing' if saving else 'open_guarded_lane_next_round')
