"""Small physical footprints, mirrored from U13MarcherSpacing.gd."""
from . import field_fortifications as fort, field_combat
from .copying import copy_data

GAP = 42


def collides(unit, other):
    return (unit['id'] != other['id'] and unit['attributes']['lane'] == other['attributes']['lane']
            and (unit['owner'] == other['owner'] or not field_combat.ignored(unit, other)))


def clear(unit, point, rows, structures, allow_escape=True):
    if not (0 <= point['x_fp'] <= 2400 and 0 <= point['y_fp'] <= 600): return False
    if fort.blocked_step(unit, point, structures) or fort.blocker(unit, point, structures): return False
    for other in rows:
        if not collides(unit, other): continue
        after = fort.distance(point, other['attributes'])
        if after < GAP**2 and (not allow_escape or after <= fort.distance(unit['attributes'], other['attributes'])):
            return False
    return True


def slide(unit, proposed, rows, structures, step, hold_contact=True):
    if hold_contact and any(other['owner'] != unit['owner'] and collides(unit, other) and fort.in_melee(unit, other) for other in rows):
        return unit['attributes']
    if clear(unit, proposed, rows, structures): return proposed
    side = 1 if ord(unit['id'][-1]) % 2 == 0 else -1
    mostly_forward = abs(proposed['x_fp']-unit['attributes']['x_fp']) >= abs(proposed['y_fp']-unit['attributes']['y_fp'])
    for sign in (side, -side):
        point = dict(unit['attributes'])
        if mostly_forward: point['y_fp'] = max(0, min(600, point['y_fp']+sign*step))
        else: point['x_fp'] = max(0, min(2400, point['x_fp']+sign*point['direction']*step))
        if clear(unit, point, rows, structures): return point
    return unit['attributes']


def anchored(unit, number):
    a = unit['attributes']
    return (a['waiting'] or a['movement_ready_round'] > number or a.get('sprite_form') == 'turret'
            or 'wright_site' in a and not a.get('wright_released', False))


def separate(s, structures, number):
    rows = s.rows()
    for unit in rows:
        if anchored(unit, number): continue
        if not any(collides(unit, other) and fort.distance(unit['attributes'], other['attributes']) == 0
                   and (other['id'] < unit['id'] or anchored(other, number)) for other in rows): continue
        side = 1 if ord(unit['id'][-1]) % 2 == 0 else -1
        placed = False
        for radius in (GAP, GAP*2):
            direction = unit['attributes']['direction']
            for dx, dy in ((0, side), (0, -side), (-direction, 0), (direction, 0), (-direction, side), (-direction, -side)):
                point = copy_data(unit['attributes'])
                point['x_fp'] += dx*radius; point['y_fp'] += dy*radius
                if not clear(unit, point, rows, structures, False): continue
                unit['attributes'] = point
                i = s.index[unit['id']]
                s.x_fp[i], s.y_fp[i] = point['x_fp'], point['y_fp']
                placed = True
                break
            if placed: break
