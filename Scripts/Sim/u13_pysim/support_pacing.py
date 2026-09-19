"""Local support pacing, mirrored by U13SupportPacing.gd."""
RADIUS, WIDTH, TRAIL = 420, 180, 180
PENITENT_TRAIL = 90


def support(a):
    return a.get('suit') == 'Vulture' or a.get('monster_id') in ('Kopita', 'Sinodek', 'Sooge')


def support_speed(unit, rows, step, clock, number, fleeing=()):
    a = unit['attributes']
    if not support(a):
        return step
    screen, lead = None, -RADIUS - 1
    for other in rows:
        b = other['attributes']
        if other['id'] == unit['id'] or other['owner'] != unit['owner'] or b['lane'] != a['lane']:
            continue
        if b.get('suit') not in ('Butcher', 'Penitent') and b.get('monster_id') not in ('Lemek', 'Kurchin'):
            continue
        if (b['waiting'] or b['movement_ready_round'] > number or b.get('hidden', False)
                or b.get('rout_round', -1) == number or other['id'] in fleeing):
            continue
        dx, dy = b['x_fp'] - a['x_fp'], b['y_fp'] - a['y_fp']
        if abs(dy) > WIDTH or dx * dx + dy * dy > RADIUS * RADIUS:
            continue
        forward = dx * a['direction']
        if forward > lead:
            screen, lead = other, forward
    if screen is None:
        return step
    if lead >= TRAIL:
        return min(step, lead - TRAIL)
    if lead >= 0 and screen['attributes']['contact_tick'] >= 0:
        return 0
    return (step >> 2) + int((clock & 3) < (step & 3))


def speed(unit, rows, step, clock, number, fleeing=()):
    a = unit['attributes']
    if 'monster_id' in a or a.get('suit') not in ('Butcher', 'Wright'):
        return support_speed(unit, rows, step, clock, number, fleeing)
    if a.get('suit') == 'Wright' and not a.get('wright_released', False):
        return step
    screen, lead = None, -RADIUS - 1
    for other in rows:
        b = other['attributes']
        if other['owner'] != unit['owner'] or b['lane'] != a['lane'] or b.get('suit') != 'Penitent' or 'monster_id' in b:
            continue
        if b['waiting'] or b['movement_ready_round'] > number or b.get('hidden', False) or b.get('rout_round', -1) == number or other['id'] in fleeing:
            continue
        dx, dy = b['x_fp']-a['x_fp'], b['y_fp']-a['y_fp']
        if abs(dy) > WIDTH or dx*dx+dy*dy > RADIUS*RADIUS:
            continue
        forward = dx*a['direction']
        if forward > lead:
            screen, lead = other, forward
    if screen is None or screen['attributes']['contact_tick'] >= 0:
        return step
    if lead >= PENITENT_TRAIL:
        return min(step, lead-PENITENT_TRAIL)
    return (step >> 2) + int((clock & 3) < (step & 3))
