"""Fresh bounded U13 planning alpha. Integer weights are injected, never tuned here.

Generate a small set of category proposals, then assemble fixed priority bundles.
No Cartesian products, full-game candidate rollouts, or elapsed-time cutoffs.
"""
from collections import Counter
from dataclasses import asdict, dataclass

from u13_pysim.battle import operational, targetable
from u13_pysim.copying import copy_data
from u13_pysim.development import eligible, commission_eligible
from u13_pysim.opening import COSTS
from u13_pysim.power_rules import RULES, declaration
from u13_pysim.powers import WISHES
from u13_pysim.lifecycle import evaluate
from . import lords
from .budget import Budget, Limits
from .coverage import POWERS
from .diagnostics import fingerprint
from .facts import Facts, Proposal, LANES

VERSION = 'U13_COMMON_SMART_CORE_ALPHA_V2_BREACH_WISHES'
BREACH_WISHES = tuple(power for power in WISHES if RULES[power].get('breach_wish'))


@dataclass(frozen=True)
class Weights:
    card_cost: int = 2
    recruit: int = 6
    guard: int = 5
    damage: int = 3
    banishment: int = 32
    destruction: int = 30
    tear: int = 22
    return_lord: int = 75
    enemy_settlement_risk: int = 90

    def __post_init__(self):
        if any(type(v) is not int or v < 0 for v in asdict(self).values()):
            raise ValueError('weights must be nonnegative integers')


def key(p):
    return fingerprint([p.category, p.term, p.payload, p.cards])


def settlement_projection(f, plan):
    """Static end-of-round resource scenario, not proof of a future outcome.

    Use actual Ritual / Final Collapse / Dominion precedence, known pressure,
    and explicit paid choices. Spatial combat, reactions, random Prices and
    enemy orders remain unknown, so this function cannot justify a hard veto.
    Only two player records and two Lords are copied, not the simulation world.
    """
    players = copy_data(f.v['players']); actors = copy_data(f.lord)
    order = plan['order']; rites = order.get('rites', {})
    gain = len(rites.get('waiter_spends', []))+int('invocation' in rites)+int('profane_ruins' in rites)
    gain += int(order.get('action') == 'Profane')
    players[f.pid]['resources']['personal_tears'] += gain
    players[f.pid]['resources']['souls'] -= 2*int('profane_ruins' in rites)
    neutral = f.v['data']['neutral_tears']+(2 if f.v['round'] > 20 else 1 if f.v['round'] > 12 else 0)
    if 'summon' in order:
        actors[f.pid]['attributes']['alive'] = True; neutral += 1
    # Inversion's Tear is conditional on a successful transfer and so remains
    # outside this paid-choice scenario, as do uncertain combat gains.
    state = dict(players=players, data=dict(neutral_tears=neutral), entities=dict(entities=actors))
    return evaluate(state)


def ordinary(f, category, weights):
    pid, enemy = f.pid, f.enemy
    if category == 'work':
        for row in f.castles(pid):
            a = row['attributes']
            activate = commission_eligible(row, pid)
            if activate or eligible(f.world, pid, row):
                term = 'Activate' if activate else 'Work'
                value = 30 if activate else 9 if a['construction_state'] != 'active' else 3
                if a.get('repair_lock_until_round', 0) >= f.v['round'] and not activate:
                    value = 0
                yield Proposal(category, term, dict(castle_action=dict(action=term, target_id=row['id'], card_ids=[], use_repair_token=False)),
                               value, 'commission_ready_castle' if activate else 'select_work_with_new_guard_contribution')
    elif category == 'guards':
        limit = f.v['data']['guard_public_limits'][pid]
        for lane in LANES:
            free = f.free(pid, lane)
            for suit in ('Penitent', 'Vulture', 'Wright', 'Butcher'):
                cards = [r for r in f.hand if r['attributes']['suit'] == suit][:2]
                if len(cards) == 2 and len(free) >= 2 and limit >= 2:
                    pair = dict(Penitent=15, Vulture=16, Wright=8, Butcher=9)[suit]
                    value = weights.guard*sum(r['attributes']['value'] for r in cards)+pair+5*f.lane_need(lane)
                    yield Proposal(category, 'Deploy', dict(guard_moves=[dict(card_id=r['id'], lane=lane, slot=slot) for r, slot in zip(cards, free)]),
                                   value, 'fresh_'+suit.lower()+'_pair', tuple(r['id'] for r in cards))
            if free and f.hand and limit:
                row = max(f.hand, key=lambda r: (r['attributes']['value'], r['id']))
                yield Proposal(category, 'Deploy', dict(guard_moves=[dict(card_id=row['id'], lane=lane, slot=free[0])]),
                               weights.guard*row['attributes']['value']+5*f.lane_need(lane), 'single_guard_no_pair_reactivation', (row['id'],))
    elif category == 'resummon' and not f.lord[pid]['attributes']['alive']:
        cost = COSTS[f.kind]+3*int(f.v['data']['breach_lord'] == f.kind)
        circles = [c for c in f.castles(pid) if c['attributes']['castle_type'] == 'SummoningCircle' and operational(c)]
        if circles: cost = max(0, cost-3)
        for required in dict.fromkeys((cost, max(0, cost-(0 if f.kind == 'Humbaba' else 4)))):
            ids = f.payment(required)
            if ids or required == 0:
                paid = sum(f.by_id[k]['attributes']['value'] for k in ids)
                yield Proposal(category, 'Resummon', dict(summon=dict(card_ids=ids)),
                               weights.return_lord-8*max(0, cost-paid), 'return_lord_with_explicit_threat_tradeoff', tuple(ids))
    elif category == 'rites':
        for lane in LANES:
            units = [r for r in f.units(pid, lane) if r['attributes']['waiting']][:5]
            if len(units) == 5:
                yield Proposal(category, 'Supplicants', dict(rites=dict(waiter_spends=[dict(lane=lane, marcher_ids=[r['id'] for r in units])])),
                               weights.tear-8, 'five_supplicants_for_personal_tear')
        if f.veil >= 7 and f.v['data']['invocation_rounds'][pid] == 0:
            ids = f.payment(11)
            if ids:
                yield Proposal(category, 'Invocation', dict(rites=dict(invocation=dict(card_ids=ids))), weights.tear,
                               'once_per_game_tear_with_card_payment', tuple(ids))
        ruins = [c for c in f.castles(pid) if c['attributes']['status'] == 'ruined']
        if len(ruins) >= 2 and f.resources['souls'] >= 2:
            yield Proposal(category, 'ProfaneRuins', dict(rites=dict(profane_ruins=dict(castle_id=ruins[0]['id']))),
                           weights.tear-12, 'spend_two_souls_for_personal_tear')
    elif category == 'combat':
        yield Proposal(category, 'Pass', {}, 0, 'retain_hand_for_next_round')
        if not f.hand: return
        # One target per attack, minimum useful commitment and full commitment.
        targets = []
        if f.lord[enemy]['attributes']['alive']:
            targets.append(('Hunt', 'Lord', f.lord[enemy]['id']))
        castles = [c for c in f.castles(enemy) if targetable(c)]
        victim = min(castles, key=lambda c: (c['attributes']['integrity'], c['attributes']['castle_slot'])) if castles else None
        targets.append(('Siege', 'Castle', victim['id'] if victim else 'castle_zone:'+str(enemy)))
        for action, lane, target in targets:
            # Linear prefixes at most the hand limit, not a subset search. This
            # is one bounded construction after reserving a generation slot.
            ordered = sorted(f.hand, key=lambda r: (-f.strength([r['id']], action), r['id']))
            minimum = []
            for row in ordered:
                minimum.append(row['id'])
                result = f.attack(action, target, minimum)
                if result['banished'] or result['destroyed'] or result['pillage'] or result['guards'] or result['damage'] >= 3:
                    break
            for ids in (minimum, [r['id'] for r in ordered]):
                result = f.attack(action, target, ids)
                value = (weights.recruit*f.recruits(ids, action)+12*result['guards']+weights.damage*result['damage']
                         +weights.banishment*result['banished']+weights.destruction*result['destroyed']+12*result['pillage'])
                yield Proposal(category, action, dict(action=action, lane=lane, target_id=target, card_ids=ids), value,
                               'current_board_attack_unknown_enemy_orders', tuple(ids))
        for lane in LANES:
            for desired in (6, sum(r['attributes']['value'] for r in f.hand)):
                ids = f.payment(desired) or [r['id'] for r in f.hand]
                value = weights.recruit*f.recruits(ids, 'Ward')+min(f.strength(ids, 'Ward'), 5+5*f.lane_need(lane))*2
                if f.kind == 'Kroni': value -= 12
                yield Proposal(category, 'Ward', dict(action='Ward', lane=lane, card_ids=ids), value, 'recruit_two_to_one_and_screen_lane', tuple(ids))
        if f.lord[pid]['attributes']['alive']:
            candidates = [c for c in f.castles(pid) if operational(c) and c['attributes']['integrity'] == c['attributes']['max_integrity']
                          and c['attributes']['castle_type'] != 'Keep']
            if candidates:
                row = candidates[-1]
                yield Proposal(category, 'Profane', dict(action='Profane', lane='Castle', target_id=row['id'], card_ids=[]),
                               weights.tear-25, 'sacrifice_full_castle_for_personal_tear')


class CommonSmartCore:
    def __init__(self, weights=None, limits=None, lord_modules=True):
        self.weights, self.limits = weights or Weights(), limits or Limits()
        self.lord_modules = lord_modules

    def decide(self, view, preview):
        f, budget = Facts(view), Budget(self.limits)
        categories = ('powers', 'resummon', 'rites', 'guards', 'work', 'combat')
        generated, retained, reasons, opportunities, exhausted = {}, {}, {}, {}, {}
        counts = Counter()
        for category in categories:
            source = lords.proposals(f) if category == 'powers' and self.lord_modules else iter(()) if category == 'powers' else ordinary(f, category, self.weights)
            proposals = []
            exhausted[category] = False
            while budget.take('generated', category):
                try: p = next(source)
                except StopIteration:
                    exhausted[category] = True
                    break
                counts[(category, p.term)] += 1
                opportunities[(category, p.term)] = opportunities.get((category, p.term), False) or p.value > 0
                if category == 'powers':
                    available, reason = f.available(p.term)
                    if not available:
                        reasons[(category, p.term)] = reason
                        continue
                cost = self.weights.card_cost*sum(f.by_id[k]['attributes']['value'] for k in p.cards)
                if category == 'powers':
                    cost += 3*sum(RULES[p.term]['cost'].values())
                p.value -= cost
                if p.value <= 0:
                    reasons.setdefault((category, p.term), p.reason)
                proposals.append(p)
            generated[category] = proposals
            # Keep best distinct terms first, then fill remaining target slots.
            ranked = sorted({key(p): p for p in proposals}.values(), key=lambda p: (-p.value, key(p)))
            choices, terms = [], set()
            if category == 'combat':
                choices = [next(p for p in ranked if p.term == 'Pass')]; terms.add('Pass')
            for p in ranked:
                if p.term not in terms and len(choices) < self.limits.retained_per_category:
                    choices.append(p); terms.add(p.term)
            for p in ranked:
                if p not in choices and len(choices) < self.limits.retained_per_category: choices.append(p)
            retained[category] = [p for p in choices if budget.take('retained', category)]

        complete = []
        def assemble(anchors, priorities):
            if not budget.take('complete_plans'): return
            selected, cards, used, resource_spend = [], set(), set(), Counter()
            plan = dict(powers=[], order={})
            def add(p):
                if p.category != 'powers' and p.category in used: return False
                if cards.intersection(p.cards): return False
                if p.category == 'powers':
                    if p.term in [x.term for x in selected if x.category == 'powers']: return False
                    if p.term in WISHES and any(s['power_id'] in WISHES for s in plan['powers']): return False
                    if any(resource_spend[k]+v > f.resources.get(k, 0) for k, v in RULES[p.term]['cost'].items()): return False
                    index = len(plan['powers'])
                    source = declaration(f.pid, view['round'], p.term, p.payload['target'], index=index,
                                         discard_ids=list(p.cards) if p.cards else None, parameters=p.payload['parameters'])
                    plan['powers'].append(source); resource_spend.update(RULES[p.term]['cost'])
                else:
                    order = plan['order']
                    if ('summon' in p.payload and order.get('action') == 'Profane' or p.term == 'Profane' and 'summon' in order): return False
                    ruin = p.payload.get('rites', {}).get('profane_ruins', {}).get('castle_id')
                    work = p.payload.get('castle_action', {}).get('target_id')
                    if ruin and ruin == order.get('castle_action', {}).get('target_id'): return False
                    if work and work == order.get('rites', {}).get('profane_ruins', {}).get('castle_id'): return False
                    order.update(copy_data(p.payload)); used.add(p.category)
                cards.update(p.cards); selected.append(p)
                return True
            for p in anchors:
                if not add(p): return
            for category in priorities:
                for p in sorted(retained[category], key=lambda p: (-p.value, key(p))):
                    if p.value > 0 and add(p): break
            if 'combat' not in used:
                add(next(p for p in retained['combat'] if p.term == 'Pass'))
            score = sum(p.value for p in selected)
            # Shared Veil risk is a score, never a hard veto under hidden orders.
            # Current board, known round pressure and explicit own Rite additions
            # can flag risk; future combat/Resummon/random effects cannot prove it.
            projected = settlement_projection(f, plan)
            risk = projected['winner'] == f.enemy
            if risk: score -= self.weights.enemy_settlement_risk
            if projected['winner'] == f.pid: score += 70
            excluded = [k for spend in plan['order'].get('rites', {}).get('waiter_spends', []) for k in spend['marcher_ids']]
            combat = next(p for p in selected if p.category == 'combat')
            if excluded and combat.term in ('Hunt', 'Siege'):
                baseline = f.attack(combat.term, combat.payload['target_id'], combat.cards)
                adjusted = f.attack(combat.term, combat.payload['target_id'], combat.cards, excluded)
                score += (self.weights.damage*(adjusted['damage']-baseline['damage'])
                          +12*(adjusted['guards']-baseline['guards'])
                          +self.weights.banishment*(adjusted['banished']-baseline['banished'])
                          +self.weights.destruction*(adjusted['destroyed']-baseline['destroyed']))
            complete.append(dict(plan=plan, score=score, selected=selected, veil_risk=risk, projected=projected))

        base = ('resummon', 'rites', 'work', 'guards', 'combat')
        # Explicit conservation plan and fixed assembly priorities preserve
        # alternatives without enumerating products of category candidates.
        assemble([], ())
        for priorities in (base, ('resummon', 'combat', 'work', 'guards', 'rites'), ('work', 'guards', 'combat', 'resummon', 'rites')):
            assemble([], priorities)
            for p in retained['powers']:
                if p.value > 0: assemble([p], priorities)
        for p in retained['combat']:
            assemble([p], ('resummon', 'powers', 'work', 'guards', 'rites'))
        positive = [p for p in retained['powers'] if p.value > 0 and p.term not in WISHES]
        if len(positive) > 1: assemble(positive[:2], base)
        ranked = sorted({fingerprint(c['plan']): c for c in complete}.values(),
                        key=lambda c: (-c['score'], sum(len(p.cards) for p in c['selected']), fingerprint(c['plan'])))
        rejected, chosen = [], None
        for c in ranked:
            if not budget.take('previews'): break
            result = preview(copy_data(c['plan']))
            if result.get('action') == 'legal': chosen = c; break
            rejected.append(dict(plan_sha256=fingerprint(c['plan']), result=result))
        if chosen is None:
            raise ValueError('No admitted plan within preview budget: '+repr(rejected))
        picked = {(p.category, p.term) for p in chosen['selected']}
        terms = [('powers', p) for p in (*POWERS[f.kind], *BREACH_WISHES)]
        terms += [(c, t) for c, ts in dict(resummon=('Resummon',), rites=('Supplicants', 'Invocation', 'ProfaneRuins'),
                 guards=('Deploy',), work=('Work', 'Activate'), combat=('Pass', 'Ward', 'Hunt', 'Siege', 'Profane')).items() for t in ts]
        assessments = []
        for category, term in terms:
            selected = (category, term) in picked
            count = counts[(category, term)]
            kept = sum(p.term == term for p in retained[category])
            if selected: reason = 'selected'
            elif (category, term) in reasons: reason = reasons[(category, term)]
            elif kept: reason = 'scoring_or_shared_budget'
            elif count: reason = 'retention_budget'
            elif category == 'powers' and not self.lord_modules: reason = 'lord_modules_disabled'
            elif not exhausted[category]: reason = 'generation_budget_unmeasured'
            else: reason = 'no_current_board_opportunity'
            opportunity = opportunities.get((category, term), False if exhausted[category] else None)
            if category == 'powers' and not self.lord_modules: opportunity = None
            assessments.append(dict(category=category, term=term, opportunity=opportunity,
                legal=True if selected else None, affordable=True if selected else False if reason == 'resource_shortfall' else None,
                generated=count, retained=kept, selected=selected, reason=reason))
        from u13_pysim import monsters
        monster_state = f.v['data'].get('monsters', {})
        if monster_state:
            names = monsters.available(f.v['board']+f.v['hand'], chosen['plan']['order'].get('card_ids', []), f.pid, monster_state['unlocked'][f.pid])
            if names: chosen['plan']['order']['monster_choice'] = names[-1]
        return dict(policy=VERSION, plan=copy_data(chosen['plan']), score=chosen['score'],
                    chosen_reasons=[p.reason for p in chosen['selected']], assessments=assessments,
                    retained_candidates=[dict(category=p.category, term=p.term, score=p.value, reason=p.reason,
                                              candidate_sha256=key(p)) for category in categories for p in retained[category]],
                    budget=budget.report(), rejected_previews=rejected,
                    assumptions='current public board; new Guards, Ward, Work, simultaneous powers and spatial/random reactions are uncertain',
                    veil=dict(current_board_risk=chosen['veil_risk'], paid_choice_scenario=chosen['projected'],
                              hard_veto=False, reason='hidden_orders_prevent_proof'))

    def choose_card(self, view, category):
        """Stockpile/Slaver decisions use the same bounded, private-hand boundary."""
        f, budget = Facts(view), Budget(self.limits)
        if category not in ('stockpile', 'slaver'): raise ValueError('unknown card choice')
        def utility(cards):
            suits = Counter(r['attributes']['suit'] for r in cards)
            return 3*sum(r['attributes']['value'] for r in cards)+4*sum(n//2 for n in suits.values())
        options = []
        if category == 'stockpile':
            pending = {r['id'] for r in view['stockpile']}
            base = [r for r in f.hand if r['id'] not in pending]
            for row in sorted(view['stockpile'], key=lambda r: r['id']):
                if not budget.take('generated', category): break
                options.append((utility(base+[row])-utility(base), dict(kind='stockpile', player_id=f.pid, keep_id=row['id'])))
        else:
            budget.take('generated', category)
            options.append((0, dict(kind='market', player_id=f.pid, choice=dict(market='Pass'))))
            before = utility(f.hand)
            give = min(f.hand, key=lambda r: (before-utility([c for c in f.hand if c['id'] != r['id']]), r['id'])) if f.hand else None
            for row in sorted(view['market'], key=lambda r: r['id']):
                if not give or not budget.take('generated', category): break
                after = [r for r in f.hand if r['id'] != give['id']] + [row]
                options.append((utility(after)-before, dict(kind='market', player_id=f.pid,
                    choice=dict(market='Swap', give_id=give['id'], take_id=row['id']))))
        if not options: raise ValueError('no card-choice candidates')
        value, operation = min(options, key=lambda x: (-x[0], fingerprint(x[1])))
        budget.take('retained', category)
        term = 'Keep' if category == 'stockpile' else operation['choice']['market']
        return dict(operation=operation, budget=budget.report(), assessment=dict(category=category, term=term,
            opportunity=value > 0, legal=True, affordable=True, generated=len(options), retained=1, selected=True,
            reason='face_value_and_pair_preservation' if value > 0 else 'conserve_current_hand'))
