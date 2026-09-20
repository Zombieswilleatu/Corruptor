"""Gremory: reinforce pressure; pay two cards to reduce healthy Castle Integrity.

Passives: Guard defense supports Gem Dagger; no assumed future draw is scored.
Timing: Inevitable Ruin fires next round; reaching the current cap makes it fizzle.
Resources: its two discard cards compete with this round's entire plan.
"""
from u13_pysim.battle import targetable
from u13_pysim.power_rules import RUIN_INTEGRITY
from u13_pysim.copying import copy_data
from ..diagnostics import fingerprint
from ..facts import LANES, power
from ..recipes import Recipes
from ..veil_judgment import settlement_projection

LORD = 'Gremory'


def discard_pair(f, cards, weights, reserved_monster=''):
    """Two linear payment patterns: cheapest, or preserve the best recipe.

    Already committed combat/Guard/Work cards are excluded by the caller.
    Recipe opportunity cost ranks payments; shared assembly scores it once.
    """
    cards = sorted(cards, key=lambda r: (r['attributes']['value'], r['id']))
    if len(cards) < 2: return ()
    recipes = Recipes(f, weights); goal = recipes.goal(cards, reserved_monster)
    spare = [r for r in cards if r['id'] not in goal['card_ids']]
    options = [tuple(r['id'] for r in cards[:2])]
    if len(spare) >= 2: options.append(tuple(r['id'] for r in spare[:2]))
    def cost(ids):
        remaining = [r for r in cards if r['id'] not in ids]
        return (weights.card_cost*sum(f.by_id[k]['attributes']['value'] for k in ids)
                +goal['score']-recipes.goal(remaining, reserved_monster)['score'])
    return min(options, key=lambda ids: (cost(ids), ids))


def forecast(f, plan):
    """Own Development, known artillery, then attack, before next-round Ruin."""
    key = fingerprint(plan)
    if not hasattr(f, '_ruin_forecasts'): f._ruin_forecasts = {}
    if key in f._ruin_forecasts: return f._ruin_forecasts[key]
    from .deimos import ArtilleryPlans, attack_after
    from ..common import Weights
    # This shared projection follows locked/singleton acquisitions only. It
    # does not require Deimos and does not select a random target for Gremory.
    if 'summon' in plan['order']:
        after, hits, unknown = f, [], 0
    else:
        after, hits, unknown = ArtilleryPlans(f, Weights()).project(plan, extra=False)
    order = plan['order']; attack = {}
    if order.get('action') in ('Hunt', 'Siege'):
        excluded = [k for spend in order.get('rites', {}).get('waiter_spends', []) for k in spend['marcher_ids']]
        attack = attack_after(after, order, excluded)['castle_hits']
    integrity = {c['id']: max(0, c['attributes']['integrity']-attack.get(c['id'], 0))
                 for c in after.castles(f.enemy) if targetable(c)}
    result = dict(integrity=integrity, artillery_hits=hits, attack_hits=attack,
                  unknown_artillery=unknown, resummon_unprojected='summon' in order,
                  settlement=settlement_projection(f, plan)['winner'])
    f._ruin_forecasts[key] = result
    return result


def ruin_value(f, target, plan):
    projected = forecast(f, plan)
    before = f.by_id[target]['attributes']['integrity']
    remaining = projected['integrity'].get(target, 0)
    damage = max(0, remaining-RUIN_INTEGRITY)
    reason = 'damage_remaining_at_next_round_ruin'
    if projected['settlement'] != -1:
        damage = 0; reason = 'settlement_precedes_ruin'
    elif any(r['declaration']['power_id'] == 'InevitableRuin'
             and r['declaration']['target'].get('entity_id') == target
             and r['fire_round'] <= f.v['round']+1 for r in f.v['pending']):
        damage = 0; reason = 'target_already_pending_ruin'
    elif not damage: reason = 'own_damage_exhausts_ruin_target'
    return dict(score=5*damage, damage=damage, integrity_before=before,
                integrity_before_ruin=remaining, effective_round=f.v['round']+1,
                target_id=target, reason=reason, projection=copy_data(projected))


def proposals(f):
    for lane in LANES:
        yield power('PredatorOfRuin', dict(lane=lane), 27+6*f.lane_need(lane), 'two_vultures_lane_pressure')
    if len(f.hand) >= 2:
        from ..common import Weights
        cards = discard_pair(f, f.hand, Weights())
        targets = sorted((r for r in f.castles(f.enemy) if targetable(r) and r['attributes']['integrity'] > RUIN_INTEGRITY),
                         key=lambda r: (-r['attributes']['integrity'], r['id']))[:2]
        for row in targets:
            value = ruin_value(f, row['id'], dict(powers=[], order={}))
            yield power('InevitableRuin', dict(entity_id=row['id']), value['score'], value['reason'], cards)


def coordinate(f, plan, ctx):
    for source in plan['powers']:
        if source['power_id'] != 'InevitableRuin': continue
        target = source['target']['entity_id']
        baseline = ruin_value(f, target, dict(powers=[], order={}))
        adjusted = ruin_value(f, target, plan)
        yield dict(power='InevitableRuin', score_delta=adjusted['score']-baseline['score'], **adjusted)


class RuinPlans:
    """Add or retarget Ruin without taking cards from an existing complete plan."""
    def __init__(self, f, weights, enabled=True):
        self.f, self.weights = f, weights
        self.enabled = (enabled and f.kind == LORD and f.available('InevitableRuin')[0] and len(f.hand) >= 2
                        and any(targetable(c) and c['attributes']['integrity'] > RUIN_INTEGRITY for c in f.castles(f.enemy)))

    def alternatives(self, candidates, budget):
        if not self.enabled: return
        f = self.f; seen = set(); choices = []
        def bundle_key(selected):
            return tuple(sorted(fingerprint([p.category, p.term, p.payload, p.cards]) for p in selected))
        existing = {bundle_key(c['selected']) for c in candidates}
        targets = [c for c in f.castles(f.enemy) if targetable(c) and c['attributes']['integrity'] > RUIN_INTEGRITY]
        for candidate in sorted(candidates, key=lambda c: (-c['score'], fingerprint(c['plan']))):
            anchors = [p for p in candidate['selected'] if not (p.category == 'powers' and p.term == 'InevitableRuin')]
            identity = fingerprint([(p.category, p.payload, p.cards) for p in anchors])
            if identity in seen: continue
            seen.add(identity)
            spent = {k for p in anchors for k in p.cards}
            cards = discard_pair(f, [r for r in f.hand if r['id'] not in spent], self.weights,
                                 candidate['plan']['order'].get('monster_choice', ''))
            if len(cards) < 2: continue
            best = None
            for target in targets:
                if not budget.take('generated', 'gremory'): break
                value = ruin_value(f, target['id'], candidate['plan'])
                net = value['score']-self.weights.card_cost*sum(f.by_id[k]['attributes']['value'] for k in cards)
                if net > 0 and (best is None or net > best[0]): best = net, target['id']
            if best:
                net, target = best
                baseline = ruin_value(f, target, dict(powers=[], order={}))['score']
                p = power('InevitableRuin', dict(entity_id=target),
                    baseline-self.weights.card_cost*sum(f.by_id[k]['attributes']['value'] for k in cards),
                    'ruin_with_uncommitted_cards_after_own_damage', cards)
                combined = anchors+[p]; identity = bundle_key(combined)
                if identity not in existing:
                    existing.add(identity); choices.append(combined)
            if budget.report()['used'].get('generated:gremory', 0) >= budget.limits.generated_per_category: break
        for anchors in choices:
            if not budget.take('retained', 'gremory'): break
            yield anchors

    def report(self, chosen, alternatives):
        return dict(enabled=self.enabled, alternatives=alternatives,
            selected=[copy_data(r) for r in chosen['coordination']['powers'] if r['power'] == 'InevitableRuin'],
            scope='conditional own Development, known artillery and attack before next-round Ruin; enemy orders, repairs and random acquisitions unknown')
