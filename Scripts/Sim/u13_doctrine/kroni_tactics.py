"""Kroni's public meal priorities and a bounded ensemble of erratic routes.

No hidden orders, activation seed or future random angle is consulted. Twelve
representative bouncing angles estimate exposure, not casualties. Authoritative
launch selection still uses all 48 angles and its independent keyed RNG.
"""
from u13_pysim.copying import copy_data
from u13_pysim.development import intact
from u13_pysim import veil, recruitment
from .diagnostics import fingerprint
from .facts import LANES
from .lane_support import free_to_advance, travel
from .orias_tactics import _support

ANGLES = (-24, -20, -16, -12, -8, -4, 4, 8, 12, 16, 20, 24)


def paired(f, guard):
    return any(guard['id'] in p['ids'] and intact(f.world, p)
               for p in f.v['data']['guard_work']['pairs'])


def consume_targets(f):
    # Preserve the best target in BOTH lanes before shared target retention.
    for lane in LANES:
        rows = f.guards(f.enemy, lane)
        if rows:
            yield min(rows, key=lambda r: (-int(paired(f, r)), -r['attributes']['value'], r['id']))


def compatible(f, target, plan):
    if target.get('mode')=='guard_bounce':return True
    order = plan['order']
    return (order.get('action') not in ('Hunt', 'Siege') or
            f.by_id[target['entity_id']]['attributes']['lane'] != order['lane'])


def consume_value(f, target, plan=None):
    if target.get('mode')=='guard_bounce':return bounce_value(f,plan)
    plan = plan or dict(powers=[], order={})
    guard = f.by_id[target['entity_id']]; pair = paired(f, guard)
    a = f.lord[f.pid]['attributes']; hunger = a['hunger']
    if plan['order'].get('action') in ('Ward', None): hunger = max(0, hunger-1)
    feed = 8 if hunger == 0 else 14 if hunger == 2 else 3
    if hunger == 2 and not a.get('hunger_milestone'): feed += 16
    # A successful next-round bite also avoids eating our weakest Guard or
    # losing Hunger. The current source must survive; these are conditional.
    own = [r for lane in LANES for r in f.guards(f.pid, lane)]
    protection = 6 if own else 3
    credit = 12+4*guard['attributes']['value']+32*int(pair)+feed+protection
    allowed = compatible(f, target, plan)
    return dict(score=credit if allowed else -credit, pair=pair, target_id=guard['id'],
                lane=guard['attributes']['lane'], target_value=guard['attributes']['value'],
                feed_score=feed, cannibal_protection=protection, compatible=allowed,
                reason='opposite_lane_pair_first_meal' if allowed else 'consume_same_attack_lane_forbidden',
                timing='next_round_start', certainty='source_and_target_must_survive')


def ravenous_targets(f):
    if not any(f.units(f.enemy, lane) for lane in LANES): return
    for lane in LANES:
        for y in (150, 300, 450):
            yield dict(lane=lane, field_position=dict(x_fp=0 if f.pid == 0 else 2400, y_fp=y))


def _near(f, row, start, angle, radius, foes):
    a = row['attributes']; x = a['x_fp'] if f.pid == 0 else 2400-a['x_fp']
    speed = travel(a, f.v['round'])//200 if free_to_advance(row, foes) else 0
    if veil.affects(f.world, 'Valak', row['owner']): speed //= 2
    # Birth-round recruits can be eaten immediately; they do not move early.
    relative = 16+speed if row['owner'] == f.enemy else max(1, 16-speed)
    forward = x*16//relative  # Forward coordinate where actor and body meet.
    if not 0 <= forward <= 2400: return False
    lateral = (start+angle*forward//16) % 2400
    if lateral > 1200: lateral = 2400-lateral
    body_y = a['y_fp']+(600 if a['lane'] == 'Castle' else 0)
    # Perpendicular distance to a candidate line, including bounced sections.
    gap = abs(body_y-lateral)
    return gap*gap*256 <= radius*radius*(256+angle*angle)


def ravenous_value(f, target, ctx=None, plan=None):
    key = fingerprint([target, ctx, (plan or {}).get('order', {}).get('action')])
    if not hasattr(f, '_kroni_routes'): f._kroni_routes = {}
    if key in f._kroni_routes: return copy_data(f._kroni_routes[key])
    own = [r for lane in LANES for r in _support(f, lane, ctx)]
    if ctx:
        for lane, count in sorted(ctx['power_bodies_minimum'].items()):
            for index in range(count):
                # Unknown Wish suit: price the guaranteed body as exposure,
                # without granting a particular attack or special ability.
                attrs = recruitment.profile('Butcher', lane, f.pid, f.v['round'], f.v['round']+1)
                attrs.update(x_fp=60 if f.pid == 0 else 2340, y_fp=300, suit='Unknown')
                own.append(dict(id='kroni_power_recruit:'+lane+str(index), kind='marcher', owner=f.pid, attributes=attrs, planned=True))
    enemy = [r for lane in LANES for r in f.units(f.enemy, lane)]
    a = f.lord[f.pid]['attributes']; hunger = a['hunger']
    if plan and plan['order'].get('action') in ('Ward', None): hunger = max(0, hunger-1)
    radius = (220, 242, 264, 297)[min(3, hunger)]
    start = target['field_position']['y_fp']+(600 if target['lane'] == 'Castle' else 0)
    rows = []
    for angle in ANGLES:
        foes = [r for r in enemy if _near(f, r, start, angle, radius, own)]
        allies = [r for r in own if _near(f, r, start, angle, radius, enemy)]
        # Fear is useful only with a public nearby army able to exploit it or
        # an imminent gate threat. Never call every fleeing unit a free kill.
        pressure = 0
        for r in enemy:
            if not _near(f, r, start, angle, radius*2, own): continue
            b = r['attributes']; x = b['x_fp'] if f.pid == 0 else 2400-b['x_fp']
            support = any(q['attributes']['lane'] == b['lane'] and not q['attributes'].get('hidden') and
                (q['attributes']['x_fp']-b['x_fp'])**2+(q['attributes']['y_fp']-b['y_fp'])**2 <=
                (400 if q['attributes'].get('suit') == 'Vulture' else 120)**2 for q in own)
            if support or x <= travel(b, f.v['round']): pressure += 2
        enemy_value = sum(8+min(4, (r['attributes']['hp']+r['attributes']['armor'])//4) for r in foes)
        friendly_cost = sum(12+min(6, (r['attributes']['hp']+r['attributes']['armor'])//3) for r in allies)
        # Half material credit: one bite at a time and fleeing break dense
        # static intersections. Eleven intersections are NOT eleven assured enemy meals.
        reward = 6 if len(foes) >= 11 else 0
        rows.append(dict(angle=angle, weight=16+angle*angle, enemies=len(foes), allies=len(allies),
                         material=(enemy_value-friendly_cost)//2, control=min(8, pressure), reward=reward))
    favored = [r for r in rows if r['enemies'] >= 2]
    used = favored or rows
    weight = sum(r['weight'] for r in used)
    mean = sum(r['weight']*(r['material']+r['control']+r['reward']) for r in used)//weight
    risky = sum(r['weight'] for r in used if r['material'] < 0)*100//weight
    value = dict(score=mean-6, reason='varied_routes_meals_fear_and_friendly_risk',
                 route_samples=len(rows), qualifying_samples=len(favored), downside_percent=risky,
                 friendly_recruits=sum(bool(r.get('planned')) for r in own),
                 consumed_supplicants=len(ctx['consumed_supplicants']) if ctx else 0,
                 power_bodies_minimum=sum(ctx['power_bodies_minimum'].values()) if ctx else 0, routes=rows,
                 timing='post_resolution_special_actors', certainty='route_exposure_not_predicted_casualties')
    f._kroni_routes[key] = value
    return copy_data(value)


def bounce_value(f,plan=None):
    """Enumerate public route geometry; no seed or future victim knowledge."""
    from u13_pysim.guard_consume import guards,route,VELOCITIES
    cache=getattr(f,'_consume_bounce',None)
    if cache is None:
        rows=guards(f.world);by_id={r['id']:r for r in rows};score=enemy=own=0
        for side,weight in ((f.enemy,60),(f.pid,40)):
            for vx,vy in VELOCITIES:
                for sign in (-1,1):
                    choice=route(rows,sign*vx,vy if side==0 else -vy)
                    r=by_id.get(choice['victim_id'])
                    if r is None:continue
                    value=12+4*r['attributes']['value']+32*int(paired(f,r))
                    if r['owner']==f.enemy:score+=weight*(value+8);enemy+=weight
                    else:score-=weight*value;own+=weight
        cache=dict(base=score//1200,enemy_percent=enemy//12,friendly_percent=own//12)
        f._consume_bounce=cache
    protection=6 if any(f.guards(f.pid,lane) for lane in LANES) else 3
    return dict(score=cache['base']+protection,reason='neutral_bounce_expected_meal',
                enemy_percent=cache['enemy_percent'],friendly_percent=cache['friendly_percent'],
                timing='next_round_start',certainty='current_layout_route_samples_not_future_victim')
