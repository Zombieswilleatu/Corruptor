"""Humbaba: pulse eligible wounded allies and support this plan's lane.

Healing is capped by current missing HP. Later regeneration and movement are
conditional on survival and remaining in the lane, never predicted outcomes.
"""
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from ..diagnostics import fingerprint
from ..facts import LANES, power
from ..lane_support import free_to_advance

LORD = 'Humbaba'
BREATH, MUSTER = 'BreathOfLife', 'MusterTheFaithful'


def breath_value(f, lane, ctx=None):
    excluded = set(ctx['consumed_supplicants']) if ctx else set()
    units = [r for r in f.units(f.pid, lane) if r['id'] not in excluded]
    enemies = f.units(f.enemy, lane); number = f.v['round']
    now = later = windows = waiting = 0
    for row in units:
        a = row['attributes']
        if a['waiting']:
            waiting += 1
            continue
        missing = max(0, a['max_hp']-a['hp'])
        pulse = min(1, missing); now += pulse
        later += min(1, max(0, missing-pulse-a['regen']))
        if free_to_advance(row, enemies):
            windows += int(a['movement_ready_round'] <= number)+int(a['movement_ready_round'] <= number+1)
    # Ordinary recruits are full HP and first move next round. Muster fires
    # earlier than Breath and its three Penitents can move this round as well.
    recruits = ctx['recruits'] if ctx and ctx['recruit_lane'] == lane else 0
    muster = ctx['muster_bodies'].get(lane, 0) if ctx else 0
    windows += recruits+2*muster
    # Monster movement/spawn placement is deliberately not priced here: Varn
    # count, Sooge rooting and other special movement are unresolved.
    return dict(score=4*(now+later)+3*windows, immediate_healing=now,
                next_regen_bonus=later, movement_windows=windows, waiting_excluded=waiting,
                consumed_excluded=len(excluded.intersection(r['id'] for r in f.units(f.pid, lane))),
                ordinary_recruits=recruits, muster_recruits=muster)


def muster_value(f, lane):
    aura = f.active(BREATH)
    windows = max(0, aura['activated_round']+2-f.v['round']) if aura and aura['target']['lane'] == lane else 0
    return 27+6*f.lane_need(lane)+9*windows


def proposals(f):
    for lane in LANES:
        yield power(MUSTER, dict(lane=lane), muster_value(f, lane), 'three_penitents_lane_support')
        value = breath_value(f, lane)
        # Keep zero-value lane targets for bounded own-plan support alternatives.
        yield power(BREATH, dict(lane=lane), value['score'],
                    'pulse_and_mobile_lane_support' if value['score'] else 'hold_breath_without_recipients')


def coordinate(f, plan, ctx):
    for source in plan['powers']:
        if source['power_id'] != BREATH: continue
        lane = source['target']['lane']
        baseline, adjusted = breath_value(f, lane), breath_value(f, lane, ctx)
        yield dict(power=BREATH, lane=lane, reason='own_plan_pulse_and_spawn_support',
                   score_delta=adjusted['score']-baseline['score'], **adjusted)


class SupportPlans:
    """At most 16 generated / four retained alternatives within 32 plans.

    Preserve each source plan's cards, attack, Work, Guards and Rites; consider
    Breath in either legal lane and an available Muster in that same lane.
    """
    def __init__(self, f, enabled=True):
        self.f = f
        self.enabled = enabled and f.kind == LORD and f.available(BREATH)[0]

    def alternatives(self, candidates, retained, budget):
        from ..coordination import context
        if not self.enabled: return
        breaths = [p for p in retained['powers'] if p.term == BREATH]
        musters = {p.payload['target']['lane']: p for p in retained['powers'] if p.term == MUSTER}
        seen = {fingerprint(c['plan']) for c in candidates}; choices = []; exhausted = False
        for candidate in sorted(candidates, key=lambda c: (-c['score'], fingerprint(c['plan']))):
            old = next((p for p in candidate['selected'] if p.term == MUSTER), None)
            for breath in breaths:
                matching = musters.get(breath.payload['target']['lane'])
                options = [old]+([matching] if matching and matching is not old else [])
                for muster in options:
                    if not budget.take('generated', 'support'):
                        exhausted = True; break
                    powers = [p for p in candidate['selected'] if p.category == 'powers' and p.term not in (MUSTER, BREATH)]
                    powers += ([muster] if muster else [])+[breath]
                    plan = copy_data(candidate['plan'])
                    plan['powers'] = [declaration(self.f.pid, self.f.v['round'], p.term,
                        p.payload['target'], index=i, discard_ids=list(p.cards) if p.cards else None,
                        parameters=p.payload['parameters']) for i,p in enumerate(powers)]
                    identity = fingerprint(plan)
                    if identity in seen: continue
                    seen.add(identity)
                    rows = list(coordinate(self.f, plan, context(self.f, plan)))
                    if rows[0]['score'] <= 0: continue
                    anchors = [p for p in candidate['selected'] if p.category != 'powers']+powers
                    score = (candidate['score']-candidate['coordination']['score_delta']
                        -sum(p.value for p in candidate['selected'] if p.category == 'powers')
                        +sum(p.value for p in powers)+sum(r['score_delta'] for r in rows))
                    choices.append((score, identity, anchors))
                if exhausted: break
            if exhausted: break
        for _, _, anchors in sorted(choices, key=lambda x: (-x[0], x[1])):
            if not budget.take('retained', 'support'): break
            yield anchors

    def report(self, chosen, alternatives):
        return dict(enabled=self.enabled, alternatives=alternatives, selected=chosen.get('support_variant', False),
                    scope='own pulse eligibility, capped healing, recruit readiness and paired Muster; future damage and movement uncertain')
