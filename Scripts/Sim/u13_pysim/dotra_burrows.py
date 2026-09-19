"""Fixed burrow exits and visible-enemy isolation, matching U13DotraBurrows."""
from . import monsters as rules, field_fortifications as fort
from .copying import copy_data

GAP = 42


def distance(a, b):
    return (a['x_fp'] - b['x_fp'])**2 + (a['y_fp'] - b['y_fp'])**2


def begin(a, clock):
    clamp = lambda x, low, high: max(low, min(high, x))
    a.update(dotra_holes=[
        dict(x_fp=clamp(a['x_fp'], 30, 2370), y_fp=clamp(a['y_fp'], 180, 420)),
        dict(x_fp=clamp(a['x_fp'] + a['direction'] * 360, 30, 2370), y_fp=100),
        dict(x_fp=clamp(a['x_fp'] + a['direction'] * 600, 30, 2370), y_fp=500)],
        dotra_burrow_ready_tick=clock + rules.TUNING['dotra_burrow_ticks'],
        dotra_ambush_ready=False, dotra_ambush_target='', contact_tick=-1,
        waiting=False, waiting_since_round=0)


def visible_enemies(unit, rows, clock=-1):
    return [r for r in rows if r['kind'] == 'marcher' and r['owner'] != unit['owner']
            and r['attributes']['lane'] == unit['attributes']['lane']
            and not r['attributes'].get('hidden', False)
            and (clock < 0 or unit['attributes'].get('navigation', {}).get('avoid', {}).get(r['id'], 0) <= clock)]


def clear_exit(unit, point, rows, structures):
    if not (30 <= point['x_fp'] <= 2370 and 30 <= point['y_fp'] <= 570): return False
    if any(r['id'] != unit['id'] and r['attributes']['lane'] == unit['attributes']['lane']
           and distance(point, r['attributes']) < GAP**2 for r in rows): return False
    probe = copy_data(unit)
    probe['attributes'].update(point)
    return not any(r['attributes']['lane'] == unit['attributes']['lane']
                   and fort.gap(probe, r) < GAP**2 for r in structures)


def exits(unit, rows, structures):
    result = []
    for hole in unit['attributes'].get('dotra_holes', []):
        found = {}
        for radius in (0, 42, 84, 126):
            for dx, dy in ((1, 0), (0, -1), (0, 1), (-1, 0), (1, -1), (1, 1), (-1, -1), (-1, 1)):
                point = dict(x_fp=hole['x_fp'] + radius * dx * unit['attributes']['direction'], y_fp=hole['y_fp'] + radius * dy)
                if clear_exit(unit, point, rows, structures):
                    found = point
                    break
            if found: break
        result.append(found)
    return result


def isolated(unit, rows, points, clock=-1):
    def score(target):
        gaps = [distance(target['attributes'], ally['attributes']) for ally in rows
                if ally['id'] != target['id'] and ally['kind'] == 'marcher'
                and ally['owner'] == target['owner'] and ally['attributes']['lane'] == target['attributes']['lane']
                and not ally['attributes'].get('hidden', False)]
        return (sum(g <= rules.TUNING['dotra_isolation_radius']**2 for g in gaps),
                -min(gaps, default=10000000),
                min((distance(p, target['attributes']) for p in points if p), default=10000000), target['id'])
    return min(visible_enemies(unit, rows, clock), key=score, default={})


def choose_exit(unit, points, target):
    return min((i for i, p in enumerate(points) if p), default=-1,
               key=lambda i: distance(points[i], target['attributes']) if target else -points[i]['x_fp'] * unit['attributes']['direction'])


def prepared_target(unit, rows, clock):
    return next((r for r in visible_enemies(unit, rows, clock)
                 if r['id'] == unit['attributes'].get('dotra_ambush_target', '')),
                None) or isolated(unit, rows, [unit['attributes']], clock)
