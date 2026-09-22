"""Known paid consequences and protection from revealed permanent intruders.

No future arrival identities, seed, speculative enemy orders or random Prices.
These are labeled scenarios and strategic preferences, never a hard loss proof.
"""
from u13_pysim import veil
from u13_pysim.battle import targetable
from u13_pysim.copying import copy_data
from u13_pysim.lifecycle import evaluate
from u13_pysim.power_rules import RULES


def paid_scenario(f, plan):
    players, actors = copy_data(f.v['players']), copy_data(f.lord)
    order = plan['order']; rites = order.get('rites', {})
    gain = len(rites.get('waiter_spends', []))+int('invocation' in rites)+int('profane_ruins' in rites)
    gain += int(order.get('action') == 'Profane')
    own = players[f.pid]['resources']
    own['personal_tears'] += gain
    own['souls'] -= 2*int('profane_ruins' in rites)
    for source in plan.get('powers', []):
        for resource, amount in RULES[source['power_id']]['cost'].items(): own[resource] -= amount
    neutral = f.v['data']['neutral_tears']+(2 if f.v['round'] > 20 else 1 if f.v['round'] > 12 else 0)
    if 'summon' in order:
        actors[f.pid]['attributes']['alive'] = True; neutral += 1
    data = dict(neutral_tears=neutral)
    if "tempo_experiment" in f.v["data"]: data["tempo_experiment"] = f.v["data"]["tempo_experiment"]
    return dict(players=players, data=data, entities=dict(entities=actors))


def settlement_projection(f, plan):
    return evaluate(paid_scenario(f, plan), f.v["round"])


def protection_projection(f, plan, weight):
    """Score newly reached protection, only for already revealed intruders.

    Benefit denial concerns the enemy; harmful intruders concern our side.
    Ordinary participating-Lord breaches and unprotectable cascade arrivals
    grant no protection value. Late protection does not refund earlier damage.
    """
    scenario = paid_scenario(f, plan)
    projected = dict(players=scenario['players'], entities=f.world['entities'], data=f.v['data'])
    changes, score = [], 0
    for row in f.v['data'].get('veil_breaches', {}).get('arrivals', []):
        name = row['lord_id']
        seat = f.enemy if name in veil.BENEFICIAL else f.pid
        if not veil.affects(f.world, name, seat) or veil.affects(projected, name, seat): continue
        units = [r for lane in ('Lord', 'Castle') for r in f.units(seat, lane)]
        castles = [c for c in f.castles(seat) if targetable(c)]
        guards = [r for lane in ('Lord', 'Castle') for r in f.guards(seat, lane)]
        exposure = dict(Gremory=int(any(f.guards(pid, lane) for pid in (0, 1) for lane in ('Lord', 'Castle'))), Deimos=min(3, len(castles)),
                        Humbaba=min(3, len(castles)), Kalligan=min(3, sum(c['attributes']['integrity'] < c['attributes']['max_integrity'] for c in castles)),
                        Orias=int(f.lord[seat]['attributes'].get('threat', 0) >= 2),
                        Odradek=min(3, len(guards)+len(units)), Kroni=min(3, len(units)),
                        Valak=min(3, sum(not r['attributes']['waiting'] for r in units)), Kanifous=1)[name]
        contribution = weight*exposure
        changes.append(dict(lord=name, affected_player=seat, protection=row['protection'],
                            direction='deny_enemy_benefit' if name in veil.BENEFICIAL else 'protect_own_side',
                            score=contribution))
        score += contribution
    before, after = f.veil, veil.total(scenario)
    count = len(f.v['data'].get('veil_breaches', {}).get('arrivals', []))
    thresholds = [t for t in veil.THRESHOLDS[count:] if after >= t]
    return dict(score=score, changes=changes, veil_before=before, paid_scenario_veil=after,
                pending_thresholds=thresholds, future_arrival_identity='unknown',
                cascade_due_if_game_continues=after >= 21 and f.v['round']+1 >= 21 and count < len(veil.LORDS)-len({p['lord_id'] for p in f.v['players']}),
                scope='revealed protection only; no retroactive healing or undo; future board and arrivals uncertain')
