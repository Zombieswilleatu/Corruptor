"""Bounded next-round alternatives, using the ordinary recruitment/recipe scores.

Compare a supported full-hand attack with Ward, saving, and two Guard-first
bundles (best deployment in each lane). No draws, enemy hand, or full planner
recursion. These are opportunity-cost estimates, not promised next orders.
"""
from .facts import Facts, LANES, Proposal
from .recipes import Recipes


def _net(f, proposal, weights):
    return proposal.value-weights.card_cost*sum(f.by_id[k]['attributes']['value'] for k in proposal.cards)


def alternatives(f):
    # Delayed import avoids the lord-module/common import cycle. Use the same
    # default scoring vocabulary as this doctrine's existing Snare estimates.
    from .common import ordinary, Weights
    weights = Weights()
    guards = list(ordinary(f, 'guards', weights))
    anchors = [None]
    for lane in LANES:
        options = [p for p in guards if p.payload['guard_moves'][0]['lane'] == lane]
        if options:
            anchors.append(min(options, key=lambda p: (-_net(f, p, weights), p.cards)))
    best = dict(score=0, action='Pass', lane='', card_ids=[], guard_card_ids=[], monster='')
    for guard in anchors:
        spent = set(guard.cards) if guard else set()
        state = Facts(dict(f.v, hand=[r for r in f.hand if r['id'] not in spent]))
        recipes = Recipes(state, weights)
        choices = [p for p in ordinary(state, 'combat', weights) if p.term in ('Pass', 'Ward')]
        for p in choices: recipes.attach(p)
        choices.extend(recipes.proposals())
        for p in choices:
            saved = [r for r in state.hand if r['id'] not in p.cards]
            score = (_net(state, p, weights)+(_net(f, guard, weights) if guard else 0)
                     +recipes.goal(saved, p.payload.get('monster_choice', ''))['score'])
            if score > best['score']:
                best = dict(score=score, action=p.term, lane=p.payload.get('lane', ''),
                    card_ids=list(p.cards), guard_card_ids=list(guard.cards) if guard else [],
                    monster=p.payload.get('monster_choice', ''))
    return best


def attack_score(f, action, lane, target, cards, result):
    from .common import Weights
    w = Weights()
    value = (w.recruit*f.recruits(cards, action)+12*result['guards']+w.damage*result['damage']
             +w.banishment*result['banished']+w.destruction*result['destroyed']+12*result['pillage'])
    p = Proposal('combat', action, dict(action=action, lane=lane, target_id=target, card_ids=cards),
                 value, 'supported_snare_attack', tuple(cards))
    Recipes(f, w).attach(p)
    return _net(f, p, w)
