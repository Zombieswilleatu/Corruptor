"""Bounded public Rout estimates, not Marching rollouts or outcome promises.

Count stationary firing/contact windows along the enemy's full-speed retreat.
A faster pursuer can earn one additional intercept, without assuming repeated
swings while chasing. New recruits sample the public spawn band and can attack
immediately, while birth readiness limits movement only. Exact placement, paths
and enemy orders stay unknown.
"""
from math import isqrt

from u13_pysim import field_combat, field_fortifications as fort, marching_spatial
from u13_pysim import monster_effects, monsters, penitent_defense, recruitment
from u13_pysim.copying import copy_data
from .lane_support import mobile, travel

HIT_VALUE, CAST_RESERVE, HIT_CAP = 6, 6, 800  # Hits below use hundredths.


def _speed(a, number, chase=False):
    if not mobile(a) or a.get('movement_ready_round', 0) > number:
        return 0
    if chase and (a.get('waiting') or a.get('rout_round') == number
                  or 'wright_site' in a and not a.get('wright_released', False)):
        return 0
    return a['step_fp']


def _window(row, target, number, world):
    """At most six ordinary attacks; no seed, special packets or future spawns."""
    a, b = row['attributes'], target['attributes']
    tower = row['kind'] == 'fortification'
    ranged = tower or a.get('suit') == 'Vulture' and not fort.in_melee(row, target)
    radius = (marching_spatial.tower_range(world) if tower else marching_spatial.vulture_range(world)) if ranged else fort.CONTACT
    lateral = radius if ranged else fort.LATERAL_CONTACT
    interval = field_combat.RANGED_INTERVAL if ranged else field_combat.MELEE_INTERVAL
    ready = max(0, a.get('ranged_next_tick' if ranged else 'melee_next_tick', 0)-number*200)
    direction = 1 if row['owner'] == 0 else -1
    ax = a['x_fp'] if direction == 1 else 2400-a['x_fp']
    bx = b['x_fp'] if direction == 1 else 2400-b['x_fp']
    dy = abs(a['y_fp']-b['y_fp'])
    enemy_speed = _speed(b, number)  # Rout releases waiting units to retreat.
    first, last = ready, -1
    if dy <= lateral:
        reach = isqrt(radius*radius*(lateral*lateral-dy*dy)//(lateral*lateral))
        low, high = ax-reach, ax+reach
        if enemy_speed:
            # Movement precedes attacks at tick zero; clamp at the enemy home.
            first = max(ready, (low-bx+enemy_speed-1)//enemy_speed-1, 0)
            last = 199 if high >= 2400 else min(199, (high-bx)//enemy_speed-1)
            if min(2400, bx+enemy_speed*(first+1)) < low: last = -1
        elif low <= bx <= high:
            last = 199
    hits = max(0, 1+(last-first)//interval) if first <= last else 0
    first_tick = first if hits else None
    # Once a shooter/striker loses range, equal-speed chasing cannot close it.
    # Charge a full lateral alignment and one movement tick of lost ground.
    own_speed = 0 if tower else _speed(a, number, chase=True)
    if own_speed > 0 and ready < 200:
        start = max(0, last+1) if hits else 0
        align = (dy+own_speed-1)//own_speed
        at = start+align
        target_x = min(2400, bx+enemy_speed*(at+1))
        closing = own_speed-enemy_speed if target_x >= ax else own_speed+enemy_speed
        if closing > 0:
            gap = max(0, abs(target_x-ax)-radius)+enemy_speed
            catch = max(ready, at+(gap+closing-1)//closing)
            if hits: catch = max(catch, first+(hits-1)*interval+interval)
            if catch < 200:
                hits += 1
                if first_tick is None: first_tick = catch
    # A landed hit wakes an enemy recruit; do not treat its birth hold as a
    # promise that it will remain stationary for every subsequent attack.
    cap = 1 if b.get('movement_ready_round', 0) > number and mobile(b) else 4 if ranged else 6
    return dict(hits=min(hits, cap), first_tick=first_tick,
                kind='ranged' if ranged else 'melee')


def _planned(f, lane, ctx):
    if not ctx or ctx['recruit_lane'] != lane:
        return []
    number = f.v['round']; rows = []
    profiles = [(suit, count, False) for suit, count in ctx['recruit_suits'].items()]
    if ctx['monster']:
        profiles.append((ctx['monster'], ctx['monster_bodies_minimum'], True))
    for name, count, monster in profiles:
        a = (monsters.profile if monster else recruitment.profile)(name, lane, f.pid, number, number+1)
        for ordinal in range(count):
            rows.append(dict(id='planned_rout:'+name+':'+str(ordinal), kind='marcher', owner=f.pid,
                             attributes=copy_data(a), planned=True))
    return rows


def _land_percent(target, kind):
    a = target['attributes']
    if a.get('monster_id') == 'Kurchin' and a['armor'] > 0:
        return 100-monsters.TUNING['kurchin_deflection_chance']
    if a.get('monster_id') == 'Tumler':
        return 100-monsters.TUNING['tumler_evasion_chance']
    if a.get('suit') == 'Penitent' and kind == 'ranged':
        return 100-penitent_defense.CHANCE
    return 100


def rout_value(f, lane, ctx=None):
    number = f.v['round']
    excluded = set(ctx['consumed_supplicants']) if ctx else set()
    allies = [r for r in f.units(f.pid, lane) if r['id'] not in excluded]
    recruits = _planned(f, lane, ctx)
    structures = sorted(fort.rows(f.world), key=lambda r: r['id'])
    enemies = f.units(f.enemy, lane)
    # Public geometry includes objects that would attract a shot instead.
    targets = enemies+[r for r in structures if r['owner'] == f.enemy and r['attributes']['lane'] == lane]
    threats, gates, distant = [], [], []
    for enemy in enemies:
        a = enemy['attributes']
        if a.get('sprite_form') == 'turret' or a.get('hidden', False): continue
        distance = travel(a, number)
        gate = (a.get('waiting', False) or mobile(a) and a.get('movement_ready_round', 0) <= number
                and (a['x_fp'] if f.pid == 0 else 2400-a['x_fp']) <= distance)
        reach = 400 if a.get('suit') == 'Vulture' else 90
        fight = any(not r['attributes'].get('hidden', False) and fort.gap(r, enemy)
                    <= (distance+travel(r['attributes'], number)+reach)**2 for r in allies)
        if gate or fight:
            threats.append(enemy['id'])
            if gate: gates.append(enemy['id'])
        else: distant.append(enemy['id'])
    def strength(rows):
        return sum(r['attributes']['hp']+r['attributes']['armor']+r['attributes']['attack'] for r in rows)
    defenders = [r for r in allies if not r['attributes'].get('hidden', False)
                 and any(fort.gap(r, e) <= (travel(r['attributes'], number)+travel(e['attributes'], number)+400)**2
                         for e in enemies if e['id'] in threats)]
    overwhelmed = bool(defenders) and strength([e for e in enemies if e['id'] in threats])*2 > strength(defenders)*3
    delay_score = max(14*min(3, len(gates)), 8*min(3, len(threats)) if overwhelmed else 0)
    attackers = allies+recruits+[r for r in structures if r['owner'] == f.pid
                 and r['attributes']['lane'] == lane and r['attributes']['structure'] == 'Tower']
    remaining = {r['id']: 100*(r['attributes']['hp']+r['attributes']['armor']) for r in enemies}
    packets, hit_units = [], 0
    for row in attackers:
        a = row['attributes']
        if a.get('attack', 0) <= 0 or a.get('hidden', False) or a.get('sprite_form') == 'turret' or a.get('rout_round') == number:
            continue
        target = monster_effects.preferred(row, enemies) if row['kind'] == 'marcher' else {}
        target = target or field_combat.nearest(row, targets)
        if not target or target['kind'] != 'marcher' or remaining[target['id']] <= 0: continue
        if fort.blocker(row, target['attributes'], structures) and a.get('suit') != 'Vulture' and row['kind'] == 'marcher': continue
        scenarios = [row]
        if row.get('planned'):
            # Discount by coarse public spawn coverage. Both melee and ranged
            # recruits can attack immediately; none gets free birth movement.
            # These nine samples are not the hidden keyed spawn positions.
            scenarios = [dict(row, attributes=dict(a, x_fp=x if f.pid == 0 else 2400-x, y_fp=y))
                         for x in (0, 60, 120) for y in (90, 300, 510)]
        windows = [_window(s, target, number, f.world) for s in scenarios]
        raw = sum(w['hits']*_land_percent(target, w['kind']) for w in windows)//len(windows)
        base = a['attack']+field_combat.matchup_bonus(row, target)+monster_effects.hunt_bonus(row, target)
        # Share one finite target budget across attackers; do not price six
        # bonuses on every friendly body against one nearly-dead victim.
        credited = min(raw, (remaining[target['id']]+base)//(base+1))
        if not credited: continue
        remaining[target['id']] = max(0, remaining[target['id']]-credited*(base+1))
        hit_units += credited
        packets.append(dict(attacker_id=row['id'], target_id=target['id'], planned=row.get('planned', False),
                            kind=windows[0]['kind'], hit_hundredths=credited,
                            first_tick=min(w['first_tick'] for w in windows if w['hits']),
                            placement_samples=len(windows), covered_samples=sum(w['hits'] > 0 for w in windows)))
    offense = max(0, HIT_VALUE*min(HIT_CAP, hit_units)//100-CAST_RESERVE)
    return dict(score=offense+delay_score, offense_score=offense, delay_score=delay_score,
                hit_hundredths=hit_units, attacks=packets, threats=threats, gate_threats=gates,
                distant=distant, overwhelmed=overwhelmed, planned_recruits=len(recruits),
                consumed_excluded=len(excluded.intersection(r['id'] for r in f.units(f.pid, lane))))
