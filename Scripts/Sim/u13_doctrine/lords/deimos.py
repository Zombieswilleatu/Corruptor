"""Deimos: operational artillery and enemy lane retreat.

Passives: reconstruction is handled by common Work; Spoils remains an observed
effect, not fabricated income. Rout snapshots enemies present when it fires.
"""
from u13_pysim.battle import operational, targetable
from u13_pysim.copying import copy_data
from ..defensive_plans import development
from ..diagnostics import fingerprint
from ..facts import Facts, LANES, Proposal, power
from ..lane_support import mobile, travel
from .. import rout_answers

LORD = 'Deimos'


def proposals(f):
    targets = any(targetable(c) for c in f.castles(f.enemy))
    for row in f.castles(f.pid):
        if row['attributes'].get('combat_profile') == 'siege_engine' and operational(row):
            yield power('WarMachine', dict(entity_id=row['id']), 18 if targets else 0,
                        'operational_extra_artillery' if targets else 'no_public_artillery_target')
    for lane in LANES:
        enemies = f.units(f.enemy, lane)
        if enemies:
            value = rout_value(f, lane)
            yield power('Rout', dict(lane=lane), value['score'],
                        'retreat_public_lane_pressure' if value['score'] else 'hold_rout_for_lane_pressure')


def rout_value(f, lane):
    """Prefer a reachable fight or gate threat over a distant head count.

    This is a public, unopposed-distance scenario. Opposing recruits, Supplicant
    spends, movement modifiers and paths are unknown. Rout does not silence
    monster specials, so an immobile Sooge turret earns no suppression credit.
    """
    number = f.v['round']; threats, gates, distant = [], [], []
    allies = [r for r in f.units(f.pid, lane) if not r['attributes'].get('hidden', False)]
    for enemy in f.units(f.enemy, lane):
        a = enemy['attributes']
        if a.get('sprite_form') == 'turret' or a.get('hidden', False):
            continue
        distance = travel(a, number)
        gate = (a.get('waiting', False) or mobile(a) and a.get('movement_ready_round', 0) <= number
                and (a['x_fp'] if f.pid == 0 else 2400-a['x_fp']) <= distance)
        reach = 400 if a.get('suit') == 'Vulture' else 90
        fight = any((a['x_fp']-r['attributes']['x_fp'])**2+(a['y_fp']-r['attributes']['y_fp'])**2
                    <= (distance+travel(r['attributes'], number)+reach)**2 for r in allies)
        if gate or fight:
            threats.append(enemy['id'])
            if gate: gates.append(enemy['id'])
        else: distant.append(enemy['id'])
    return dict(score=8*len(threats)+6*len(gates), threats=threats, gate_threats=gates, distant=distant)


def coordinate(f, plan, ctx):
    if not hasattr(f, '_rout_answer_cache'): f._rout_answer_cache = {}
    for source in plan['powers']:
        if source['power_id'] != 'Rout': continue
        lane = source['target']['lane']
        key = fingerprint([lane, ctx['consumed_supplicants'], ctx['recruit_lane'],
                           ctx['recruit_suits'], ctx['monster']])
        if key not in f._rout_answer_cache:
            f._rout_answer_cache[key] = rout_answers.evaluate(f, lane, ctx, rout_value(f, lane))
        value = f._rout_answer_cache[key]
        yield dict(power='Rout', lane=lane, reason='available_plan_answer_to_public_wave',
                   score_delta=value['score']-value['baseline_score'], **value)


def attack_value(result, weights):
    # Recruitment/recipes happen before combat and survive a fizzled Siege.
    return (12*result['guards'] + weights.damage*result['damage']
            + weights.banishment*result['banished'] + weights.destruction*result['destroyed']
            + 12*result['pillage'])


def attack_after(f, order, excluded):
    if (order['action'] == 'Siege' and any(targetable(c) for c in f.castles(f.enemy))
            and not targetable(f.by_id.get(order['target_id']))):
        return dict(guards=0, damage=0, banished=False, destroyed=False, pillage=False, castle_hits={})
    return f.attack(order['action'], order['target_id'], order['card_ids'], excluded)


class ArtilleryPlans:
    """Conditional own-artillery scenarios; no RNG or opposing-order access.

    War Machine fires before normal artillery. Follow public locked targets and
    uniquely determined reacquisitions only. Unknown acquisitions are recorded,
    never chosen with the simulation seed. Opposing repairs/fire and reactions
    can invalidate the scenario, so it changes scores rather than legality.
    """
    def __init__(self, f, weights):
        self.f, self.weights, self.cache = f, weights, {}
        engines = [r for r in f.castles(f.pid) if r['attributes'].get('combat_profile') == 'siege_engine']
        self.enabled = f.kind == LORD and bool(engines)
        self.needs_alternatives = self.enabled and any(
            operational(r) and targetable(f.by_id.get(r['attributes']['artillery_target']))
            and f.by_id[r['attributes']['artillery_target']]['attributes']['integrity'] <= 4 for r in engines)

    def project(self, plan, extra=True):
        engines = [s['target']['entity_id'] for s in plan['powers'] if extra and s['power_id'] == 'WarMachine']
        key = fingerprint([plan['order'].get('castle_action'), plan['order'].get('guard_moves', []), engines])
        if key in self.cache: return self.cache[key]
        world, _ = development(self.f, plan)
        by_id = {r['id']: r for r in world['entities']['entities']}
        normal = sorted(r['id'] for r in world['entities']['entities'] if r['owner'] == self.f.pid
                        and r['kind'] == 'castle' and r['attributes'].get('combat_profile') == 'siege_engine')
        hits, unknown = [], 0
        for identity, mode in [(k, 'WarMachine') for k in engines]+[(k, 'normal') for k in normal]:
            engine = by_id[identity]
            if not operational(engine): continue
            a = engine['attributes']; victim = by_id.get(a['artillery_target'])
            if not targetable(victim):
                targets = [r for r in world['entities']['entities'] if r['owner'] == self.f.enemy and targetable(r)]
                if not targets: continue
                if len(targets) != 1:
                    unknown += 1
                    continue
                victim = targets[0]; a['artillery_target'] = victim['id']
            before = victim['attributes']['integrity']; damage = min(before, 2)
            victim['attributes']['integrity'] -= damage
            if before <= 2: victim['attributes']['status'] = 'ruined'
            hits.append(dict(engine_id=identity, shot=mode, target_id=victim['id'], damage=damage,
                             destroyed=before <= 2))
        view = dict(self.f.v, board=world['entities']['entities'], data=world['data'], players=world['players'])
        result = Facts(view), hits, unknown
        self.cache[key] = result
        return result

    def evaluate(self, plan):
        result = dict(enabled=self.enabled, score_delta=0, attack_score_delta=0,
                      war_machine_score_delta=0, siege_target_lost=False, hits=[], unknown_shots=0)
        # Resummon/Conduit can alter infrastructure before Development.
        if not self.enabled or 'summon' in plan['order']:
            result['enabled'] = False
            return result
        after, hits, unknown = self.project(plan)
        result.update(hits=hits, unknown_shots=unknown)
        order = plan['order']
        if order.get('action') in ('Hunt', 'Siege'):
            excluded = [k for s in order.get('rites', {}).get('waiter_spends', []) for k in s['marcher_ids']]
            before = self.f.attack(order['action'], order['target_id'], order['card_ids'], excluded)
            changed = attack_after(after, order, excluded)
            result['attack_score_delta'] = attack_value(changed, self.weights)-attack_value(before, self.weights)
            result['siege_target_lost'] = (order['action'] == 'Siege'
                and not targetable(after.by_id.get(order['target_id']))
                and any(targetable(c) for c in after.castles(after.enemy)))
        if any(s['power_id'] == 'WarMachine' for s in plan['powers']):
            _, automatic, unresolved = self.project(plan, extra=False)
            # Preserve the old 18-point value for two extra Integrity. Do not
            # call damage incremental when either acquisition remains unknown.
            if not unknown and not unresolved:
                incremental = max(0, min(2, sum(h['damage'] for h in hits)-sum(h['damage'] for h in automatic)))
                result['war_machine_score_delta'] = 9*incremental-18
        result['score_delta'] = result['attack_score_delta']+result['war_machine_score_delta']
        return result

    def alternatives(self, candidates, budget):
        """At most four target replacements inside the total plan budget.

        Search has its own explicit 16-generated / four-retained source limits;
        each replacement preserves cards, recruitment, recipe and other orders.
        """
        seen = {fingerprint(c['plan']) for c in candidates}
        for c in sorted(candidates, key=lambda c: (-c['score'], fingerprint(c['plan']))):
            if not c['artillery']['siege_target_lost']: continue
            plan, order = c['plan'], c['plan']['order']
            after, _, _ = self.project(plan)
            excluded = [k for s in order.get('rites', {}).get('waiter_spends', []) for k in s['marcher_ids']]
            choices = []
            for row in after.castles(after.enemy):
                if not targetable(row): continue
                if not budget.take('generated', 'artillery'): return
                changed = dict(order, target_id=row['id'])
                score = attack_value(attack_after(after, changed, excluded), self.weights)
                choices.append((score, row['id']))
            if not choices: continue
            _, target = min(choices, key=lambda x: (-x[0], x[1]))
            changed = copy_data(plan); changed['order']['target_id'] = target
            key = fingerprint(changed)
            if key in seen: continue
            if not budget.take('retained', 'artillery'): return
            seen.add(key)
            original = next(p for p in c['selected'] if p.category == 'combat')
            before = self.f.attack('Siege', order['target_id'], original.cards)
            replacement = self.f.attack('Siege', target, original.cards)
            proposal = Proposal('combat', 'Siege', dict(original.payload, target_id=target),
                original.value+attack_value(replacement, self.weights)-attack_value(before, self.weights),
                original.reason+'_after_own_artillery', original.cards)
            yield [proposal if p is original else p for p in c['selected']]

    def report(self, candidates, chosen, alternatives):
        return dict(enabled=self.enabled, assessed_plans=sum(c['artillery']['enabled'] for c in candidates),
            target_loss_plans=sum(c['artillery']['siege_target_lost'] for c in candidates),
            alternatives=alternatives, selected=copy_data(chosen['artillery']),
            selected_retarget=chosen.get('artillery_variant', False), hard_veto=False,
            scope='conditional own Work and locked/singleton artillery targets; enemy orders, reactions and random acquisitions unknown')
