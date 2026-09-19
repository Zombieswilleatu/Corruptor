"""Deimos's public, conditional estimate of an answer already in his plan.

This is a material/ordinary-attack heuristic, not a combat rollout or a claim
that the hand has no other answer. Geometry is nominal and new bodies use the
spawn edge, not a keyed placement. No enemy orders or random outcomes enter it.
"""
from u13_pysim import field_combat, monsters, recruitment
from .lane_support import travel


def reachable(ally, enemy, number, later=False):
    a, b = ally['attributes'], enemy['attributes']
    reach = 400 if a['suit'] == 'Vulture' or b['suit'] == 'Vulture' else 90
    # Units which have already passed this wave are not a defensive reserve.
    direction = 1 if ally['owner'] == 0 else -1
    if direction*(b['x_fp']-a['x_fp']) < -reach:
        return False
    rounds = (number, number+1) if later else (number,)
    distance = reach+sum(travel(a, n)+travel(b, n) for n in rounds)
    return (a['x_fp']-b['x_fp'])**2+(a['y_fp']-b['y_fp'])**2 <= distance**2


def force(rows, targets):
    """Durability times aggregate ordinary damage rate, in integer units.

    Matchups include the Vulture/Butcher bonus and Penitent ranged block's
    expected rate. This never rolls a block, deflection, evasion or special.
    Armor is a consumable pool, not flat reduction on every hit. Monster
    specials and fortification fire receive no speculative answer credit.
    """
    if not rows or not targets:
        return 0
    durability = sum(r['attributes']['hp']+r['attributes']['armor'] for r in rows)
    rate = 0
    for row in rows:
        a = row['attributes']
        interval = field_combat.RANGED_INTERVAL if a['suit'] == 'Vulture' else field_combat.MELEE_INTERVAL
        damage = 0
        for target in targets:
            b = target['attributes']
            amount = 100*(a['attack']+field_combat.matchup_bonus(row, target))
            if a['suit'] == 'Vulture' and b['suit'] == 'Penitent':
                amount //= 2
            if b.get('monster_id') == 'Tumler':
                amount //= 2
            elif b.get('monster_id') == 'Kurchin' and b['armor'] > 0:
                amount //= 4
            damage += amount
        rate += 100*damage//(interval*len(targets))
    return durability*rate


def defenders(f, lane, ctx):
    excluded = set(ctx['consumed_supplicants'])
    rows = [r for r in f.units(f.pid, lane) if r['id'] not in excluded
            and not r['attributes'].get('hidden') and not r['attributes'].get('waiting')
            and r['attributes'].get('sprite_form') != 'turret']
    number = f.v['round']
    planned = []
    if ctx['recruit_lane'] == lane:
        for suit, count in sorted(ctx['recruit_suits'].items()):
            for i in range(count):
                planned.append(dict(id=f'answer_recruit:{suit}:{i}', kind='marcher', owner=f.pid,
                    attributes=recruitment.profile(suit, lane, f.pid, number, number+1)))
        if ctx['monster']:
            for i in range(ctx['monster_bodies_minimum']):
                planned.append(dict(id=f'answer_monster:{i}', kind='marcher', owner=f.pid,
                    attributes=monsters.profile(ctx['monster'], lane, f.pid, number, number+1)))
    # Deimos's War Machine hits castles, not marching bodies. Breach wishes can
    # have unknown spawn suits or victims: none is invented as a certain answer.
    return rows, planned


def evaluate(f, lane, ctx, baseline):
    threats = [f.by_id[k] for k in baseline['threats']]
    existing, planned = defenders(f, lane, ctx)
    all_defenders = existing+planned
    number = f.v['round']
    now = [r for r in all_defenders if any(reachable(r, e, number) for e in threats)]
    later = [r for r in all_defenders if r not in now
             and any(reachable(r, e, number, later=True) for e in threats)]
    own, enemy = force(now, threats), force(threats, now or all_defenders)
    # With no reachable defender the unanswered threat retains its old value.
    # At parity keep the full delay preference; discount only a material edge,
    # reaching zero at twice the opposing force estimate. This is a score,
    # never a ban on Rout. A one-round reserve cannot erase present pressure.
    numerator = min(enemy, max(0, 2*enemy-own)) if own and enemy else enemy
    value = baseline['score']*numerator//enemy if enemy else baseline['score']
    uncertain = sorted({r['attributes']['monster_id'] for r in threats+now
                        if r['attributes'].get('monster_id')})
    return dict(score=value, baseline_score=baseline['score'], own_force=own, enemy_force=enemy,
        answer='material_edge' if value == 0 and baseline['score'] else 'partial_edge' if value < baseline['score'] else 'unanswered_or_uncertain',
        threat_bodies=len(threats), defenders_now=len(now), reserves_next_round=len(later),
        planned_bodies=len(planned), planned_in_reach=sum(r in planned for r in now),
        consumed_excluded=len(set(ctx['consumed_supplicants']).intersection(r['id'] for r in f.units(f.pid, lane))),
        unmodeled_monster_specials=uncertain,
        scope='nominal contact and ordinary material; no random placement, future draw, enemy recruits, specials or terrain prediction')
