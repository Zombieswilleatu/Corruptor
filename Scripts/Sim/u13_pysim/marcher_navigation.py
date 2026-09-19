"""Deterministic local routes and bounded target retries; native mirror."""
from math import isqrt
from . import marcher_spacing as spacing, field_fortifications as fort
from .copying import copy_data

STALL_TICKS, RETRY_TICKS, CELL, SEARCH_RADIUS = 24, 80, 24, 14


def avoided(unit, target, clock):
    return bool(target) and unit['attributes'].get('navigation', {}).get('avoid', {}).get(target['id'], 0) > clock


def candidates(unit, targets, clock):
    return [t for t in targets if not avoided(unit, t, clock) or fort.in_melee(unit, t)]


def retained(unit, targets):
    nav = unit['attributes'].get('navigation', {})
    if not nav.get('path'): return {}
    return next((t for t in targets if t['id'] == nav.get('target') and t['owner'] != unit['owner'] and not t['attributes'].get('hidden', False)), {})


def route(unit, destination, rows, structures):
    a = unit['attributes']; side = 1 if ord(unit['id'][-1]) % 2 == 0 else -1
    offsets = ((1, 0), (0, side), (0, -side), (-1, 0))
    queue = [(0, 0)]; parents = {(0, 0): (0, 0)}
    points = {(0, 0): dict(x_fp=a['x_fp'], y_fp=a['y_fp'])}
    start_gap = fort.distance(a, destination)
    for cell in queue:
        point = points[cell]
        if cell != (0, 0) and fort.distance(point, destination) + CELL*CELL*4 < start_gap:
            path = []
            while cell != (0, 0):
                path.insert(0, points[cell]); cell = parents[cell]
            return path
        for dx, dy in offsets:
            nxt = cell[0]+dx, cell[1]+dy
            if abs(nxt[0]) > SEARCH_RADIUS or abs(nxt[1]) > SEARCH_RADIUS or nxt in parents: continue
            proposed = dict(x_fp=a['x_fp']+nxt[0]*a['direction']*CELL, y_fp=a['y_fp']+nxt[1]*CELL)
            origin = dict(unit, attributes=dict(a, **point))
            middle = dict(x_fp=(point['x_fp']+proposed['x_fp']) >> 1, y_fp=(point['y_fp']+proposed['y_fp']) >> 1)
            if not spacing.clear(origin, middle, rows, structures) or not spacing.clear(origin, proposed, rows, structures): continue
            parents[nxt] = cell; points[nxt] = proposed; queue.append(nxt)
    return []


def steer(unit, proposed, destination, target, rows, structures, step, clock, protected_target=False, retreat=False):
    if retreat or step <= 0: return spacing.slide(unit, proposed, rows, structures, step, not retreat and not protected_target)
    # A taunted fighter must be able to leave its previous melee contact.
    if not protected_target and any(other['owner'] != unit['owner'] and spacing.collides(unit, other) and fort.in_melee(unit, other) for other in rows): return unit['attributes']
    a = unit['attributes']
    goal = destination or dict(x_fp=2400 if unit['owner'] == 0 else 0, y_fp=a['y_fp'])
    nav = copy_data(a.get('navigation', {})); gap = fort.distance(a, goal)
    if 'progress' not in nav:
        nav = dict(target=target, best=gap, progress=clock, path=[], avoid={}, origin=dict(x_fp=a['x_fp'], y_fp=a['y_fp']))
    if nav.get('target', '') != target: nav.update(target=target, best=gap, path=[])
    nav['avoid'] = {key: value for key, value in nav['avoid'].items() if value > clock}
    if gap+step*step < nav['best'] and fort.distance(a, nav['origin']) >= 16**2:
        nav.update(best=gap, progress=clock, origin=dict(x_fp=a['x_fp'], y_fp=a['y_fp']))
    if not nav['path'] and clock-nav['progress'] >= STALL_TICKS:
        nav['path'] = route(unit, goal, rows, structures); nav['progress'] = clock
        if not nav['path'] and target and not protected_target: nav['avoid'][target] = clock+RETRY_TICKS
    if nav['path']:
        point = nav['path'][0]; dx, dy = point['x_fp']-a['x_fp'], point['y_fp']-a['y_fp']
        square = dx*dx+dy*dy; length = isqrt(square); length = max(1, length+int(length*length < square))
        def rounded(value):
            result = (abs(value)*step*2+length)//(2*length)
            return -result if value < 0 else result
        moved = copy_data(a)
        moved['x_fp'] += dx if length <= step else rounded(dx)
        moved['y_fp'] += dy if length <= step else rounded(dy)
        if spacing.clear(unit, moved, rows, structures):
            if length <= step: nav['path'].pop(0)
            nav['progress'] = clock
        else:
            nav['path'] = []; nav['progress'] = clock-STALL_TICKS
            moved = spacing.slide(unit, proposed, rows, structures, step, not protected_target)
    else: moved = spacing.slide(unit, proposed, rows, structures, step, not protected_target)
    moved = copy_data(moved); moved['navigation'] = nav
    return moved
