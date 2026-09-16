"""Gremory: reinforce pressure; pay two low cards only for valuable damaged stone.

Passives: Guard defense supports Gem Dagger; no assumed future draw is scored.
Timing: Inevitable Ruin fires next round and can fizzle after repair.
Resources: its two discard cards compete with this round's entire plan.
"""
from u13_pysim.battle import targetable
from ..facts import LANES, power

LORD = 'Gremory'


def proposals(f):
    for lane in LANES:
        yield power('PredatorOfRuin', dict(lane=lane), 27+6*f.lane_need(lane), 'three_vultures_lane_pressure')
    if len(f.hand) >= 2:
        targets = sorted((r for r in f.castles(f.enemy) if targetable(r) and 0 < r['attributes']['integrity'] < r['attributes']['max_integrity']),
                         key=lambda r: (-r['attributes']['integrity'], r['id']))[:2]
        for row in targets:
            yield power('InevitableRuin', dict(entity_id=row['id']), 5*row['attributes']['integrity'],
                        'delayed_defunction_repair_can_fizzle', [r['id'] for r in f.hand[:2]])
