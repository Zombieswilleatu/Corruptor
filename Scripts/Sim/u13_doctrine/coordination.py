"""Bounded public scenarios for conflicts within an assembled own plan.

Enemy orders, artillery, reactions and Marching are not simulated. A Guard
forecast is conditional; a new friendly body is exposure, not a promised death.
Lord-specific score adjustments live alongside each Lord's proposal rules.
"""
from collections import Counter

from u13_pysim.copying import copy_data
from . import lords

VERSION = 'U13_POWER_COORDINATION_V2'
TERMS = frozenset(('Projection', 'Consume', 'Ravenous', 'Redirect', 'FalseOrders', 'AllegianceShift', 'Inversion'))


def context(f, plan):
    order = plan['order']
    action, lane = order.get('action'), order.get('lane')
    lost, consumed = [], set()
    for spend in order.get('rites', {}).get('waiter_spends', []):
        consumed.update(spend['marcher_ids'])
    if action in ('Hunt', 'Siege'):
        result = f.attack(action, order['target_id'], order['card_ids'], consumed)
        guards = sorted(f.guards(f.enemy, lane),
                        key=lambda r: (-r['attributes']['value'], r['attributes']['slot'], r['id']))
        lost = [r['id'] for r in guards[:result['guards']]]
        consumed.update(r['id'] for r in f.units(f.pid, lane) if r['attributes']['waiting'])
    recruits = f.recruits(order.get('card_ids', []), action) if action in ('Hunt', 'Siege', 'Ward') else 0
    monster = order.get('monster_choice', '')
    # Varn's guaranteed minimum; do not consult its future swarm roll.
    monsters = (3 if monster == 'Varn' else 1) if monster else 0
    spawn_powers = Counter()
    for source in plan['powers']:
        name = source['power_id'].removeprefix('Breach')
        if name in ('WishPower', 'PredatorOfRuin', 'MusterTheFaithful'):
            spawn_powers[source['target']['lane']] += dict(WishPower=1, PredatorOfRuin=2, MusterTheFaithful=3)[name]
    return dict(attack_lane=lane if action in ('Hunt', 'Siege') else '',
                guard_losses=lost, consumed_supplicants=sorted(consumed),
                recruit_lane=lane, recruits=recruits, monster_bodies_minimum=monsters,
                monster=monster, unknown_extra_varn_bodies=monster == 'Varn',
                power_bodies_minimum=dict(sorted(spawn_powers.items())))


def evaluate(f, plan):
    if not any(s['power_id'] in TERMS for s in plan['powers']):
        return dict(score_delta=0, powers=[], context=None)
    ctx = context(f, plan)
    assess = getattr(lords.MODULES[f.kind], 'coordinate', None)
    rows = list(assess(f, plan, ctx)) if assess else []
    return dict(score_delta=sum(r['score_delta'] for r in rows), powers=rows, context=ctx)


def report(candidates, chosen, omission_count):
    measured, affected = Counter(), Counter()
    for candidate in candidates:
        for row in candidate['coordination']['powers']:
            measured[row['power']] += 1
            if row['score_delta'] < 0: affected[row['power']] += 1
    return dict(version=VERSION, assessed_plans=dict(sorted(measured.items())),
                adjusted_plans=dict(sorted(affected.items())), omission_plans=omission_count,
                selected=copy_data(chosen['coordination']),
                selected_omitted_powers=chosen.get('omitted_powers', []),
                scope='own attack, Guard deployments, recruitment, Supplicant spends and Redirect/Shift order; enemy orders, reactions and spatial outcomes uncertain',
                hard_veto=False)
