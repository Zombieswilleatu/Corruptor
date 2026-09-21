"""Fresh bounded U13 planning alpha. Integer weights are injected, never tuned here.

Generate a small set of category proposals, then assemble fixed priority bundles.
No Cartesian products, full-game candidate rollouts, or elapsed-time cutoffs.
"""
from collections import Counter
from dataclasses import asdict, dataclass

from u13_pysim import split_ward as split_rules
from . import split_ward
from u13_pysim.battle import operational, targetable
from u13_pysim.copying import copy_data
from u13_pysim.development import eligible, commission_eligible
from u13_pysim.opening import COSTS
from u13_pysim.power_rules import RULES, declaration
from u13_pysim.powers import WISHES
from . import lords
from .lords.odradek import ResourceHorizon, RECONFIGURATION, SAVING_GOALS
from .lords.deimos import ArtilleryPlans, RoutPlans
from .lords.humbaba import SupportPlans
from .lords.orias import OriasPlans
from .lords.valak import ValakPlans
from .lords.kroni import KroniPlans, normalize as kroni_normalize
from .lords.gremory import RuinPlans
from .kanifous_tactics import WishPlans, PROFILES as WISH_PROFILES, DEFAULT_PROFILE
from .budget import Budget, Limits
from . import closing, coordination, defensive_plans
from .coverage import POWERS
from .diagnostics import fingerprint
from .facts import Facts, Proposal, LANES
from .recipes import Recipes
from .selection import PlanSelector
from .veil_judgment import settlement_projection, protection_projection

VERSION = 'U13_COMMON_SMART_CORE_ALPHA_V28_ATTACK_RECIPES'
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
    monster: int = 2
    recipe_save: int = 1
    veil_protection: int = 8

    def __post_init__(self):
        if any(type(v) is not int or v < 0 for v in asdict(self).values()):
            raise ValueError('weights must be nonnegative integers')


def key(p):
    return fingerprint([p.category, p.term, p.payload, p.cards])


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
        for action, lane, target in f.attack_targets():
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
                value = f.attack_value(action, target, ids, weights)
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
    def __init__(self, weights=None, limits=None, lord_modules=True, selector=None, wish_profile=DEFAULT_PROFILE):
        self.weights, self.limits = weights or Weights(), limits or Limits()
        self.lord_modules = lord_modules
        self.selector = selector if selector is not None else PlanSelector()
        if wish_profile not in WISH_PROFILES: raise ValueError('Unknown Wish calibration profile')
        self.wish_profile = wish_profile

    @property
    def policy_id(self):
        return VERSION+self.selector.policy_suffix+('' if self.wish_profile==DEFAULT_PROFILE else ':WISH_'+self.wish_profile)

    def decide(self, view, preview):
        f, budget = Facts(view), Budget(self.limits)
        f.wish_profile = self.wish_profile
        recipes = Recipes(f, self.weights)
        initial_goal = recipes.goal(f.hand)
        categories = ('powers', 'resummon', 'rites', 'guards', 'work', 'combat', 'monsters')
        generated, retained, reasons, opportunities, exhausted = {}, {}, {}, {}, {}
        counts = Counter()
        resource_options = []
        for category in categories:
            source = (lords.proposals(f) if self.lord_modules else iter(())) if category == 'powers' else recipes.proposals() if category == 'monsters' else ordinary(f, category, self.weights)
            proposals = []
            exhausted[category] = False
            while budget.take('generated', category):
                try: p = next(source)
                except StopIteration:
                    exhausted[category] = True
                    break
                if p.category == 'combat': recipes.attach(p)
                counts[(p.category, p.term)] += 1
                opportunities[(p.category, p.term)] = opportunities.get((p.category, p.term), False) or p.value > 0
                if category == 'powers':
                    if f.kind == 'Odradek' and p.term in SAVING_GOALS:
                        resource_options.append(dict(power=p.term, target=copy_data(p.payload['target'])))
                    available, reason = f.available(p.term)
                    if not available:
                        reasons[(category, p.term)] = reason
                        continue
                cost = self.weights.card_cost*sum(f.by_id[k]['attributes']['value'] for k in p.cards)
                if category == 'powers':
                    cost += 3*sum(RULES[p.term]['cost'].values())
                p.value -= cost
                if p.value <= 0:
                    reasons.setdefault((p.category, p.term), p.reason)
                proposals.append(p)
            generated[category] = proposals
            # Keep best distinct terms first, then fill remaining target slots.
            ranked = sorted({key(p): p for p in proposals}.values(), key=lambda p: (-p.value, key(p)))
            choices, terms = [], set()
            if category == 'combat':
                choices = [next(p for p in ranked if p.term == 'Pass')]; terms.add('Pass')
            if category == 'guards':
                # Preserve a placement in each legal lane before using the
                # remaining slots for alternate suits/values.
                for lane in LANES:
                    p = next((p for p in ranked if p.payload['guard_moves'][0]['lane'] == lane), None)
                    if p and len(choices) < self.limits.retained_per_category: choices.append(p)
                if choices: terms.add('Deploy')
            if category == 'powers' and f.kind == 'Orias' and self.limits.retained_per_category >= 3:
                # Preserve the densest current cluster in both lanes before
                # extra control placements. Snare retains its existing slot.
                snare = next((p for p in ranked if p.term == 'Snare'), None)
                if snare: choices.append(snare); terms.add('Snare')
                for lane in LANES:
                    lane_webs = [p for p in ranked if p.term == 'Web' and p.payload['target']['lane'] == lane]
                    p = next((p for p in lane_webs if p.reason == 'web_dense_cluster_and_control'),
                             next(iter(lane_webs), None))
                    if p and len(choices) < self.limits.retained_per_category: choices.append(p)
                if any(p.term == 'Web' for p in choices): terms.add('Web')
            if category == 'powers' and f.kind == 'Valak' and self.limits.retained_per_category >= 3:
                shot = next((p for p in ranked if p.term == 'Projection'), None)
                if shot: choices.append(shot); terms.add('Projection')
                for lane in LANES:
                    orb = next((p for p in ranked if p.term == 'GravityOrb' and p.payload['target']['lane'] == lane), None)
                    if orb: choices.append(orb)
                if any(p.term == 'GravityOrb' for p in choices): terms.add('GravityOrb')
            if category == 'powers' and f.kind == 'Kalligan' and self.limits.retained_per_category >= 4:
                pulse = next((p for p in ranked if p.term == 'Pyroclasm'), None)
                if pulse: choices.append(pulse); terms.add('Pyroclasm')
                for lane in LANES:
                    shot = next((p for p in ranked if p.term == 'Inferno' and p.payload['target'].get('lane') == lane), None)
                    if shot: choices.append(shot)
                castle = next((p for p in ranked if p.term == 'Inferno' and p.payload['target']['kind'] == 'castle'), None)
                if castle: choices.append(castle)
                if any(p.term == 'Inferno' for p in choices): terms.add('Inferno')
            if category == 'powers' and f.kind == 'Kroni' and self.limits.retained_per_category >= 3:
                for lane in LANES:
                    meal = next((p for p in ranked if p.term == 'Consume' and f.by_id[p.payload['target']['entity_id']]['attributes']['lane'] == lane), None)
                    if meal: choices.append(meal)
                if choices: terms.add('Consume')
            for p in ranked:
                term = p.payload['monster_choice'] if category == 'monsters' else p.term
                if term not in terms and len(choices) < self.limits.retained_per_category:
                    choices.append(p); terms.add(term)
            for p in ranked:
                if p not in choices and len(choices) < self.limits.retained_per_category: choices.append(p)
            retained[category] = [p for p in choices if budget.take('retained', category)]

        split = (split_ward.retain(split_ward.proposals(f, self.weights, retained, budget), budget)
                 if split_rules.enabled(f.world) else [])
        horizon = ResourceHorizon(f, resource_options)
        defense = defensive_plans.Defense(f, self.weights)
        artillery = ArtilleryPlans(f, self.weights)
        support = SupportPlans(f, self.lord_modules)
        rout = RoutPlans(f, self.lord_modules)
        orias = OriasPlans(f, self.lord_modules)
        gremory = RuinPlans(f, self.weights, self.lord_modules)
        kanifous = WishPlans(f, self.lord_modules)
        valak = ValakPlans(f, self.lord_modules)
        kroni = KroniPlans(f, self.lord_modules)
        complete = []
        omission_reserve = (min(4, self.limits.complete_plans//4)
            if any(p.term in coordination.TERMS for p in retained['powers']) else 0)
        defense_reserve = min(4, self.limits.complete_plans//4) if retained['guards'] or len(retained['work']) > 1 else 0
        artillery_reserve = min(4, self.limits.complete_plans//4) if artillery.needs_alternatives else 0
        support_reserve = min(4, self.limits.complete_plans//4) if support.enabled else 0
        rout_reserve = min(4, self.limits.complete_plans//4) if rout.enabled else 0
        orias_reserve = min(4, self.limits.complete_plans//4) if orias.enabled else 0
        gremory_reserve = min(4, self.limits.complete_plans//4) if gremory.enabled else 0
        kanifous_reserve = min(4, self.limits.complete_plans//4) if kanifous.enabled else 0
        valak_reserve = min(4, self.limits.complete_plans//4) if valak.enabled else 0
        kroni_reserve = min(4, self.limits.complete_plans//4) if kroni.enabled else 0
        assembly_limit = max(1, self.limits.complete_plans-len(split)-omission_reserve-defense_reserve-artillery_reserve-support_reserve-rout_reserve-orias_reserve-gremory_reserve-kanifous_reserve-valak_reserve-kroni_reserve)
        def assemble(anchors, priorities, reserve=(), omitted=(), defense_variant='', artillery_variant=False, support_variant=False, rout_variant=False, orias_variant=False, gremory_variant=False, kanifous_variant=False, valak_variant=False, kroni_variant=False, split_variant=False):
            if not split_variant and not omitted and not defense_variant and not artillery_variant and not support_variant and not rout_variant and not orias_variant and not gremory_variant and not kanifous_variant and not valak_variant and not kroni_variant and budget.report()['used'].get('complete_plans', 0) >= assembly_limit: return
            if not budget.take('complete_plans'): return
            selected, cards, used, resource_spend = [], set(), set(), Counter()
            plan = dict(powers=[], order={})
            def add(p):
                if p.category != 'powers' and p.category in used: return False
                if cards.intersection(p.cards) or set(reserve).intersection(p.cards): return False
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
                    if ruin:
                        if resource_spend['souls']+2 > f.resources['souls']: return False
                        resource_spend['souls'] += 2
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
            enforced_omissions = []
            if f.kind == 'Kroni':
                selected, enforced_omissions = kroni_normalize(f, plan, selected, retained['powers'])
            score = sum(p.value for p in selected)
            # Shared Veil risk is a score, never a hard veto under hidden orders.
            # Current board, known round pressure and explicit own Rite additions
            # can flag risk; future combat/Resummon/random effects cannot prove it.
            projected = settlement_projection(f, plan)
            risk = projected['winner'] == f.enemy
            if risk: score -= self.weights.enemy_settlement_risk
            protection = protection_projection(f, plan, self.weights.veil_protection)
            # No next-round protection credit after this scenario settles.
            if projected['winner'] == -1: score += protection['score']
            remaining_goal = recipes.goal([r for r in f.hand if r['id'] not in cards], plan['order'].get('monster_choice', ''))
            saving_delta = remaining_goal['score']-initial_goal['score']
            if projected['winner'] == -1: score += saving_delta
            excluded = [k for spend in plan['order'].get('rites', {}).get('waiter_spends', []) for k in spend['marcher_ids']]
            combat = next(p for p in selected if p.category == 'combat')
            if excluded and combat.term in ('Hunt', 'Siege'):
                baseline = f.attack(combat.term, combat.payload['target_id'], combat.cards)
                adjusted = f.attack(combat.term, combat.payload['target_id'], combat.cards, excluded)
                score += (self.weights.damage*(adjusted['damage']-baseline['damage'])
                          +12*(adjusted['guards']-baseline['guards'])
                          +self.weights.banishment*(adjusted['banished']-baseline['banished'])
                          +self.weights.destruction*(adjusted['destroyed']-baseline['destroyed']))
            coordinated = coordination.evaluate(f, plan)
            score += coordinated['score_delta']
            resource = horizon.evaluate(plan, coordinated['context'] or
                (coordination.context(f, plan) if horizon.options else None), projected)
            score += resource['score']
            defensive = defense.evaluate(plan, selected, projected)
            score += defensive['score_delta']
            artillery_score = artillery.evaluate(plan)
            score += artillery_score['score_delta']
            complete.append(dict(plan=plan, score=score, selected=selected, veil_risk=risk, projected=projected,
                                 protection=protection, remaining_goal=remaining_goal, saving_delta=saving_delta,
                                 coordination=coordinated, resource_horizon=resource, omitted_powers=sorted(set(omitted) | set(enforced_omissions)),
                                 defense=defensive, defense_variant=defense_variant,
                                 artillery=artillery_score, artillery_variant=artillery_variant, support_variant=support_variant))

        base = ('resummon', 'rites', 'work', 'guards', 'monsters', 'combat')
        # Explicit conservation plan and fixed assembly priorities preserve
        # alternatives without enumerating products of category candidates.
        assemble([], ())
        # Paid Rites can have zero/negative immediate material value while
        # changing settlement or revealed Veil protection. Reserve their small
        # set of anchored plans before ordinary bundles consume the plan budget.
        # Keep both a conservation plan and one compatible bundle: adding a
        # power can spend Souls needed for the Rite's settlement scenario.
        for p in retained['rites']:
            assemble([p], ())
            assemble([p], ('resummon', 'powers', 'work', 'guards', 'combat'))
        for priorities in (base, ('resummon', 'combat', 'work', 'guards', 'rites'), ('work', 'monsters', 'guards', 'combat', 'resummon', 'rites')):
            assemble([], priorities)
            for p in retained['powers']:
                if p.value > 0 or (f.kind == 'Kalligan' and p.term in ('Inferno','Pyroclasm')) or (f.kind == 'Odradek' and p.term == 'Redirect'):
                    assemble([p], priorities)
        for p in retained['combat']+retained['monsters']:
            assemble([p], ('resummon', 'powers', 'work', 'guards', 'rites'))
        if initial_goal['card_ids']:
            assemble([], ('resummon', 'powers', 'work', 'guards', 'combat', 'rites'), reserve=initial_goal['card_ids'])
        positive = [p for p in retained['powers'] if p.value > 0 and p.term not in WISHES]
        if len(positive) > 1: assemble(positive[:2], base)
        for p in split:
            assemble([p], ('resummon', 'powers', 'work', 'guards', 'rites'), split_variant=True)
        defensive_variants = []
        variants = defensive_plans.alternatives(f, complete, retained)
        for _ in range(defense_reserve):
            try: anchors, reason = next(variants)
            except StopIteration: break
            before = len(complete)
            assemble(anchors, (), defense_variant=reason)
            if len(complete) > before: defensive_variants.append(reason)
        artillery_alternatives = 0
        variants = artillery.alternatives(complete, budget)
        for _ in range(artillery_reserve):
            try: anchors = next(variants)
            except StopIteration: break
            before = len(complete)
            assemble(anchors, (), artillery_variant=True)
            artillery_alternatives += len(complete)-before
        support_alternatives = 0
        variants = support.alternatives(complete, retained, budget)
        for _ in range(support_reserve):
            try: anchors = next(variants)
            except StopIteration: break
            before = len(complete)
            assemble(anchors, (), support_variant=True)
            support_alternatives += len(complete)-before
        rout_alternatives = 0
        variants = rout.alternatives(complete, retained, budget)
        for _ in range(rout_reserve):
            try: anchors = next(variants)
            except StopIteration: break
            before = len(complete)
            assemble(anchors, (), rout_variant=True)
            rout_alternatives += len(complete)-before
        orias_alternatives = 0
        variants = orias.alternatives(complete, retained, budget)
        for _ in range(orias_reserve):
            try: anchors = next(variants)
            except StopIteration: break
            before = len(complete)
            assemble(anchors, (), orias_variant=True)
            orias_alternatives += len(complete)-before
        # Reserve up to four complete-plan slots for a controlled comparison:
        # same own choices, without powers whose standalone credit is reduced.
        # Reassemble to recompute payments, recipes, declaration IDs and Veil.
        # No products of alternative targets/payments or extra previews.
        gremory_alternatives = 0
        variants = gremory.alternatives(complete, budget)
        for _ in range(gremory_reserve):
            try: anchors = next(variants)
            except StopIteration: break
            before = len(complete)
            assemble(anchors, (), gremory_variant=True)
            gremory_alternatives += len(complete)-before
        kanifous_alternatives = 0
        variants = kanifous.alternatives(complete, budget)
        for _ in range(kanifous_reserve):
            try: anchors = next(variants)
            except StopIteration: break
            before = len(complete)
            assemble(anchors, (), kanifous_variant=True)
            kanifous_alternatives += len(complete)-before
        valak_alternatives = 0
        variants = valak.alternatives(complete, retained, budget)
        for _ in range(valak_reserve):
            try: anchors = next(variants)
            except StopIteration: break
            before = len(complete)
            assemble(anchors, (), valak_variant=True)
            valak_alternatives += len(complete)-before
        kroni_alternatives = 0
        variants = kroni.alternatives(complete, retained, budget)
        for _ in range(kroni_reserve):
            try: anchors = next(variants)
            except StopIteration: break
            before = len(complete)
            assemble(anchors, (), kroni_variant=True)
            kroni_alternatives += len(complete)-before
        omissions, resource_omissions, omission_keys = 0, 0, set()
        for candidate in sorted(complete, key=lambda c: (
                -int(c['projected']['winner'] == f.pid), -c['score'], fingerprint(c['plan']))):
            if omissions >= omission_reserve: break
            omit = sorted(r['power'] for r in candidate['coordination']['powers'] if r['score_delta'] < 0)
            conserving = bool(horizon.options and candidate['resource_horizon']['spent'])
            if conserving:
                omit = sorted(set(omit) | {p['power_id'] for p in candidate['plan']['powers'] if p['power_id'] in RECONFIGURATION})
            if not omit: continue
            anchors = [p for p in candidate['selected'] if not (p.category == 'powers' and p.term in omit)]
            identity = tuple(key(p) for p in anchors)
            if identity in omission_keys: continue
            omission_keys.add(identity)
            before = len(complete)
            assemble(anchors, (), omitted=omit)
            omissions += len(complete)-before
            if conserving: resource_omissions += len(complete)-before
        unique = list({fingerprint(c['plan']): c for c in complete}.values())
        closing.prioritize(f, unique)
        ranked = sorted(unique,
                        key=lambda c: (-c['score'], sum(len(p.cards) for p in c['selected']),
                                       len(c['plan']['powers']), fingerprint(c['plan'])))
        from u13_pysim import game_staging
        if game_staging.enabled(f.world):
            staging = game_staging.bot_order(f.world, f.v['round'], f.pid)
            # Native admission must preview the exact final command. Adding
            # staging after selection would change the already admitted plan.
            for candidate in ranked:
                candidate['plan']['order']['staging'] = copy_data(staging)
        chosen, rejected, selection = self.selector.select(ranked, preview, budget,
            round_number=view['round'], seat=f.pid)
        picked = {(p.category, p.term) for p in chosen['selected']}
        if chosen['plan']['order'].get('ward'): picked.add(('combat', 'Ward'))
        rite_plans = {}
        for term in ('Supplicants', 'Invocation', 'ProfaneRuins'):
            scored = [c for c in complete if any(p.category == 'rites' and p.term == term for p in c['selected'])]
            rite_plans[term] = dict(scored_plans=len(scored),
                current_board_wins=sum(c['projected']['winner'] == f.pid for c in scored),
                current_board_losses=sum(c['projected']['winner'] == f.enemy for c in scored),
                selected=('rites', term) in picked)
        terms = [('powers', p) for p in (*POWERS[f.kind], *BREACH_WISHES)]
        terms += [(c, t) for c, ts in dict(resummon=('Resummon',), rites=('Supplicants', 'Invocation', 'ProfaneRuins'),
                 guards=('Deploy',), work=('Work', 'Activate'), combat=('Pass', 'Ward', 'Hunt', 'Siege', 'Profane')).items() for t in ts]
        assessments = []
        for category, term in terms:
            selected = (category, term) in picked
            count = counts[(category, term)]
            alternatives = retained[category]+(retained['monsters'] if category == 'combat' else [])
            kept = sum(p.term == term for p in alternatives)
            if selected: reason = 'selected'
            elif category == 'rites' and kept:
                reason = ('complete_plan_score' if selection['mode'] == 'greedy' else 'complete_plan_selection') if rite_plans[term]['scored_plans'] else 'complete_plan_budget'
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
        assessments.extend(recipes.assessments(generated['combat']+generated['monsters'],
            retained['combat']+retained['monsters'], chosen['plan'], exhausted['monsters'] and exhausted['combat']))
        return dict(policy=self.policy_id+(':SPLIT_WARD_V1' if split_rules.enabled(f.world) else ''),
                    split_ward=dict(enabled=split_rules.enabled(f.world), candidates=len(split),
                                    selected=bool(chosen['plan']['order'].get('ward'))), plan=copy_data(chosen['plan']), score=chosen['score'], selection=selection,
                    chosen_reasons=[p.reason for p in chosen['selected']], assessments=assessments,
                    retained_candidates=[dict(category=p.category, term=p.term, score=p.value, reason=p.reason,
                                              source_category=category, monster=p.payload.get('monster_choice', ''),
                                              candidate_sha256=key(p)) for category in categories for p in retained[category]],
                    budget=budget.report(), rejected_previews=rejected, rite_plans=rite_plans,
                    closing=closing.report(unique, chosen),
                    coordination=coordination.report(unique, chosen, omissions),
                    resource_horizon=horizon.report(unique, chosen, resource_omissions),
                    defense=defensive_plans.report(unique, chosen, defensive_variants),
                    artillery=artillery.report(unique, chosen, artillery_alternatives),
                    support=support.report(chosen, support_alternatives),
                    rout=rout.report(chosen, rout_alternatives),
                    orias=orias.report(chosen, orias_alternatives),
                    gremory=gremory.report(chosen, gremory_alternatives),
                    kanifous=kanifous.report(chosen, kanifous_alternatives),
                    valak=valak.report(chosen, valak_alternatives),
                    kroni=kroni.report(chosen, kroni_alternatives),
                    assumptions='current public board; new Guards, Ward, Work, simultaneous powers and spatial/random reactions are uncertain',
                    veil=dict(current_board_risk=chosen['veil_risk'], paid_choice_scenario=chosen['projected'],
                              protection=chosen['protection'], hard_veto=False, reason='hidden_orders_prevent_proof'),
                    recipes=dict(initial_goal=initial_goal, retained_goal=chosen['remaining_goal'],
                                 saving_score_delta=chosen['saving_delta'], selected=chosen['plan']['order'].get('monster_choice', '')))

    def choose_card(self, view, category):
        """Stockpile/Slaver decisions use the same bounded, private-hand boundary."""
        f, budget = Facts(view), Budget(self.limits)
        recipes = Recipes(f, self.weights)
        if category not in ('stockpile', 'slaver'): raise ValueError('unknown card choice')
        def utility(cards):
            suits = Counter(r['attributes']['suit'] for r in cards)
            return 3*sum(r['attributes']['value'] for r in cards)+4*sum(n//2 for n in suits.values())+recipes.goal(cards)['score']
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
            reason='face_value_pairs_and_recipe_progress' if value > 0 else 'conserve_current_hand'))
