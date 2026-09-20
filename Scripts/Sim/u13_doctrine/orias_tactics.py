"""Orias public, bounded control estimates; no enemy orders or Marching rollouts.

Web compares nominal straight travel with travel through a half-speed circle.
Snare compares two explicit next-round Guard scenarios using cards still held.
Neither projection promises survival, enemy deployments or a future attack.
"""
from math import isqrt

from u13_pysim import field_combat, field_fortifications as fort, monsters, recruitment, veil
from u13_pysim.battle import defense, operational, targetable
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import RULES
from .facts import Facts, LANES
from .lane_support import free_to_advance, mobile, travel
from .veil_judgment import settlement_projection

RADIUS = RULES['Web']['spatial_field']['radius_fp']
PHASES = len(RULES['Web']['stages'])
GUARD_VALUES = (2, 4)


def _x(f, a):
    return a['x_fp'] if f.pid == 0 else 2400-a['x_fp']


def _support(f, lane, ctx):
    excluded = set(ctx['consumed_supplicants']) if ctx else set()
    rows = [r for r in f.units(f.pid, lane) if r['id'] not in excluded]
    if ctx and ctx['recruit_lane'] == lane:
        profiles = [(s, count, False) for s, count in ctx['recruit_suits'].items()]
        if ctx['monster']:
            profiles.append((ctx['monster'], ctx['monster_bodies_minimum'], True))
        for name, count, monster in profiles:
            a = (monsters.profile if monster else recruitment.profile)(name, lane, f.pid, f.v['round'], f.v['round']+1)
            # A coarse spawn-area support estimate, not keyed placement. Every
            # recruit can attack now; movement readiness does not gate firing.
            a.update(x_fp=60 if f.pid == 0 else 2340, y_fp=300)
            rows.extend(dict(id='web_recruit:'+name+':'+str(i), kind='marcher', owner=f.pid,
                             attributes=copy_data(a), planned=True) for i in range(count))
    return rows


def _bounds(f, row, point, radius):
    dy = abs(row['attributes']['y_fp']-point['y_fp'])
    if dy > radius: return None
    reach = isqrt(radius*radius-dy*dy)
    center = _x(f, point)
    return max(0, center-reach), min(2400, center+reach)


def _distance_in_web(x, budget, bounds):
    """Distance advanced for a nominal movement budget; no tick simulation."""
    if not bounds: return min(x, budget)
    low, high = bounds
    before, inside = max(0, x-high), max(0, min(x, high)-low)
    if budget <= before or not inside: return min(x, budget)
    return min(x, before+min(inside, (budget-before)//2)+max(0, budget-before-2*inside))


def web_value(f, target, ctx=None):
    lane, point, number = target['lane'], target['field_position'], f.v['round']
    allies, enemies = _support(f, lane, ctx), f.units(f.enemy, lane)
    visible = [r for r in allies if not r['attributes'].get('hidden', False)]
    structures = fort.rows(f.world)
    shooters = [r for r in visible if r['attributes'].get('suit') == 'Vulture']
    shooters += [r for r in structures if r['owner'] == f.pid and r['attributes']['lane'] == lane
                 and r['attributes']['structure'] == 'Tower' and r['attributes']['hp'] > 0]
    engaged = [r for r in visible if field_combat.nearest(r, enemies, 90, True)]
    initial, kills, slowed, control = [], [], [], 0
    for enemy in enemies:
        a = enemy['attributes']; x = _x(f, a)
        if fort.distance(a, point) <= RADIUS*RADIUS:
            initial.append(enemy['id'])
            if a['hp']+a['armor'] <= 1: kills.append(enemy['id'])
        # Web changes movement, not attack speed. Do not price stationary
        # melee, firing Vultures, waiting Supplicants or turrets as suppressed.
        if not free_to_advance(enemy, visible) or a.get('rout_round') == number: continue
        destination = dict(x_fp=0 if f.pid == 0 else 2400, y_fp=a['y_fp'])
        if fort.blocker(enemy, destination, structures): continue
        first = travel(a, number)
        total = first+travel(a, number+1)
        bounds = _bounds(f, enemy, point, RADIUS)
        normal, changed = min(x, total), _distance_in_web(x, total, bounds)
        # Even a unit reaching the gate in both scenarios can spend longer in
        # a firing arc. Endpoint displacement alone would miss that benefit.
        inside = max(0, min(x, bounds[1])-bounds[0]) if bounds else 0
        traversed = min(inside, max(0, total-max(0, x-bounds[1]))//2) if bounds else 0
        delay = max(normal-changed, min(x, first)-_distance_in_web(x, first, bounds), traversed)
        if delay <= 0: continue
        gate_now = x <= first and _distance_in_web(x, first, bounds) < x
        gate_later = x <= total and changed < x
        gate = 14 if gate_now else 9 if gate_later else 0
        coverage = 0
        for shooter in shooters:
            b = shooter['attributes']
            if b.get('hidden') or b.get('rout_round') == number: continue
            # Any recruit can fire now. Its sampled spawn support receives a
            # discount; it earns no imaginary movement on its birth round.
            radius = 600 if shooter['kind'] == 'fortification' else 400
            shooting = _bounds(f, enemy, b, radius)
            if not shooting or not bounds: continue
            stop = 400 if a.get('suit') == 'Vulture' else 90
            lower = max(bounds[0], shooting[0], _x(f, b)+stop, x-total)
            upper = min(bounds[1], shooting[1], x)
            if upper > lower and b.get('ranged_next_tick', 0) < (number+PHASES)*200:
                worth = 4 if shooter.get('planned') else 8
                coverage = max(coverage, min(worth, worth*(upper-lower)//180))
        nearby = [r for r in visible if fort.gap(enemy, r) <= (total+travel(r['attributes'], number)+90)**2]
        force = sum(r['attributes']['hp']+r['attributes']['armor']+r['attributes']['attack'] for r in nearby)
        pressure = sum(r['attributes']['hp']+r['attributes']['armor']+r['attributes']['attack'] for r in enemies
                       if fort.gap(enemy, r) <= (total+90)**2)
        relief = 8 if force and pressure*2 > force*3 else 0
        reinforcement = 6 if any(fort.gap(enemy, r) <= (total+90)**2 for r in engaged) else 0
        value = max(gate, min(coverage, coverage*delay//180), min(relief, relief*delay//180),
                    min(reinforcement, reinforcement*delay//180))
        later = bool(bounds and x-bounds[1] >= first and x > bounds[1])
        if later: value = value*3//4
        control += value
        slowed.append(dict(entity_id=enemy['id'], delay_distance_equivalent_fp=delay, entry_next_round=later,
                           gate_score=gate, ranged_score=coverage, relief_score=relief,
                           reinforcement_score=reinforcement, score=value))
    damage = 3*min(6, len(initial))+6*min(3, len(kills))
    return dict(score=max(0, damage+min(48, control)-6), damage_score=damage,
                control_score=min(48, control), initial_hits=initial, potential_kills=kills,
                slowed=slowed, phases=PHASES, planned_recruits=sum(r.get('planned', False) for r in allies))


def web_targets(f, lane):
    """Three public groups, two placements each; consumed under proposal budget."""
    enemies = sorted(f.units(f.enemy, lane), key=lambda r: (
        -int(r['attributes']['hp']+r['attributes']['armor'] <= 1),
        -int(mobile(r['attributes']) and not r['attributes'].get('waiting')),
        _x(f, r['attributes']), r['id']))
    anchors, seen = [], set()
    for row in enemies:
        # Avoid spending every spatial proposal on almost identical positions.
        if any(fort.distance(row['attributes'], a) <= (RADIUS//2)**2 for a in anchors): continue
        anchors.append(row['attributes'])
        if len(anchors) == 3: break
    for a in anchors:
        # Put the front edge near the visible wave's nominal position at the
        # next Marching phase, so empty ground can be a useful future field.
        for lead in (0, travel(a, f.v['round'])+RADIUS):
            x = max(0, _x(f, a)-lead)
            position = dict(x_fp=x if f.pid == 0 else 2400-x, y_fp=a['y_fp'])
            identity = (position['x_fp'], position['y_fp'])
            if identity in seen: continue
            seen.add(identity)
            yield dict(lane=lane, field_position=position)


def _spent_cards(f, plan):
    hand = {r['id'] for r in f.hand}
    def walk(value):
        if isinstance(value, dict):
            return set().union(*(walk(v) for v in value.values()))
        if isinstance(value, list):
            return set().union(*(walk(v) for v in value))
        return {value} if isinstance(value, str) and value in hand else set()
    return walk(plan)


def _snare_cost(f, plan):
    actor = f.lord[f.pid]; before = actor['attributes'].get('threat', 0)
    later = copy_data(actor); later['attributes']['threat'] = before+1
    loss = defense(f.world, actor)-defense(f.world, later)
    circle = next((c for c in f.castles(f.pid) if c['attributes']['castle_type'] == 'SummoningCircle'
                   and operational(c)), None) if loss else None
    order = plan['order']
    # A Lord Ward can reduce the gained Threat later, but cannot undo an
    # already exerted Circle or the earlier window of lower Lord defense.
    ward = order.get('action') == 'Ward' and order.get('lane') == 'Lord'
    score = 6+4*min(3, before)+4*loss if not circle else 6+9
    if ward and not circle: score = max(4, score-4)
    return dict(score=score, threat_before=before, threat_after=before+int(not circle),
                defense_loss=loss if not circle else 0, circle_id=circle['id'] if circle else '',
                circle_integrity_cost=3 if circle else 0)


def _guard_scenario(f, lane, value, count):
    view = dict(f.v, board=copy_data(f.rows))
    for slot in f.free(f.enemy, lane)[:count]:
        view['board'].append(dict(id='snare_scenario:'+str(slot), kind='card', owner=f.enemy,
            attributes=dict(role='guard', lane=lane, slot=slot, suit='Butcher', value=value)))
    return Facts(view)


def snare_value(f, plan, ctx):
    cost = _snare_cost(f, plan)
    result = dict(score=-cost['score'], benefit=0, cost=cost, follow_up=None,
                  effective_round=f.v['round']+1, reason='no_supported_next_round_attack')
    if settlement_projection(f, plan)['winner'] != -1:
        result['reason'] = 'settlement_precedes_snare'; return result
    if any(r['declaration']['power_id'] == 'Snare' and r.get('fire_round') == f.v['round']+1
           and r['declaration']['player_id'] == f.pid for r in f.v['pending']):
        result['reason'] = 'next_round_already_snared'; return result
    spent = _spent_cards(f, plan)
    remaining = [r['id'] for r in f.hand if r['id'] not in spent]
    if not remaining: return result
    view = dict(f.v, board=copy_data([r for r in f.rows if r['id'] not in ctx['guard_losses']
                                    and r['id'] not in ctx['consumed_supplicants']]))
    arrivals = []
    for row in view['board']:
        a = row['attributes']
        if row['id'] in ctx['castle_hits']:
            a['integrity'] = max(0, a['integrity']-ctx['castle_hits'][row['id']])
            if a['integrity'] == 0: a['status'] = 'ruined'
        if row['kind'] == 'marcher' and row['owner'] == f.pid and not a.get('waiting'):
            foes = f.units(f.enemy, a['lane'])
            destination = dict(x_fp=2400 if f.pid == 0 else 0, y_fp=a['y_fp'])
            if (free_to_advance(row, foes) and a.get('rout_round') != f.v['round']
                    and 2400-_x(f, a) <= travel(a, f.v['round'])
                    and not fort.blocker(row, destination, fort.rows(f.world))):
                # Stop at visible interception: a clear endpoint alone is not
                # enough to promise passage through an approaching enemy.
                if any(fort.gap(row, e) <= (travel(a, f.v['round'])+travel(e['attributes'], f.v['round'])+90)**2 for e in foes): continue
                a['waiting'] = True; arrivals.append(row['id'])
    after = Facts(view)
    # A current one-round cap expires; only the public Orias breach can carry
    # its two-Guard limit forward without another declaration.
    limit = 2 if veil.affects(f.world, 'Orias', f.enemy) and f.lord[f.enemy]['attributes'].get('threat', 0) >= 2 else 6
    for lane in LANES:
        count = min(limit, len(after.free(f.enemy, lane)))
        if count <= 1: continue
        action = 'Hunt' if lane == 'Lord' else 'Siege'
        if action == 'Hunt':
            if not f.lord[f.enemy]['attributes']['alive']: continue
            spent_waiters = [key for spend in plan['order'].get('rites', {}).get('waiter_spends', []) for key in spend['marcher_ids']]
            if ctx['attack_lane'] == lane and f.attack(action, f.lord[f.enemy]['id'], plan['order']['card_ids'], spent_waiters)['banished']: continue
            targets = [f.lord[f.enemy]['id']]
        else:
            targets = [c['id'] for c in after.castles(f.enemy) if targetable(c)] or ['castle_zone:'+str(f.enemy)]
        for target in targets:
            scenarios, benefits = [], []
            for value in GUARD_VALUES:
                normal = _guard_scenario(after, lane, value, count)
                snared = _guard_scenario(after, lane, value, 1)
                base, capped = normal.attack(action, target, remaining), snared.attack(action, target, remaining)
                def penetration(state, attack):
                    return max(0, attack['strength']-sum(r['attributes']['value'] for r in state.guards(state.enemy, lane)))
                gain = (3*min(4, max(0, penetration(snared, capped)-penetration(normal, base)))
                        +3*max(0, capped['damage']-base['damage'])
                        +32*int(capped['banished'] and not base['banished'])
                        +30*int(capped['destroyed'] and not base['destroyed']))
                benefits.append(gain)
                scenarios.append(dict(new_guard_value=value, normal_new_guards=count, snared_new_guards=1,
                    normal_damage=base['damage'], snared_damage=capped['damage'], value=gain))
            # Half credit for next-round uncertainty; never assume an enemy
            # hand, a particular deployment, or newly drawn attacking cards.
            benefit = min(28, sum(benefits)//(2*len(benefits)))
            if benefit > result['benefit']:
                result.update(score=benefit-cost['score'], benefit=benefit,
                    reason='limit_reinforcement_before_follow_up',
                    follow_up=dict(action=action, lane=lane, target_id=target, card_ids=remaining,
                        arrivals=[r for r in arrivals if after.by_id[r]['attributes']['lane'] == lane],
                        existing_guards=[r['id'] for r in after.guards(f.enemy, lane)],
                        conditional_guard_losses=ctx['guard_losses'], scenarios=scenarios))
    return result
