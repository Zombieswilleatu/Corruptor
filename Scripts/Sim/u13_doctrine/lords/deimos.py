"""Deimos: operational artillery and enemy lane retreat.

Passives: reconstruction is handled by common Work; Spoils remains an observed
effect, not fabricated income. Rout snapshots enemies present when it fires.
"""
from u13_pysim.battle import operational
from ..facts import LANES, power

LORD = 'Deimos'


def proposals(f):
    for row in f.castles(f.pid):
        if row['attributes'].get('combat_profile') == 'siege_engine' and operational(row):
            yield power('WarMachine', dict(entity_id=row['id']), 18, 'operational_extra_artillery')
    for lane in LANES:
        enemies = f.units(f.enemy, lane)
        if enemies:
            yield power('Rout', dict(lane=lane), 8*len(enemies)+6*f.lane_need(lane), 'retreat_existing_enemy_column')
