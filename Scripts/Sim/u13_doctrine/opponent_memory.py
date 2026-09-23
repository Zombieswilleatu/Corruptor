"""Bounded, public-only opponent habits. No private hand or sealed order input."""
WINDOW = 6
VERSION = 'U13_OPPONENT_MEMORY_V1'


def project(rows, seat, number):
    """Rebuild from visible reveals, including after loading an existing save."""
    first = max(1, number-WINDOW)
    rounds = {}
    for envelope in reversed(rows):
        event = envelope['views'][seat]
        if not event or event['type'] != 'COMBAT_ORDER_REVEALED':
            continue
        d = event['data']; n = d['round']
        if n < first:
            break
        if n >= number or d['player_id'] == seat:
            continue
        r = rounds.setdefault(n, dict(round=n, action='Pass', lane='', cards=0,
                                       strength=0, ward_strength=0))
        order = d['order']
        strength = sum(c['attributes']['value'] for c in d['cards'])
        if order.get('action') in ('Hunt', 'Siege'):
            r.update(action=order['action'], lane=order['lane'],
                     cards=len(d['cards']), strength=strength)
        elif order.get('action') == 'Ward':
            r['ward_strength'] = strength
    if not rounds:
        return []
    return [rounds.get(n, dict(round=n, action='Pass', lane='', cards=0,
                              strength=0, ward_strength=0)) for n in range(first, number)]


def profile(view):
    number = view['round']
    # Older fixtures and observations remain valid; absent memory is neutral.
    rows = sorted((r for r in view.get('opponent_history', [])
                   if max(1, number-WINDOW) <= r['round'] < number), key=lambda r: r['round'])[-WINDOW:]
    lanes = dict(Lord=2, Castle=2)  # Never presume the opponent cannot switch.
    total = heavy = attacks = strength = attack_weight = 0
    for r in rows:
        weight = WINDOW-(number-1-r['round'])
        total += weight
        if r['action'] not in ('Hunt', 'Siege'):
            continue
        attacks += 1
        lanes[r['lane']] += weight
        strength += weight*r['strength']; attack_weight += weight
        if r['cards'] >= 4 and r['strength'] >= 12:
            heavy += weight
    big_count = sum(r['action'] in ('Hunt', 'Siege') and r['cards'] >= 4
                    and r['strength'] >= 12 for r in rows)
    aggression = min(100, 100*heavy//max(1, total)) if big_count >= 2 else 0
    # Moderate attacks do not activate the counter-all-in response.
    if aggression < 50:
        aggression = 0
    mean = max(9, min(30, (strength+attack_weight//2)//max(1, attack_weight))) if attacks else 15
    return dict(version=VERSION, rounds=len(rows), attacks=attacks,
                large_attacks=big_count, aggression=aggression,
                lane_weights=lanes, card_pressures=[max(1, mean-3), mean, mean+3],
                evidence=rows, source='completed-round public commitments only')


def risk(f, world, plan, weights):
    """Material at risk under learned stress cases; not a predicted enemy move."""
    from .defensive_plans import exposure
    p = f.opponent
    if not p['aggression']:
        return 0
    weighted = 0
    for lane, lane_weight in p['lane_weights'].items():
        for pressure in p['card_pressures']:
            result = exposure(f, world, plan, lane, pressure)
            # Losses include the attacker's two-Soul reward (24 utility),
            # or the same return-Lord value used by ordinary resummon planning.
            # These are bounded utility weights, not predicted win chances.
            cost = ((weights.destruction+24)*result['castles_lost']
                    +(weights.banishment+weights.return_lord)*int(result['banished'])
                    +6*result.get('guards_lost', 0)
                    +weights.damage*result.get('castle_damage', 0)
                    +12*int(result.get('pillage', False)))
            weighted += lane_weight*cost
    return weighted*p['aggression']//(100*3*sum(p['lane_weights'].values()))


def proposal_bonus(f, proposal, weights):
    """Keep useful defensive proposals alive until complete-plan scoring."""
    if not f.opponent['aggression'] or proposal.category not in ('combat', 'guards'):
        return 0
    if proposal.category == 'combat' and proposal.term != 'Ward':
        return 0
    from .defensive_plans import development
    empty = dict(order={}, powers=[])
    plan = dict(order=proposal.payload, powers=[])
    world, _ = development(f, plan)
    return risk(f, f.world, empty, weights)-risk(f, world, plan, weights)
