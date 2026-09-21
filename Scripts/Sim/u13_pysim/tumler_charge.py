"""Fixed-point Tumler charge. Mirror of U13TumlerCharge.gd."""
from . import monsters as rules, field_fortifications as fort, dotra_shroud as shroud

GAP = 42
PRIORITY = ('Sooge', 'Kopita', 'Fyra', 'Vulture')


def active(a):
    return a.get('tumler_charge_phase', '') in ('windup', 'charge')


def rank_target(unit):
    a = unit['attributes']; name = a.get('monster_id', a['suit'])
    return PRIORITY.index(name) if name in PRIORITY else 4


def legal(unit, target):
    return bool(target and target['kind'] == 'marcher' and target['owner'] != unit['owner']
                and target['attributes']['lane'] == unit['attributes']['lane']
                and target['attributes']['hp'] > 0 and shroud.targetable(target['attributes']))


def engaged_target(unit, rows):
    a = unit['attributes']; identity = a.get('tumler_engaged_target', '')
    if not identity or a.get('tumler_engaged_owner', -1) != unit['owner']: return {}
    return next((r for r in rows if r['id'] == identity and legal(unit, r)), {})


def clear_engagement(a):
    if 'tumler_engaged_target' not in a: return
    a.update(tumler_engaged_target='', tumler_engaged_owner=-1)


def select_target(unit, rows, clock):
    a = unit['attributes']
    if not active(a):
        engaged = engaged_target(unit, rows)
        if engaged: return engaged
    choices = [r for r in rows if legal(unit, r)]
    if active(a):
        return next((r for r in choices if r['id'] == a.get('tumler_charge_target', '')), {})
    choices = [r for r in choices if rank_target(r) < 4
               or a.get('navigation', {}).get('avoid', {}).get(r['id'], 0) <= clock]
    return min(choices, key=lambda r: (rank_target(r), fort.gap(unit, r), r['id']), default={})


def fact(kind, unit, context, tick, **extra):
    data = dict(unit_id=unit['id'], target_id=unit['attributes'].get('tumler_charge_target', ''),
                owner=unit['owner'], lane=unit['attributes']['lane'], round=context['round'], tick=tick)
    data.update(extra)
    return fort.event(kind, data)


def finish(unit, context, tick, reason):
    a = unit['attributes']
    # The combined Armor pool is spent normally. Remove only the unspent
    # temporary top layer, preserving any surviving pre-charge Armor.
    removed = max(0, a['armor'] - a.get('tumler_charge_base_armor', a['armor']))
    a['armor'] -= removed
    result = fact('MONSTER_CHARGE_ENDED', unit, context, tick, reason=reason, armor_removed=removed)
    if reason == 'target':
        a.update(tumler_engaged_target=a.get('tumler_charge_target', ''), tumler_engaged_owner=unit['owner'])
    else:
        clear_engagement(a)
    a.update(tumler_charge_phase='', tumler_charge_target='', tumler_charge_base_armor=0,
             tumler_charge_ready_tick=0, tumler_charge_end_tick=0,
             tumler_charge_goal_x_fp=0, tumler_charge_goal_y_fp=0)
    return result


def swept(a, b, p):
    dx, dy = b['x_fp'] - a['x_fp'], b['y_fp'] - a['y_fp']
    px, py = p['x_fp'] - a['x_fp'], p['y_fp'] - a['y_fp']
    length2, dot = dx*dx+dy*dy, px*dx+py*dy
    if length2 == 0 or dot < 0: return False
    if dot > length2: return fort.distance(b, p) < GAP*GAP
    cross = px*dy-py*dx
    return cross*cross < GAP*GAP*length2


def side_point(unit, other, heading, rows, structures):
    a, b = unit['attributes'], other['attributes']
    dx, dy = heading['x_fp']-a['x_fp'], heading['y_fp']-a['y_fp']
    scale = max(abs(dx), abs(dy))
    if scale == 0: return {}
    cross = dx*(b['y_fp']-a['y_fp'])-dy*(b['x_fp']-a['x_fp'])
    first = (1 if cross > 0 else -1) if cross else (1 if ord(other['id'][-1]) % 2 == 0 else -1)
    for reach in range(GAP*2, GAP*15, GAP):
        for side in (first, -first):
            p = dict(x_fp=b['x_fp']+int(-dy*reach*side/scale), y_fp=b['y_fp']+int(dx*reach*side/scale))
            if not (0 <= p['x_fp'] <= 2400 and 0 <= p['y_fp'] <= 600): continue
            if fort.blocked_step(other, p, structures) or fort.blocker(other, p, structures): continue
            if any(r['id'] != other['id'] and r['attributes']['lane'] == b['lane']
                   and fort.distance(p, r['attributes']) < GAP*GAP for r in rows): continue
            return p
    return {}


def advance(unit, target, buffer, structures, context, tick, live_target=True):
    a, b = unit['attributes'], target['attributes']
    dx, dy = b['x_fp']-a['x_fp'], b['y_fp']-a['y_fp']
    scale = max(abs(dx), abs(dy))
    p = dict(x_fp=a['x_fp'], y_fp=a['y_fp'])
    arrival = 'target' if live_target else 'destination'
    reason = arrival if fort.in_melee(unit, target) else ''
    wall = fort.blocker(unit, b, structures)
    if not reason and scale > 0:
        for offset in range(1, min(scale, rules.TUNING['tumler_charge_step_fp'])+1):
            candidate = dict(x_fp=a['x_fp']+int(dx*offset/scale), y_fp=a['y_fp']+int(dy*offset/scale))
            if fort.blocked_step(unit, candidate, structures): reason = 'wall'; break
            p = candidate; probe = dict(attributes=candidate)
            if wall and fort.in_melee(probe, wall): reason = 'wall'; break
            if fort.in_melee(probe, target): reason = arrival; break
    events = []
    for other in buffer.rows():
        if other['id'] in (unit['id'], target['id']) or other['attributes']['lane'] != a['lane'] or not swept(a, p, other['attributes']): continue
        shifted = side_point(unit, other, p, buffer.rows(), structures)
        if not shifted:
            # Crowded bodies never cancel the committed rush.
            continue
        before = dict(x_fp=other['attributes']['x_fp'], y_fp=other['attributes']['y_fp'])
        other['attributes'].update(shifted, contact_tick=-1)
        buffer.update(other['id'], other['owner'], other['attributes'])
        events.append(fact('MONSTER_CHARGE_DISPLACED', unit, context, tick,
                           displaced_id=other['id'], displaced_owner=other['owner'], **{'from': before, 'to': shifted}))
    a.update(p, contact_tick=-1)
    if reason: events.append(finish(unit, context, tick, reason))
    return events


def step(buffer, structures, context, tick, fleeing):
    events = []; clock = context['round']*200+tick; t = rules.TUNING
    for original in buffer.rows():
        if original['attributes'].get('monster_id') != 'Tumler': continue
        unit = buffer.get(original['id']); a = unit['attributes']
        allowed = (a['step_fp'] > 0 and not a['waiting'] and a['movement_ready_round'] <= context['round']
                   and a.get('rout_round', -1) != context['round'] and not a.get('hidden', False) and unit['id'] not in fleeing)
        if a.get('tumler_engaged_target', '') and (not allowed or not engaged_target(unit, buffer.rows())): clear_engagement(a)
        target = select_target(unit, buffer.rows(), clock)
        if active(a):
            live_target = legal(unit, target)
            if live_target:
                a.update(tumler_charge_goal_x_fp=target['attributes']['x_fp'], tumler_charge_goal_y_fp=target['attributes']['y_fp'])
            else:
                direction = 1 if a.get('tumler_charge_owner', unit['owner']) == 0 else -1
                target = dict(id=a.get('tumler_charge_target', ''), attributes=dict(
                    x_fp=a.get('tumler_charge_goal_x_fp', max(0, min(2400, a['x_fp']+direction*t['tumler_charge_range']))),
                    y_fp=a.get('tumler_charge_goal_y_fp', a['y_fp'])))
            a['tumler_charge_motion_tick'] = clock
            if a['tumler_charge_phase'] == 'windup' and clock >= a['tumler_charge_ready_tick']:
                a['tumler_charge_phase'] = 'charge'
                events.append(fact('MONSTER_CHARGE_LAUNCHED', unit, context, tick))
            if a['tumler_charge_phase'] == 'charge': events.extend(advance(unit, target, buffer, structures, context, tick, live_target))
        elif (allowed and clock >= a.get('tumler_charge_next_tick', 0)
              and legal(unit, target) and not fort.in_melee(unit, target) and fort.gap(unit, target) <= t['tumler_charge_range']**2):
            wall = fort.blocker(unit, target['attributes'], structures)
            if not wall or not fort.in_melee(unit, wall):
                a.update(hunt_target=target['id'], tumler_charge_phase='windup', tumler_charge_target=target['id'],
                         tumler_charge_owner=unit['owner'], tumler_charge_base_armor=a['armor'],
                         tumler_charge_goal_x_fp=target['attributes']['x_fp'], tumler_charge_goal_y_fp=target['attributes']['y_fp'],
                         armor=a['armor']+t['tumler_charge_armor'], tumler_charge_ready_tick=clock+t['tumler_charge_windup_ticks'],
                         tumler_charge_end_tick=clock+t['tumler_charge_windup_ticks']+t['tumler_charge_max_ticks'],
                         tumler_charge_next_tick=clock+t['tumler_charge_cooldown_ticks'], tumler_charge_motion_tick=clock, contact_tick=-1)
                events.append(fact('MONSTER_CHARGE_WINDUP', unit, context, tick, armor_gained=t['tumler_charge_armor'], ready_tick=a['tumler_charge_ready_tick']))
        buffer.update(unit['id'], unit['owner'], a)
    return events
