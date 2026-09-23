"""Shared split-Ward and tempo rules; explicit flags preserve legacy replay behavior.

The primary order stays compatible with attack consumers. Optional `ward` is a
second, separately paid commitment. Empty Sigil schema fields remain solely for
old serializers; they have no effect in this ruleset.
"""
from copy import copy

from . import economy as e
from .copying import copy_data

VERSION = 'U13_SPLIT_WARD_V1'
TEMPO = 'U13_VEIL_ATTACK_ROUND25_V1'
TEMPO_SOUL_START_ROUND = 20


def tempo_enabled(world):
    return world['data'].get('tempo_experiment') == TEMPO


def attack_bonus(world):
    if not tempo_enabled(world): return 0
    total = world['data']['neutral_tears'] + sum(p['resources']['personal_tears'] for p in world['players'])
    return sum(total >= threshold for threshold in (15, 19, 23))



def enabled(world):
    return world['data'].get('ward_experiment') == VERSION


def configure(world):
    world['data']['ward_experiment'] = VERSION
    world['data']['sigils'] = [dict(Lord='', Castle='') for _ in range(2)]


def ward(order):
    return order if order.get('action') == 'Ward' else order.get('ward', {})


def accept(match, world, pid, order, reserve, ordinary_accept):
    """Reserve the separate Ward first so every other payment sees fewer cards."""
    part = order['ward']
    e.require(order.get('action') in ('Hunt', 'Siege'), 'ward_requires_attack')
    e.require(type(part) is dict and part.get('action') == 'Ward'
              and match._combat_shape(part) and bool(part['card_ids']), 'ward_shape_invalid')
    staged = world if reserve else copy_data(world)
    zones = e.zones(staged)
    e.require(e.selection(zones['hands'][pid], part['card_ids']), 'ward_cards_unavailable')
    for identity in part['card_ids']:
        zones['hands'][pid].remove(identity)
    attack = {k: v for k, v in order.items() if k != 'ward'}
    events = ordinary_accept(staged, pid, attack, reserve)
    if reserve:
        zones['committed'][pid].extend(part['card_ids'])
        events.append(e.sealed_event('WARD_ORDER_SEALED', dict(player_id=pid,
            round=match.clock.round, order=part), pid))
    return events


def succeeded(events):
    for row in reversed(events):
        event = row['event']
        if event['type'] == 'HUNT_RESOLVED':
            return event['data']['banished']
        if event['type'] == 'SIEGE_RESOLVED':
            d = event['data']
            return d.get('pillage_success', False) if d.get('pillage') else d['destroyed']
    return False


def reward_breakthrough(rules, pid, events):
    """One extra soul for an actual Hunt banishment or Siege target destruction.

    Not a pillage, screening structure, artillery shot, or counterfactual reward.
    Apply only to the real attack after its normal rewards/reactions resolve.
    """
    if tempo_enabled(rules.w):
        if rules.number < TEMPO_SOUL_START_ROUND: return
    elif not rules.w['data'].get('decisive_soul_bonus', False): return
    resolved = next((r['event'] for r in reversed(events)
                     if r['event']['type'] in ('HUNT_RESOLVED', 'SIEGE_RESOLVED')), None)
    if not resolved: return
    d = resolved['data']
    success = d.get('banished', False) if resolved['type'] == 'HUNT_RESOLVED' else (
        not d.get('pillage', False) and d.get('destroyed', False))
    if not success: return
    paid = rules.w['data'].setdefault('decisive_soul_rounds', [0, 0])
    if paid[pid] >= rules.number: return
    paid[pid] = rules.number
    rules.w['players'][pid]['resources']['souls'] += 1
    events.append(e.event('DECISIVE_SOUL_GAINED', dict(player_id=pid,
        round=rules.number, amount=1, target_id=d['target_id'],
        attack='Hunt' if resolved['type'] == 'HUNT_RESOLVED' else 'Siege')))


def resolve_attack(rules, pid, order):
    """Compare from the actual pre-attack state, with only Ward screen removed.

This is authority, never a bot forecast. Reactions, guards, waiters and target
retargeting run on a detached world with the same keyed RNG. Counterfactual
events/resources are discarded. A successful Siege means its target destroyed
(or pillage succeeded), not merely any damage or a screening Bastion lost.
"""
    method = order['action'].lower()
    defending = ward(rules.orders[1-pid])
    eligible = defending and defending['lane'] == order['lane']
    would_succeed = False
    if eligible:
        probe = copy(rules)
        # Detach all mutable attributes, including persistent effects.
        probe.__dict__ = copy_data(rules.__dict__)
        probe.orders[1-pid] = ({k: v for k, v in probe.orders[1-pid].items() if k != 'ward'}
                              if 'ward' in probe.orders[1-pid] else {})
        would_succeed = succeeded(getattr(probe, method)(pid, copy_data(order)))
    events = getattr(rules, method)(pid, order)
    saved = bool(eligible and would_succeed and not succeeded(events))
    if eligible:
        events.append(e.event('WARD_CONTESTED', dict(player_id=1-pid, attacker_id=pid,
            round=rules.number, lane=order['lane'], target_id=order['target_id'],
            would_succeed_without_ward=would_succeed, saved=saved)))
    paid = rules.w['data'].setdefault('ward_reward_rounds', [0, 0])
    if saved and paid[1-pid] < rules.number:
        paid[1-pid] = rules.number
        rules.w['players'][1-pid]['resources']['souls'] += 1
        events.append(e.event('WARD_SOUL_GAINED', dict(player_id=1-pid,
            round=rules.number, lane=order['lane'], amount=1)))
    reward_breakthrough(rules, pid, events)
    return events
