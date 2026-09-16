"""Humbaba: establish a lane, then sustain its existing wounded units.

Passives: Castle activation strengthens standing defense; common Resummon pays
the full requirement. Endurance benefit requires actual surviving units.
"""
from ..facts import LANES, power

LORD = 'Humbaba'


def proposals(f):
    for lane in LANES:
        yield power('MusterTheFaithful', dict(lane=lane), 27+6*f.lane_need(lane), 'three_penitents_lane_support')
        units = f.units(f.pid, lane)
        if units:
            missing = sum(max(0, r['attributes'].get('max_hp', r['attributes']['hp'])-r['attributes']['hp']) for r in units)
            yield power('BreathOfLife', dict(lane=lane), 6*len(units)+4*missing, 'sustain_existing_allied_column')
