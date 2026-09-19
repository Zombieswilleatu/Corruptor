"""Independent simultaneous melee and fortification-aware ranged attacks."""
from . import field_fortifications as fort, monster_effects, penitent_defense
from .copying import copy_data
from .marching_buffer import Buffer
from .primitives import instance_id

MELEE_INTERVAL = 34
RANGED_INTERVAL = 50


def ignored(a, b):
    aa, bb = a['attributes'], b['attributes']
    return aa.get('hidden', False) or bb.get('hidden', False) or b['id'] in aa.get('ghost_bypassed', []) or a['id'] in bb.get('ghost_bypassed', [])


def nearest(unit, targets, radius=4000, melee=False):
    best, gap = {}, radius**2+1
    for row in targets:
        if row['owner'] == unit['owner'] or row['attributes']['lane'] != unit['attributes']['lane'] or row['kind'] == 'marcher' and ignored(unit, row):
            continue
        if unit['attributes'].get('flying', False) and row['kind']=='fortification' and row['attributes']['structure']=='Wall': continue
        if melee and not fort.in_melee(unit, row): continue
        d = fort.gap(unit, row)
        if d <= radius**2 and (d < gap or d == gap and (not best or row['id'] < best['id'])):
            best, gap = row, d
    return best


def touching(rows, structures):
    targets = rows+structures
    return [r['id'] for r in rows if nearest(r, targets, fort.CONTACT, True)]


def melee(phase, tick, fleeing):
    clock, ctx, number = phase.number*200+tick, phase.context, phase.number
    buffer = Buffer(phase)
    units = buffer.rows(); targets = units + copy_data(fort.rows(phase.w))
    has_taunt = any(r['attributes'].get('monster_id') == 'Kurchin' for r in units)
    shots, deaths = [], []
    for unit in units:
        a = unit['attributes']
        if (a.get('melee_next_tick', 0) > clock or unit['id'] in fleeing or a.get('rout_round') == number
                or a.get('hidden', False) or a.get('sprite_form') == 'turret'):
            continue
        target = nearest(unit, targets, fort.CONTACT, True)
        if has_taunt or a.get('monster_id') == 'Tumler':
            target = monster_effects.preferred(unit, units) or target
        if not target:
            continue
        obstruction = fort.blocker(unit, fort.point(a, target), fort.rows(phase.w))
        if obstruction:
            target = obstruction
        if not fort.in_melee(unit, target):
            continue
        source = buffer.get(unit['id']); sa = source['attributes']
        amount = sa['attack'] * (2 if sa.pop('blood_wish', False) else 1)
        sa['melee_next_tick'] = clock+MELEE_INTERVAL
        if a['suit'] == 'Vulture':
            sa['ranged_next_tick'] = max(a.get('ranged_next_tick', 0), clock+MELEE_INTERVAL)
        buffer.update(source['id'], source['owner'], sa)
        shots.append(dict(attacker=unit, target=target, amount=amount))
    for shot in shots:
        dealt, hp_after, evaded = 0, 0, False
        if shot['target']['kind'] == 'fortification':
            hit = fort.damage(phase.w, shot['target']['id'], shot['attacker'], shot['amount'], shot['attacker']['attributes']['armor_bypass'], number, tick)
            dealt, hp_after = hit['damage_dealt'], hit['hp_after']
            phase.events.extend(hit['events'])
        else:
            target = buffer.get(shot['target']['id'])
            if target:
                a = target['attributes']
                live_rows = buffer.rows() if a.get('monster_id') == 'Tumler' else []
                evaded = monster_effects.evades(target, shot['attacker'], live_rows, ctx, tick, 'Melee', fort.rows(phase.w), fleeing)
                amount = 0 if evaded else shot['amount']
                if not evaded and target['id'] not in fleeing:
                    phase.events.extend(monster_effects.intercept(target, shot['attacker'], live_rows, ctx, tick, fort.rows(phase.w)))
                absorbed = 0 if shot['attacker']['attributes']['armor_bypass'] else min(a['armor'], amount)
                a['armor'] -= absorbed; dealt = amount-absorbed
                a['hp'] = max(0, a['hp']-dealt); hp_after = a['hp']
                a['movement_ready_round'] = min(a['movement_ready_round'], number)
                if not a['hp']:
                    buffer.retire_id(target['id'])
                    deaths.append(dict(victim=copy_data(target), attacker=shot['attacker'], damage_dealt=dealt, hp_after=0))
                else:
                    buffer.update(target['id'], target['owner'], a)
                if not evaded:
                    phase.events.extend(monster_effects.on_hit(buffer, shot['attacker'], target['id'], dealt, ctx, tick))
        phase.emit('MARCHER_MELEE_ATTACK', dict(attacker=shot['attacker'], target=shot['target'], damage_dealt=dealt, evaded=evaded, hp_after=hp_after, round=number, tick=tick, lane=shot['attacker']['attributes']['lane']))
    phase.w['entities'] = phase.s.snapshot()
    for death in deaths:
        death.update(event_id=instance_id('field_melee_kill', str(clock), death['victim']['id']), round=number, tick=tick, hook=ctx['hook'], cause='combat')
        phase.emit('MARCHER_DEFEATED', death)
        phase.react(phase.events[-1]['event'], 'field_melee_reaction_invalid')
    if deaths:
        phase.restore_reactions('field_melee_reaction_invalid')


def volley(phase, duels, tick, fleeing):
    buffer = Buffer(phase)
    rows = buffer.rows() + copy_data(fort.rows(phase.w))
    clock, number = phase.number*200+tick, phase.number
    busy = {r['id'] for duel in duels.values() for r in duel['units']}
    shots, deaths = [], []
    for unit in rows:
        a = unit['attributes']; tower = unit['kind'] == 'fortification' and a['structure'] == 'Tower'
        if tower:
            if a['ranged_next_tick'] > clock:
                continue
        elif (unit['kind'] != 'marcher' or a['suit'] != 'Vulture' or unit['id'] in busy or unit['id'] in fleeing
              or a.get('rout_round') == number or a.get('ranged_next_tick', 0) > clock):
            continue
        radius = fort.TOWER_RANGE if tower else 400
        best, target = radius**2+1, {}
        for other in rows:
            if other['owner'] == unit['owner'] or other['attributes']['lane'] != a['lane'] or ignored(unit, other):
                continue
            d = fort.gap(unit, other)
            if d < best or (d == best and (not target or other['id'] < target['id']) and not tower):
                target, best = other, d
            elif tower and d == best and target and other['id'] < target['id']:
                target = other
        if not tower:
            preferred = monster_effects.preferred(unit, rows)
            if preferred and fort.distance(a, preferred['attributes']) <= radius**2:
                target = preferred
        if not target or not tower and fort.in_melee(unit, target):
            continue
        amount = 1
        if tower:
            fort.find(fort.rows(phase.w), unit['owner'], a['lane'], 2)['attributes']['ranged_next_tick'] = clock+RANGED_INTERVAL
        else:
            attacker = buffer.get(unit['id']); aa = attacker['attributes']
            amount = aa['attack'] * (2 if aa.pop('blood_wish', False) else 1)
            aa.update(ranged_next_tick=clock+RANGED_INTERVAL, melee_next_tick=clock+MELEE_INTERVAL)
            buffer.update(attacker['id'], attacker['owner'], aa)
        shots.append(dict(attacker=unit, target=target, amount=amount))
    for shot in shots:
        dealt, hp_after, blocked, evaded = 0, 0, False, False
        if shot['target']['kind'] == 'fortification':
            hit = fort.damage(phase.w, shot['target']['id'], shot['attacker'], shot['amount'], False, number, tick)
            dealt, hp_after = hit['damage_dealt'], hit['hp_after']; phase.events.extend(hit['events'])
        else:
            target = buffer.get(shot['target']['id'])
            if target:
                blocked = penitent_defense.blocks(target, shot['attacker']['id'], phase.context['seed'], number, tick, 'Tower' if shot['attacker']['kind'] == 'fortification' else 'Vulture')
                evaded = monster_effects.evades(target, shot['attacker'], buffer.rows() if target['attributes'].get('monster_id') == 'Tumler' else [], phase.context, tick, 'Tower' if shot['attacker']['kind'] == 'fortification' else 'Vulture', fort.rows(phase.w), fleeing)
                a = target['attributes']; amount = 0 if blocked or evaded else shot['amount']; absorbed = min(a['armor'], amount)
                a['armor'] -= absorbed; dealt = amount-absorbed
                a['hp'] = max(0, a['hp']-dealt); hp_after = a['hp']
                if not a['hp']:
                    buffer.retire_id(target['id'])
                    deaths.append(dict(attacker=shot['attacker'], victim=copy_data(target), damage_dealt=dealt, hp_after=0))
                else:
                    a['movement_ready_round'] = min(a['movement_ready_round'], number)
                    buffer.update(target['id'], target['owner'], a)
        phase.emit('MARCHER_RANGED_ATTACK', dict(round=number, tick=tick, lane=shot['attacker']['attributes']['lane'], attacker=shot['attacker'], target=shot['target'], blocked=blocked, evaded=evaded, damage_dealt=dealt, hp_after=hp_after))
    if shots:
        phase.w['entities'] = phase.s.snapshot()
    for death in deaths:
        death.update(event_id=instance_id('ranged_kill', str(clock), death['victim']['id']), round=number, tick=tick, hook='marching', cause='combat')
        phase.emit('MARCHER_DEFEATED', death)
        phase.react(phase.events[-1]['event'], 'ranged_reaction_invalid')
    if deaths:
        phase.restore_reactions('ranged_reaction_invalid')
