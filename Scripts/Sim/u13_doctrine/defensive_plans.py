"""Bounded public defense scenarios, not predictions of sealed enemy orders.

Three fixed card-strength probes in each lane measure structural exposure.
They are equally weighted stress cases, not estimated attack probabilities.
No hidden hand, simulation RNG, movement, artillery or enemy declaration enters
the calculation. Work and fresh bonds are projected from this own plan only.
"""
from collections import Counter

from u13_pysim import split_ward
from u13_pysim.battle import defense, operational, targetable
from u13_pysim.castle_balance import PENITENT_PAIR_SCREEN, WRIGHT_PAIR_WORK
from u13_pysim.copying import copy_data
from u13_pysim.development import commission_eligible, eligible, intact
from .diagnostics import fingerprint
from .facts import LANES

VERSION = 'U13_DEFENSIVE_PLANS_V1'
CARD_PRESSURES = (9, 15, 21)


def development(f, plan):
    """Known Guard/Work changes on a detached public world, before attacks."""
    world = copy_data(f.world)
    rows = world['entities']['entities']
    by_id = {r['id']: r for r in rows}
    order = plan['order']
    moves = order.get('guard_moves', [])
    for move in moves:
        row = copy_data(f.by_id[move['card_id']])
        row['attributes'].update(role='guard', lane=move['lane'], slot=move['slot'])
        rows.append(row); by_id[row['id']] = row
    amount = len(moves)
    for lane in LANES:
        for suit in ('Penitent', 'Vulture', 'Wright', 'Butcher'):
            fresh = sorted((m for m in moves if m['lane'] == lane and
                by_id[m['card_id']]['attributes']['suit'] == suit), key=lambda m: m['slot'])
            if len(fresh) < 2: continue
            world['data']['guard_work']['pairs'].append(dict(player_id=f.pid, lane=lane,
                suit=suit, ids=[m['card_id'] for m in fresh[:2]], slots=[m['slot'] for m in fresh[:2]],
                round=f.v['round'], active=True))
            if suit == 'Wright': amount += WRIGHT_PAIR_WORK
    choice = order.get('castle_action', {})
    target_id = world['data']['guard_work']['targets'][f.pid]
    activated = []
    if choice.get('action') == 'Activate':
        row = by_id.get(choice['target_id'])
        if commission_eligible(row, f.pid):
            row['attributes']['construction_state'] = 'active'
            activated.append(row['id'])
    elif choice:
        target_id = choice['target_id']
    row = by_id.get(target_id)
    details = dict(target_id=target_id, guard_work=amount, gain=0, building=False,
                   activated=activated, locked=False)
    if eligible(world, f.pid, row):
        a = row['attributes']
        building = a['construction_state'] != 'active' or a['status'] == 'ruined'
        locked = not building and a.get('repair_lock_until_round', 0) >= f.v['round']
        gain = 0 if locked else min(a['max_integrity']-a['integrity'], amount+(3 if building else 0))
        a['integrity'] += gain
        if building:
            a['construction_state'] = 'active' if a['integrity'] >= a['max_integrity'] else 'building'
            if a['construction_state'] == 'active': activated.append(row['id'])
            a.pop('repair_lock_until_round', None)
        if a['integrity'] > 0: a['status'] = 'standing'
        details.update(gain=gain, building=building, locked=locked)
    return world, details


def exposure(f, world, plan, lane, card_pressure):
    rows = world['entities']['entities']
    own = [r for r in rows if r['owner'] == f.pid]
    lord = next(r for r in own if r['kind'] == 'lord')
    if lane == 'Lord' and not lord['attributes']['alive']:
        return dict(castles_lost=0, banished=False)
    castles = sorted((r for r in own if targetable(r)), key=lambda r: (r['attributes']['castle_slot'], r['id']))
    if lane == 'Castle' and not castles:
        return dict(castles_lost=0, banished=False)
    pressure = card_pressure+sum(r['attributes']['waiting'] for r in f.units(f.enemy, lane))
    if lane == 'Lord' and f.lord[f.enemy]['attributes']['alive'] and f.lord[f.enemy]['attributes']['lord_id'] == 'Orias':
        pressure += 1+int(lord['attributes'].get('threat', 0) >= 2)
    order = plan['order']
    if split_ward.enabled(world): order = split_ward.ward(order)
    if order.get('action') == 'Ward':
        screen = f.strength(order.get('card_ids', []), 'Ward')
        off_lane = 0 if split_ward.enabled(world) else screen//2
        pressure = max(0, pressure-(screen if order['lane'] == lane else off_lane))
    for pair in world['data']['guard_work']['pairs']:
        if pair['player_id'] == f.pid and pair['lane'] == lane and pair['suit'] == 'Penitent' and intact(world, pair):
            pressure = max(0, pressure-PENITENT_PAIR_SCREEN)
    if lane == 'Lord' and f.kind == 'Valak' and lord['attributes']['alive']:
        reserved = sum(s.get('parameters', {}).get('spend', 0) for s in plan['powers'] if s['power_id'] == 'Projection')
        pressure = max(0, pressure-max(0, f.resources['life_essence']-reserved))
    guards = sorted((r for r in own if r['kind'] == 'card' and r['attributes']['lane'] == lane),
                    key=lambda r: (-r['attributes']['value'], r['attributes']['slot'], r['id']))
    for guard in guards:
        pressure = max(0, pressure-guard['attributes']['value'])
    sigil = '' if split_ward.enabled(world) else f.v['data']['sigils'][f.pid][lane]
    pressure = max(0, pressure-(2 if sigil == 'fresh' else 1 if sigil else 0))
    losses = 0
    if lane == 'Lord':
        keep = next((r for r in castles if r['attributes']['castle_type'] == 'Keep'), None)
        if keep:
            pressure = max(0, pressure-(3 if operational(keep) else 0))
            losses += pressure > 0 and pressure >= keep['attributes']['integrity']
            pressure = max(0, pressure-keep['attributes']['integrity'])
        # Humbaba's defense depends on surviving targetable infrastructure.
        current_defense = defense(world, lord)-(losses if f.kind == 'Humbaba' else 0)
        return dict(castles_lost=int(losses), banished=pressure > current_defense)
    target = min(castles, key=lambda r: (r['attributes']['integrity'], r['attributes']['castle_slot'], r['id']))
    bastion = next((r for r in castles if r['attributes']['castle_type'] == 'Bastion' and r['id'] != target['id']), None)
    for row in ([bastion] if bastion else [])+[target]:
        losses += pressure > 0 and pressure >= row['attributes']['integrity']
        pressure = max(0, pressure-row['attributes']['integrity'])
    return dict(castles_lost=int(losses), banished=False)


class Defense:
    def __init__(self, f, weights):
        self.f, self.weights = f, weights
        empty = dict(powers=[], order={})
        self.baseline_world, self.baseline_work = development(f, empty)
        self.baseline = self.scenarios(self.baseline_world, empty)

    def scenarios(self, world, plan):
        return [dict(lane=lane, card_pressure=pressure, **exposure(self.f, world, plan, lane, pressure))
                for lane in LANES for pressure in CARD_PRESSURES]

    def evaluate(self, plan, selected, projected):
        # Resummon changes Conduit/Threat before Work. That lifecycle is outside
        # this small model, as are Profane's deliberate structure sacrifice and
        # terminal paid-choice scenarios. Keep their existing scores.
        if 'summon' in plan['order'] or plan['order'].get('action') == 'Profane' or projected['winner'] != -1:
            return dict(enabled=False, score_delta=0, reason='outside_defense_scenario', work=None, scenarios=[])
        world, work = development(self.f, plan)
        scenarios = self.scenarios(world, plan)
        prevented = sum(self.weights.destruction*(a['castles_lost']-b['castles_lost'])+
                        self.weights.banishment*(int(a['banished'])-int(b['banished']))
                        for a,b in zip(self.baseline, scenarios))
        structure_score = prevented//len(scenarios)
        old_work = sum(p.value for p in selected if p.category == 'work')
        # Replace the fixed Work score with actual capped progress.
        # The old 30-point activation value is counted once, including automatic
        # completion. This is utility, not a predicted survival probability.
        work_score = 30*(len(work['activated'])-len(self.baseline_work['activated']))
        work_score += self.weights.damage*(work['gain']-self.baseline_work['gain'])
        return dict(enabled=True, score_delta=structure_score+work_score-old_work,
                    structure_score=structure_score, work_score=work_score, replaced_work_score=old_work,
                    work=work, scenarios=scenarios)


def alternatives(f, candidates, retained):
    """Yield anchors only; each full alternative still reserves a plan slot."""
    ranked = sorted(candidates, key=lambda c: (-c['score'], fingerprint(c['plan'])))
    if not ranked: return
    guarded = next((c for c in ranked if c['plan']['order'].get('guard_moves')), None)
    seeds = [guarded, ranked[0]] if guarded and guarded is not ranked[0] else [ranked[0]]
    seen = {fingerprint(c['plan']) for c in candidates}
    # Repairs first, then other existing Work proposals; no new target search.
    works = sorted(retained['work'], key=lambda p: (
        not (p.term == 'Work' and f.by_id[p.payload['castle_action']['target_id']]['attributes']['construction_state'] == 'active'),
        -p.value, fingerprint(p.payload)))
    options = []
    for candidate in seeds:
        selected = candidate['selected']
        guard = next((p for p in selected if p.category == 'guards'), None)
        if guard:
            for p in retained['guards']:
                if p.cards == guard.cards and p.payload != guard.payload:
                    options.append((candidate, 'guards', p, 'guard_lane'))
        for p in works:
            if p.payload.get('castle_action') != candidate['plan']['order'].get('castle_action'):
                options.append((candidate, 'work', p, 'work_target'))
    for candidate, category, replacement, reason in options:
        plan = copy_data(candidate['plan']); plan['order'].update(replacement.payload)
        identity = fingerprint(plan)
        if identity in seen: continue
        seen.add(identity)
        yield [p for p in candidate['selected'] if p.category != category]+[replacement], reason


def report(candidates, chosen, variants):
    return dict(version=VERSION, card_pressures=list(CARD_PRESSURES),
                scenarios_per_plan=2*len(CARD_PRESSURES), evaluated_plans=sum(c['defense']['enabled'] for c in candidates),
                alternative_plans=dict(sorted(Counter(variants).items())), selected=copy_data(chosen['defense']),
                scope='fixed public stress cases, not enemy-hand estimates; Work before combat; enemy powers, artillery and movement unmodeled',
                hard_veto=False)
