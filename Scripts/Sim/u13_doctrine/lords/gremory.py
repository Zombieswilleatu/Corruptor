"""Gremory: reinforce pressure; pay two low cards to reduce healthy Castles to 14.

Passives: Guard defense supports Gem Dagger; no assumed future draw is scored.
Timing: Inevitable Ruin fires next round; damage down to 14 or lower makes it fizzle.
Resources: its two discard cards compete with this round's entire plan.
"""
from u13_pysim.battle import targetable
from u13_pysim.power_rules import RUIN_INTEGRITY
from ..facts import LANES, power

LORD = 'Gremory'


def proposals(f):
    for lane in LANES:
        yield power('PredatorOfRuin', dict(lane=lane), 27+6*f.lane_need(lane), 'three_vultures_lane_pressure')
    if len(f.hand) >= 2:
        targets = sorted((r for r in f.castles(f.enemy) if targetable(r) and r['attributes']['integrity'] > RUIN_INTEGRITY),
                         key=lambda r: (-r['attributes']['integrity'], r['id']))[:2]
        for row in targets:
            yield power('InevitableRuin', dict(entity_id=row['id']), 5*(row['attributes']['integrity']-RUIN_INTEGRITY),
                        'delayed_damage_to_14', [r['id'] for r in f.hand[:2]])
