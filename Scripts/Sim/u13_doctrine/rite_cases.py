"""Small, explicitly prepared policy contracts; never counted as full games."""
from u13_pysim import economy, full_match_inputs, power_components
from u13_pysim.power_match import PowerMatch


def prepared_case(name, values=(5, 3, 3)):
    setup = dict(seed='u13-rite-contract:'+name, lords=['Odradek', 'Gremory'],
        castles=[['Keep', 'Stockpile', 'SummoningCircle', 'SiegeEngine', 'Bastion']]*2)
    game = PowerMatch(setup)
    while game.clock.hook != 'submission_lock':
        result = game.apply(full_match_inputs.next_operation(game))
        if result['action'] == 'invalid': raise ValueError(result)
    world = game._state['world']
    for pid in (0, 1): economy.discard(world, pid, economy.zones(world)['hands'][pid][:])
    selected = [next(r['id'] for r in world['entities']['entities'] if r['kind'] == 'card'
                    and r['attributes']['suit'] == suit and r['attributes']['value'] == value)
                for suit, value in zip(('Butcher', 'Penitent', 'Wright'), values)]
    scenarios = dict(win=([4, 4], 3), hold=([0, 0], 7), enemy_win=([0, 5], 6),
                     already_winning=([4, 4], 3))
    tears, neutral = scenarios[name]
    changes = [dict(kind='fixture_give', player_id=0, card_id=key) for key in selected]
    changes += [dict(kind='fixture_data', data=dict(neutral_tears=neutral))]
    for pid in (0, 1):
        changes.append(dict(kind='fixture_resources', player_id=pid,
            resources=dict(personal_tears=tears[pid], souls=12 if name == 'already_winning' and pid == 0 else 0)))
    power_components.prepare(game, changes)
    return game
