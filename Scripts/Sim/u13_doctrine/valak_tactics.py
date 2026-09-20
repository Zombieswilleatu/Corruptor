"""Bounded public Valak estimates: two-phase geometry, never a combat rollout.

Twenty coarse movement samples per body expose possible pulls and core crossings.
No targeting, attacks, RNG or hidden orders are simulated. Later exposure is
discounted; existing competing wells suppress estimates rather than stack them.
"""
from math import isqrt

from u13_pysim import field_fortifications as fort, veil
from u13_pysim.battle import targetable
from u13_pysim.copying import copy_data
from u13_pysim.development import intact
from u13_pysim.marching_spatial import GRAVITY_CORE, GRAVITY_PULL, GRAVITY_RADIUS, GRAVITY_DAMAGE_INTERVAL, swept
from .facts import Facts
from .lane_support import free_to_advance, travel
from .orias_tactics import _support, _spent_cards
from .diagnostics import fingerprint


def _x(f, a):
    return a['x_fp'] if f.pid == 0 else 2400-a['x_fp']


def orb_targets(f, lane):
    """Six placements per lane: current cluster, trailing pull and future path."""
    cluster, _ = f.cluster(lane, GRAVITY_RADIUS, friendly_penalty=0)
    if not cluster: return
    seen = set()
    enemies = sorted(f.units(f.enemy, lane), key=lambda r: (_x(f, r['attributes']), r['id']))
    anchors = [cluster['field_position']]
    anchors += [r['attributes'] for r in enemies if fort.distance(r['attributes'], anchors[0]) > GRAVITY_RADIUS**2][:1]
    for a in anchors:
        for offset in (0, 160, -min(800, max((travel(r['attributes'], f.v['round']) for r in enemies), default=0))):
            x = max(0, min(2400, _x(f, a)+offset))
            point = dict(x_fp=x if f.pid == 0 else 2400-x, y_fp=a['y_fp']+(150 if a['y_fp'] <= 300 else -150) if offset == 160 else a['y_fp'])
            key = (point['x_fp'], point['y_fp'])
            if key in seen: continue
            seen.add(key)
            yield dict(lane=lane, field_position=point)


def _trace(f, row, foes, point):
    a = row['attributes']; x, y = a['x_fp'], a['y_fp']; normal = x
    direction = 1 if row['owner'] == 0 else -1
    destination = dict(x_fp=2400 if direction == 1 else 0, y_fp=y)
    advancing = free_to_advance(row, foes) and not fort.blocker(row, destination, fort.rows(f.world))
    core, core_tick, entry, exposure, contraction, delay = False, None, None, 0, 0, 0
    # Nominal trajectory only. Pull is additive, including on engaged/waiting
    # bodies, but birth-round movement hold also suppresses their pull.
    for elapsed in range(0, 400, 20):
        number = f.v['round']+elapsed//200
        step = travel(a, number)//200 if advancing else 0
        if a.get('rout_round') == number: step = 0  # Unknown retreat path: no delay credit.
        collapse = veil.affects(f.world, 'Valak', row['owner'])
        if collapse: step //= 2
        nx, ny = max(0, min(2400, x+direction*20*step)), y
        normal = max(0, min(2400, normal+direction*20*step))
        gap = (x-point['x_fp'])**2+(y-point['y_fp'])**2
        if gap <= GRAVITY_RADIUS**2:
            if entry is None: entry = elapsed
            exposure += 20 if elapsed < 200 else 10
            if a.get('movement_ready_round', 0) <= number:
                pull = 20*(GRAVITY_PULL//2 if collapse else GRAVITY_PULL)
                length = max(1, isqrt(gap))
                # Avoid stepping through the center merely through coarse pull.
                pull = min(pull, length)
                dx, dy = point['x_fp']-x, point['y_fp']-y
                nx += (1 if dx >= 0 else -1)*(abs(dx)*pull//length)
                ny += (1 if dy >= 0 else -1)*(abs(dy)*pull//length)
                contraction += pull if elapsed < 200 else pull//2
        if swept(x, y, nx, ny, point['x_fp'], point['y_fp']):
            core = True; core_tick = elapsed
            if entry is None: entry = elapsed
            break
        x, y = nx, ny
        delta = direction*(normal-x)
        if abs(delta) > abs(delay): delay = delta
        if x <= 0 or x >= 2400: break
    return dict(core=core, core_tick=core_tick, entry_tick=entry, exposure=exposure, contraction=contraction,
                delay_fp=delay, entry_next_round=entry is not None and entry >= 200)


def orb_value(f, target, ctx=None):
    cache = getattr(f, '_valak_orbs', None)
    if cache is None: f._valak_orbs = cache = {}
    key = fingerprint([target, ctx])
    if key in cache: return copy_data(cache[key])
    lane, point = target['lane'], target['field_position']
    allies, enemies = _support(f, lane, ctx), f.units(f.enemy, lane)
    damage, control, friendly, details = 0, 0, 0, []
    for row in enemies+allies:
        own = row['owner'] == f.pid
        trace = _trace(f, row, enemies if own else allies, point)
        if trace['entry_tick'] is None: continue
        a = row['attributes']
        health = a['hp']+a['armor']
        harm = min(health, trace['exposure']//GRAVITY_DAMAGE_INTERVAL)*3
        if trace['core']:
            # A future contact is conditional, never all HP worth of damage.
            harm = 12+min(12, health*2)
            if trace['core_tick'] > 0: harm = harm*2//3
            if trace['core_tick'] >= 200: harm //= 2
        # Another well owns some of this exposure; do not double-credit it.
        if any(o['target']['lane'] == lane and fort.distance(o['target']['field_position'], point) < GRAVITY_RADIUS**2
               for o in f.v['data'].get('valak_orbs', [])):
            harm //= 2
        support = 0
        if not own and not trace['core']:
            for ally in allies:
                b = ally['attributes']
                if b.get('hidden'): continue
                reach = 400 if b.get('suit') == 'Vulture' else 90
                if fort.distance(b, point) <= (reach+100)**2:
                    support = max(support, min(6, trace['contraction']//40))
            for tower in fort.rows(f.world):
                b = tower['attributes']
                if tower['owner'] == f.pid and b['lane'] == lane and b['structure'] == 'Tower' and b['hp'] > 0 and fort.distance(b, point) <= fort.TOWER_RANGE**2:
                    support = max(support, min(6, trace['contraction']//40))
        useful_delay = 0
        if not own and not trace['core']:
            x = _x(f, a)
            threatens = x <= travel(a, f.v['round'])+travel(a, f.v['round']+1)
            if threatens or support: useful_delay = max(-8, min(10, trace['delay_fp']//30))
        if own:
            # Friendly losses cost more than equal enemy material; pulling our
            # survivors back also delays their contribution.
            friendly += (harm*3+1)//2+max(0, min(6, trace['delay_fp']//40))
        else:
            damage += harm; control += support+useful_delay
        details.append(dict(entity_id=row['id'], friendly=own, harm_score=harm,
                            support_score=support, delay_score=useful_delay, **trace))
    value = dict(score=damage+min(24, control)-friendly-6, damage_score=damage,
        control_score=min(24, control), friendly_cost=friendly, bodies=details, phases=2,
        planned_recruits=sum(bool(r.get('planned')) for r in allies),
        reason='two_round_pull_support_and_friendly_exposure')
    cache[key] = value
    return copy_data(value)


def _victim(rows, spend):
    return min((r for r in rows if r['attributes']['value'] <= spend),
        key=lambda r: (-r['attributes']['value'], r['attributes']['slot'], r['id']), default=None)


def _follow_up(f, plan, ctx, victim):
    remaining = [r for r in f.hand if r['id'] not in _spent_cards(f, plan)]
    if not remaining: return 0
    rows = copy_data([r for r in f.rows if r['id'] not in ctx['guard_losses'] and r['id'] not in ctx['consumed_supplicants']])
    for r in rows:
        if r['id'] in ctx['castle_hits']:
            a = r['attributes']; a['integrity'] = max(0, a['integrity']-ctx['castle_hits'][r['id']])
            if a['integrity'] == 0: a['status'] = 'ruined'
    before = Facts(dict(f.v, board=rows, hand=remaining))
    after = Facts(dict(f.v, board=[r for r in rows if r['id'] != victim['id']], hand=remaining))
    lane = victim['attributes']['lane']; action = 'Hunt' if lane == 'Lord' else 'Siege'
    if action == 'Hunt' and not before.lord[f.enemy]['attributes']['alive']: return 0
    targets = [before.lord[f.enemy]['id']] if action == 'Hunt' else [c['id'] for c in before.castles(f.enemy) if targetable(c)] or ['castle_zone:'+str(f.enemy)]
    best = 0
    for target in targets:
        a, b = [state.attack(action, target, [r['id'] for r in remaining]) for state in (before, after)]
        benefit = 3*(b['damage']-a['damage'])+32*(int(b['banished'])-int(a['banished']))+30*(int(b['destroyed'])-int(a['destroyed']))+12*(int(b['pillage'])-int(a['pillage']))
        best = max(best, benefit//2)
    return min(18, best)


def projection_value(f, target, spend, plan=None, ctx=None):
    from .coordination import context
    plan = plan or dict(powers=[], order={})
    ctx = ctx or context(f, plan)
    own = target['player_id'] == f.pid; lane = target['zone']
    rows = list(f.guards(target['player_id'], lane))
    if own:
        for move in plan['order'].get('guard_moves', []):
            if move['lane'] != lane: continue
            r = copy_data(f.by_id[move['card_id']]); r['attributes'].update(role='guard', lane=lane, slot=move['slot'])
            rows.append(r)
    before = _victim(rows, spend)
    remaining = [r for r in rows if own or r['id'] not in ctx['guard_losses']]
    victim = _victim(remaining, spend)
    reserve = 0 if own else 5*max(0, 2-(f.resources['life_essence']-spend))
    value = dict(score=-3*spend-reserve, victim_id=victim['id'] if victim else '', spend=spend,
        eligible_before=[r['id'] for r in rows if r['attributes']['value'] <= spend],
        eligible_after=[r['id'] for r in remaining if r['attributes']['value'] <= spend],
        target_value_before=before['attributes']['value'] if before else 0,
        target_value_after=victim['attributes']['value'] if victim else 0,
        timing='post_resolution_direct', certainty='current_board_scenario',
        follow_up_score=0, net_essence=-spend, reason='attack_removes_projection_targets' if before and not victim else 'projection_target_remains')
    if not victim: return value
    a = victim['attributes']; pool = f.resources['life_essence']
    if own:
        net = min(5, pool-spend+2)-pool
        pairs = [p for p in f.v['data']['guard_work']['pairs'] if victim['id'] in p['ids'] and intact(f.world, p)]
        # Fresh same-suit deployment may bond with another newly placed Guard.
        fresh = [m for m in plan['order'].get('guard_moves', []) if m['lane'] == lane and f.by_id[m['card_id']]['attributes']['suit'] == a['suit']]
        pair_cost = 12 if pairs or len(fresh) >= 2 and victim['id'] in [m['card_id'] for m in fresh] else 0
        pressure = any(r['attributes'].get('waiting') or _x(f, r['attributes']) <= travel(r['attributes'], f.v['round'])+90 for r in f.units(f.enemy, lane))
        future = any(pool < r['attributes']['value'] <= pool+net for zone in ('Lord', 'Castle') for r in f.guards(f.enemy, zone))
        value.update(score=6*net-5*a['value']-pair_cost-8*int(pressure)+5*int(future and net > 0),
                     net_essence=net, pair_cost=pair_cost, pressure=pressure, reason='sacrifice_for_useful_essence')
        if net <= 0 or not future: value['score'] = min(-1, value['score'])
    else:
        follow = _follow_up(f, plan, ctx, victim)
        reserve = 5*max(0, 2-(pool-spend))
        value.update(score=10+4*a['value']-3*spend-reserve+follow,
                     follow_up_score=follow, reserve_cost=reserve,
                     reason='attack_reduces_projection_target' if before and a['value'] < before['attributes']['value'] else 'projection_target_remains')
    return value
