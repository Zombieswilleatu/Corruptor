"""Bounded split-hand alternatives, scored before ordinary legal selection."""
from copy import copy

from u13_pysim.copying import copy_data
from .facts import Proposal, LANES
from .recipes import Recipes
from .diagnostics import fingerprint


def proposals(f, weights, retained, budget):
    # Attack-first preserves two economical existing attack/recipe candidates.
    attacks = sorted((p for p in retained['combat']+retained['monsters']
                      if p.term in ('Hunt', 'Siege')),
                     key=lambda p: (-p.value, fingerprint(p.payload)))[:2]
    # Ward-first tests a real opportunity cost: remove one/two high-value cards
    # before making an ordinary attack. Recipe attachment sees only that attack.
    hand = sorted(f.hand, key=lambda r: (-f.strength([r['id']], 'Ward'), r['id']))
    for count in (1, 2):
        rest = hand[count:]
        if not rest: continue
        reduced = copy(f); reduced.hand = rest
        book = Recipes(reduced, weights)
        choices = []
        for action, lane, target in reduced.attack_targets():
            ids = [r['id'] for r in rest]
            p = Proposal('combat', action, dict(action=action, lane=lane,
                target_id=target, card_ids=ids), reduced.attack_value(action, target, ids, weights),
                'ward_first_attack', tuple(ids))
            book.attach(p)
            p.value -= weights.card_cost*sum(f.by_id[k]['attributes']['value'] for k in ids)
            choices.append(p)
        attacks.append(min(choices, key=lambda p: (-p.value, fingerprint(p.payload))))
    found = {}
    for attack in attacks:
        rest = [r['id'] for r in hand if r['id'] not in attack.cards]
        small, value = [], 0
        for identity in rest:
            if value >= 6: break
            small.append(identity); value += f.by_id[identity]['attributes']['value']
        for ids in (small, rest):
            for lane in LANES:
                if not budget.take('generated', 'split_ward'): return list(found.values())
                if not ids: continue
                payload = copy_data(attack.payload)
                payload['ward'] = dict(action='Ward', lane=lane, card_ids=ids[:])
                net = (weights.recruit*f.recruits(ids, 'Ward')
                       +2*min(f.strength(ids, 'Ward'), 5+5*f.lane_need(lane))
                       -weights.card_cost*sum(f.by_id[k]['attributes']['value'] for k in ids))
                p = Proposal('combat', attack.term, payload, attack.value+net,
                    'separate_paid_ward_and_attack', attack.cards+tuple(ids))
                found[fingerprint(payload)] = p
    return list(found.values())


def retain(proposals, budget):
    ranked = sorted(proposals, key=lambda p: (-p.value, fingerprint(p.payload)))
    chosen = []
    for lane in LANES:
        p = next((p for p in ranked if p.payload['ward']['lane'] == lane), None)
        if p is not None and budget.take('retained', 'split_ward'): chosen.append(p)
    for p in ranked:
        if p not in chosen:
            if not budget.take('retained', 'split_ward'): break
            chosen.append(p)
    return chosen
