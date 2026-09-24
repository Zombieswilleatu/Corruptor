"""Wright construction and persistent, destructible lane objects."""
from .copying import copy_data
from . import embolden
from .primitives import instance_id
from .marching_spatial import half_away

CONTACT, LATERAL_CONTACT, BUILD_TICKS, GUARD_TICKS, TOWER_RANGE = 90, 42, 32, 200, 600
REPAIR_RANGE, REPAIR_TICKS = CONTACT, 27
WALL_HP, WALL_ARMOR, TOWER_HP, TOWER_ARMOR = 16, 4, 12, 6
GUARD_RANGE, GUARD_ALERT_RANGE = 400, 600


def rows(world):
    return world['data'].get('field_structures', [])


def event(kind, details):
    fact = dict(type=kind, text='', data=copy_data(details))
    return dict(event=fact, views=[copy_data(fact), copy_data(fact)])


def site_point(owner, site):
    return dict(x_fp=((640 if owner == 0 else 1760) if site < 2 else (480 if owner == 0 else 1920)),
                y_fp=(150, 450, 300)[site])


def anchor(owner, site):
    p = site_point(owner, site)
    p['x_fp'] -= 80 if owner == 0 else -80
    return p


def find(structures, owner, lane, site):
    return next((r for r in structures if r['owner'] == owner and r['attributes']['lane'] == lane
                 and r['attributes']['site'] == site), {})


def point(a, target):
    b = target['attributes']
    if target.get('kind', 'marcher') != 'fortification' or b['structure'] != 'Wall':
        return dict(x_fp=b['x_fp'], y_fp=b['y_fp'])
    return dict(x_fp=max(b['x_fp']-24, min(b['x_fp']+24, a['x_fp'])),
                y_fp=max(b['y_fp']-150, min(b['y_fp']+150, a['y_fp'])))


def distance(a, b):
    return (a['x_fp']-b['x_fp'])**2 + (a['y_fp']-b['y_fp'])**2


def gap(unit, target):
    return distance(unit['attributes'], point(unit['attributes'], target))


def in_melee(unit, target):
    if not target: return False
    p = point(unit['attributes'], target)
    dx = unit['attributes']['x_fp']-p['x_fp']; dy = unit['attributes']['y_fp']-p['y_fp']
    return dx*dx*LATERAL_CONTACT**2 + dy*dy*CONTACT**2 <= CONTACT**2*LATERAL_CONTACT**2


def blocker(unit, destination, structures):
    a = unit['attributes']
    if a.get('flying', False) or not destination:
        return {}
    best, best_gap = {}, (1 << 63)-1
    for row in structures:
        b = row['attributes']
        if row['owner'] == unit['owner'] or b['lane'] != a['lane'] or b['structure'] != 'Wall':
            continue
        dx = destination['x_fp'] - a['x_fp']
        if not dx:
            continue
        along = (b['x_fp']-a['x_fp']) * (1 if dx > 0 else -1)
        if not 0 <= along <= abs(dx):
            continue
        cross_y = a['y_fp'] + half_away((destination['y_fp']-a['y_fp']) * along / abs(dx))
        if abs(cross_y-b['y_fp']) > 150:
            continue
        d = gap(unit, row)
        if d < best_gap:
            best, best_gap = row, d
    return best


def blocked_step(unit, proposed, structures):
    if unit['attributes'].get('flying', False):
        return False
    for row in structures:
        if row['owner'] == unit['owner'] or row['attributes']['lane'] != unit['attributes']['lane'] or row['attributes']['structure'] != 'Wall':
            continue
        after = distance(proposed, point(proposed, row))
        if after < 42**2 and after < gap(unit, row):
            return True
    return False


def assigned_structure(unit, structures):
    a = unit['attributes']
    if 'wright_site' not in a or a.get('wright_owner', -1) != unit['owner']: return {}
    structure = find(structures, unit['owner'], a['lane'], a['wright_site'])
    if 'wright_guard_target' in a:
        return structure if structure and structure['id'] == a['wright_guard_target'] else {}
    return structure if structure and structure['attributes']['builder_id'] == unit['id'] else {}


def guarding(a):
    return a.get('wright_built', False) or 'wright_guard_target' in a


def ranged_guard(unit, structures, number):
    if unit.get('kind') != 'marcher': return False
    a = unit['attributes']
    return (a.get('suit') == 'Wright' and 'monster_id' not in a and guarding(a) and not a.get('wright_released',False)
            and not a['waiting'] and a['movement_ready_round'] <= number and not a.get('hidden',False)
            and bool(assigned_structure(unit,structures)) and distance(a,anchor(unit['owner'],a['wright_site'])) <= 32**2)


def threatened_post(unit, units, structures):
    home = anchor(unit['owner'],unit['attributes']['wright_site'])
    for other in units:
        b = other['attributes']
        if other['owner'] == unit['owner'] or b['lane'] != unit['attributes']['lane'] or b.get('hidden',False) or b['waiting']: continue
        # Incoming troops still threaten the post while intercepted farther out.
        # Distant fort guards/turrets must not lock both armies at home forever.
        if distance(home,b) <= GUARD_ALERT_RANGE**2: return True
        if b.get('sprite_form') == 'turret': continue
        if (b.get('suit') == 'Wright' and 'monster_id' not in b and guarding(b)
                and not b.get('wright_released',False) and assigned_structure(other,structures)): continue
        return True
    return False


def repair_target(unit, structures, guarded):
    a = unit['attributes']
    repair, repair_distance = {}, (1 << 63)-1
    for structure in structures:
        b = structure['attributes']
        if structure['owner'] != unit['owner'] or b['lane'] != a['lane'] or b['hp'] >= b['max_hp'] or structure['id'] in guarded:
            continue
        d = distance(a, anchor(unit['owner'], b['site']))
        if d < repair_distance:
            repair, repair_distance = structure, d
    return repair


def repair_support_target(unit, structures):
    a = unit['attributes']
    if not guarding(a) or a.get('wright_released',False) or ('wright_guard_target' in a and not a.get('wright_arrived',False)): return {}
    held = assigned_structure(unit, structures)
    if not held or held['attributes']['hp'] < held['attributes']['max_hp']: return {}
    home = anchor(unit['owner'],a['wright_site'])
    choices = [r for r in structures if r['owner']==unit['owner'] and r['attributes']['lane']==a['lane']
               and r['attributes']['hp'] < r['attributes']['max_hp']
               and distance(home,anchor(unit['owner'],r['attributes']['site'])) <= GUARD_ALERT_RANGE**2]
    return min(choices,key=lambda r:(gap(unit,r),r['id'])) if choices else {}


def work_in_reach(unit, structures, destination):
    for structure in structures:
        a = structure['attributes']
        if (structure['owner']==unit['owner'] and a['lane']==unit['attributes']['lane']
                and anchor(unit['owner'],a['site'])==destination and a['hp']<a['max_hp']):
            return in_melee(unit,structure)
    return True


def goal(unit, structures, clock, enemy):
    a = unit['attributes']
    if 'wright_site' not in a:
        return {}
    home = anchor(unit['owner'], a['wright_site'])
    if not guarding(a):
        return home
    structure = assigned_structure(unit, structures)
    if a.get('wright_released', False) or not structure:
        return {}
    if 'wright_guard_target' in a and not a.get('wright_arrived', False):
        return home
    support = repair_support_target(unit,structures)
    if support: return anchor(unit['owner'],support['attributes']['site'])
    # Only step() releases guard duty; movement honors that decision.
    return home


def step(world, entities, number, tick, fleeing=()):
    structures = world['data'].setdefault('field_structures', [])
    units, clock, events, reserved = entities.rows(), number*200+tick, [], {}
    guarded = {}
    for unit in units:
        a = unit['attributes']
        if a.get('suit') != 'Wright' or 'monster_id' in a:
            continue
        if guarding(a) and not a.get('wright_released', False):
            held = assigned_structure(unit, structures)
            if held: guarded[held['id']] = unit['id']
        if 'wright_site' in a and not guarding(a):
            site = a['wright_site']
            if (a.get('wright_owner', -1) != unit['owner'] or find(structures, unit['owner'], a['lane'], site)
                    or site == 2 and (not find(structures, unit['owner'], a['lane'], 0) or not find(structures, unit['owner'], a['lane'], 1))):
                for k in ('wright_site', 'wright_progress', 'wright_owner'):
                    a.pop(k, None)
                entities.update(unit['id'], unit['owner'], a)
            else:
                reserved[(unit['owner'], a['lane'], site)] = unit['id']
    for original in units:
        unit = entities.get(original['id']); a = unit['attributes']
        active = (not a['waiting'] and a['movement_ready_round'] <= number and a.get('rout_round', -1) != number
                  and not a.get('hidden', False) and unit['id'] not in fleeing)
        if a.get('suit') == 'Wright' and 'monster_id' not in a and 'wright_site' not in a and not guarding(a) and active:
            repair = repair_target(unit, structures, guarded)
            if repair:
                a.update(wright_site=repair['attributes']['site'], wright_owner=unit['owner'], wright_progress=0,
                         wright_guard_target=repair['id'], wright_arrived=False, wright_guard_until=0,
                         wright_repair_round=a.get("wright_repair_round",0), wright_released=False)
                guarded[repair['id']] = unit['id']
                events.append(event('WRIGHT_REPAIR_ASSIGNED', dict(unit_id=unit['id'], structure=repair,
                              owner=unit['owner'], lane=a['lane'], round=number, tick=tick)))
        if a.get('suit') == 'Wright' and 'monster_id' not in a and guarding(a):
            if a.get('wright_released', False): continue
            structure = assigned_structure(unit, structures)
            if not structure:
                a['wright_released'] = True
            elif active:
                arrived_now = ('wright_guard_target' in a and not a.get('wright_arrived', False)
                               and distance(a, anchor(unit['owner'], a['wright_site'])) <= 16**2)
                if arrived_now:
                    a.update(wright_arrived=True, wright_guard_until=clock+GUARD_TICKS)
                at_post = 'wright_guard_target' not in a or a.get('wright_arrived', False)
                if at_post and clock >= a['wright_guard_until'] and structure['attributes']['hp'] == structure['attributes']['max_hp'] and not threatened_post(unit, units, structures) and not repair_support_target(unit,structures):
                    a['wright_released'] = True
            entities.update(unit['id'], unit['owner'], a)
            continue
        if a['suit'] != 'Wright' or 'monster_id' in a or guarding(a) or not active:
            continue
        if 'wright_site' not in a:
            choices = [2] if find(structures, unit['owner'], a['lane'], 0) and find(structures, unit['owner'], a['lane'], 1) else [0, 1]
            selected, best = -1, (1 << 63)-1
            for site in choices:
                if find(structures, unit['owner'], a['lane'], site) or (unit['owner'], a['lane'], site) in reserved:
                    continue
                d = distance(a, anchor(unit['owner'], site))
                if d < best:
                    best, selected = d, site
            if selected < 0:
                continue
            a.update(wright_site=selected, wright_progress=0, wright_owner=unit['owner'])
            reserved[(unit['owner'], a['lane'], selected)] = unit['id']
            events.append(event('WRIGHT_BUILD_ASSIGNED', dict(unit_id=unit['id'], site=selected, owner=unit['owner'], lane=a['lane'], round=number, tick=tick)))
        threatened = any(r['owner'] != unit['owner'] and r['attributes']['lane'] == a['lane'] and not r['attributes'].get('hidden', False)
                         and in_melee(unit, r) for r in units)
        if distance(a, anchor(unit['owner'], a['wright_site'])) <= 16**2 and not threatened:
            a['wright_progress'] += 1
            if a['wright_progress'] >= BUILD_TICKS:
                p, tower = site_point(unit['owner'], a['wright_site']), a['wright_site'] == 2
                built = dict(id=instance_id('wright_structure', unit['id'], str(a['wright_site'])), kind='fortification', owner=unit['owner'],
                             attributes=dict(structure='Tower' if tower else 'Wall', site=a['wright_site'], lane=a['lane'], **p,
                                             hp=TOWER_HP if tower else WALL_HP, max_hp=TOWER_HP if tower else WALL_HP,
                                             armor=TOWER_ARMOR if tower else WALL_ARMOR, max_armor=TOWER_ARMOR if tower else WALL_ARMOR,
                                             attack=1 if tower else 0, ranged_next_tick=clock+1, builder_id=unit['id']))
                structures.append(built); structures.sort(key=lambda r: r['id'])
                guarded[built['id']] = unit['id']
                a.update(wright_built=True, wright_guard_until=clock+GUARD_TICKS, wright_repair_round=a.get("wright_repair_round",0), wright_released=False)
                events.append(event('WRIGHT_STRUCTURE_BUILT', dict(unit_id=unit['id'], structure=built, round=number, tick=tick)))
        entities.update(unit['id'], unit['owner'], a)
    events.extend(repair_nearby(world, entities, number, tick, fleeing))
    return events


def repair_nearby(world, entities, number, tick, fleeing=()):
    events = []
    for unit in entities.rows():
        a = unit['attributes']
        if (a.get('suit') != 'Wright' or 'monster_id' in a or a['waiting'] or a['movement_ready_round'] > number
                or a.get('rout_round',-1) == number or a.get('hidden',False) or unit['id'] in fleeing
                or a.get('wright_repair_next_tick',0) > number*200+tick):
            continue
        candidates = [r for r in rows(world) if r['owner'] == unit['owner'] and r['attributes']['lane'] == a['lane']
                      and r['attributes']['hp'] < r['attributes']['max_hp'] and in_melee(unit,r)]
        if not candidates: continue
        target = min(candidates,key=lambda r:(gap(unit,r),r['id']))
        before = target['attributes']['hp']; target['attributes']['hp'] = min(target['attributes']['max_hp'], before+1)
        a['wright_repair_next_tick'] = number*200+tick+REPAIR_TICKS
        entities.update(unit['id'],unit['owner'],a)
        events.append(event('WRIGHT_STRUCTURE_REPAIRED',dict(unit_id=unit['id'],structure=target,owner=unit['owner'],lane=a['lane'],hp_before=before,hp_after=target['attributes']['hp'],round=number,tick=tick)))
    return events


def damage(world, target_id, source, amount, bypass, number, tick):
    for row in rows(world):
        if row['id'] != target_id:
            continue
        a = row['attributes']; absorbed = 0 if bypass else min(a['armor'], amount)
        a['armor'] -= absorbed
        dealt = amount-absorbed; a['hp'] = max(0, round(a['hp']-dealt,8) if embolden.enabled(world) else a['hp']-dealt)
        events = []
        if a['hp'] == 0:
            events.append(event('WRIGHT_STRUCTURE_DESTROYED', dict(structure=row, attacker=source, round=number, tick=tick)))
            rows(world).remove(row)
        return dict(damage_dealt=dealt, hp_after=a['hp'], events=events)
    return dict(damage_dealt=0, hp_after=0, events=[])


def beam_hit(source, aim, row, radius, half_width):
    vx = aim['x_fp']-source['x_fp']; vy = aim['y_fp']-source['y_fp']
    p = dict(row['attributes'])
    if p['structure'] == 'Wall' and vx:
        ray_y = source['y_fp']+half_away((p['x_fp']-source['x_fp'])*vy/vx)
        p['y_fp'] = max(p['y_fp']-150, min(p['y_fp']+150, ray_y))
    dx = p['x_fp']-source['x_fp']; dy = p['y_fp']-source['y_fp']; cross = dx*vy-dy*vx
    return dx*vx+dy*vy >= 0 and dx*dx+dy*dy <= radius*radius and cross*cross <= half_width*half_width*max(1, vx*vx+vy*vy)


def valid_unit(a):
    for key in ('wright_site', 'wright_progress', 'wright_owner', 'wright_guard_until', 'wright_repair_round', 'wright_repair_next_tick'):
        if key in a and (a.get('suit') != 'Wright' or 'monster_id' in a or type(a[key]) is not int or a[key] < 0):
            return False
    for key in ('wright_built', 'wright_released', 'wright_arrived'):
        if key in a and (a.get('suit') != 'Wright' or 'monster_id' in a or type(a[key]) is not bool): return False
    if 'wright_guard_target' in a and (a.get('suit') != 'Wright' or 'monster_id' in a or type(a['wright_guard_target']) is not str or not a['wright_guard_target'] or 'wright_arrived' not in a):
        return False
    if 'wright_arrived' in a and 'wright_guard_target' not in a:
        return False
    if 'wright_released' in a and not guarding(a):
        return False
    if 'wright_site' in a and (a['wright_site'] > 2 or 'wright_progress' not in a or a['wright_progress'] > BUILD_TICKS or a.get('wright_owner', -1) not in (0, 1)):
        return False
    if guarding(a) and ('wright_site' not in a or 'wright_guard_until' not in a):
        return False
    return True


def valid(world):
    structures = rows(world)
    if type(structures) is not list or len(structures) > 12:
        return False
    sites, builders = set(), set()
    for row in structures:
        if type(row) is not dict or row.get('kind') != 'fortification' or row.get('owner') not in (0, 1) or type(row.get('attributes')) is not dict:
            return False
        a = row['attributes']
        if 'repair_round' in a and (type(a['repair_round']) is not int or a['repair_round'] < 0):
            return False
        if any(not (embolden.valid_stat(a.get(k)) if embolden.enabled(world) and k in ('hp','armor') else type(a.get(k)) is int) for k in ('site', 'x_fp', 'y_fp', 'hp', 'max_hp', 'armor', 'max_armor', 'attack', 'ranged_next_tick')):
            return False
        if a['site'] not in (0, 1, 2) or a.get('lane') not in ('Lord', 'Castle') or type(a.get('builder_id')) is not str:
            return False
        if row.get('id') != instance_id('wright_structure', a['builder_id'], str(a['site'])):
            return False
        if a['builder_id'] not in world['entities'].get('used_ids', []) or a['builder_id'] in builders:
            return False
        builders.add(a['builder_id'])
        p = site_point(row['owner'], a['site'])
        if a['x_fp'] != p['x_fp'] or a['y_fp'] != p['y_fp'] or not (0 < a['hp'] <= a['max_hp'] if embolden.enabled(world) else 1 <= a['hp'] <= a['max_hp']) or not 0 <= a['armor'] <= a['max_armor'] or a['ranged_next_tick'] < 0:
            return False
        tower = a['site'] == 2
        legacy = a['max_hp'] == 6 and a['max_armor'] == (4 if tower else 2)
        current = a['max_hp'] == (TOWER_HP if tower else WALL_HP) and a['max_armor'] == (TOWER_ARMOR if tower else WALL_ARMOR)
        if not (legacy or current) or a.get('structure') != ('Tower' if tower else 'Wall') or a['attack'] != (1 if tower else 0):
            return False
        key = row['owner'], a['lane'], a['site']
        if key in sites:
            return False
        sites.add(key)
    claims = set()
    guard_claims = set()
    for row in world['entities']['entities']:
        a = row['attributes']
        if row['kind'] == 'marcher' and guarding(a) and not a.get('wright_released', False):
            held = assigned_structure(row, structures)
            if held:
                if held['id'] in guard_claims: return False
                guard_claims.add(held['id'])
        if row['kind'] != 'marcher' or 'wright_site' not in a or guarding(a): continue
        # Charm releases the old claim before step() assigns another site.
        if a.get('wright_owner', -1) != row['owner']: continue
        key = str(row['owner']), str(a.get('lane', '')), str(a['wright_site'])
        if key in claims: return False
        claims.add(key)
    return True
