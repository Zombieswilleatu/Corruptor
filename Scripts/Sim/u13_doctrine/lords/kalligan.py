"""Kalligan: place Scorch where enemy exposure exceeds friendly exposure.

Timing: Pyroclasm requires a pre-existing Inferno; a newly declared Inferno is
not active this round. Relocation preserves lifetime and is scored as a move.
"""
from ..facts import LANES, power

LORD = 'Kalligan'


def exposure(f, target):
    lane = target['lane']
    if target['kind'] == 'guard':
        return sum(r['attributes']['value'] <= 2 for r in f.guards(f.enemy, lane))*12
    return 7*(len(f.units(f.enemy, lane))-len(f.units(f.pid, lane)))


def proposals(f):
    active = f.active('Inferno')
    for lane in LANES:
        for target in (dict(kind='lane', lane=lane), dict(kind='guard', lane=lane, player_id=f.enemy)):
            value = exposure(f, target)
            if active:
                value -= exposure(f, active['target'])
            if value > 0:
                yield power('Inferno', target, value, 'relocate_for_net_exposure' if active else 'delayed_scorch_net_exposure')
    if active and exposure(f, active['target']) > 0:
        yield power('Pyroclasm', {}, exposure(f, active['target']), 'pulse_existing_scorch')
