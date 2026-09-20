"""Opt-in Rout delay experiment. Public conditional goals, never a rollout.

Default V12 is unchanged. Fixed coefficients are preregistered for one cohort,
not optimized on its outcomes. Rout cannot prevent this round's resolved attack
or buy artillery that fires before it. Unseen recruits and future enemy repairs,
powers, random acquisitions and spatial combat remain unknown.
"""
from collections import Counter

from u13_pysim.battle import operational, targetable
from .coordination import context
from .lords.deimos import attack_after, rout_value

VERSION = 'U13_ROUT_DELAY_EXPERIMENT_V1'
RESERVE_COST = 24


class RoutDelay:
    def __init__(self, facts, artillery):
        self.f, self.artillery = facts, artillery
        self.pressure = {lane: rout_value(facts, lane) for lane in ('Lord', 'Castle')}

    def future_finishes(self, plan):
        """A next-round ordinary volley plus at most one War Machine shot.

Only surviving public locks/singleton targets, after this own Work, artillery
and attack scenario. No prediction of a future random acquisition. Operational
engines and the living Lord are assumed to survive; those are conditions.
        """
        if not self.artillery.enabled or 'summon' in plan['order']: return []
        after, _, unknown = self.artillery.project(plan)
        if unknown: return []
        hp = {r['id']: r['attributes']['integrity'] for r in after.castles(after.enemy) if targetable(r)}
        order = plan['order']
        if order.get('action') in ('Hunt', 'Siege'):
            excluded = [k for s in order.get('rites', {}).get('waiter_spends', []) for k in s['marcher_ids']]
            for key, damage in attack_after(after, order, excluded)['castle_hits'].items():
                if key in hp: hp[key] -= damage
        hp = {key: value for key, value in hp.items() if value > 0}
        ordinary, locks = Counter(), []
        for row in after.castles(after.pid):
            a = row['attributes']
            if a.get('combat_profile') != 'siege_engine' or not operational(row): continue
            target = a['artillery_target']
            if target not in hp:
                if len(hp) != 1: continue
                target = next(iter(hp))
            ordinary[target] += 2
            locks.append(target)
        # Extra shot goes before ordinary shots. No reacquisition credit after
        # a kill, so this remains conservative even when shots could retarget.
        extra = None
        if locks and after.lord[after.pid]['attributes']['alive']:
            extra = min(set(locks), key=lambda k: (-int(ordinary[k] < hp[k] <= ordinary[k]+2), k))
        return sorted(k for k, damage in ordinary.items() if hp[k] <= damage+2*int(k == extra))

    def evaluate(self, plan, settlement):
        source = next((s for s in plan['powers'] if s['power_id'] == 'Rout'), None)
        if source is None: return None
        lane = source['target']['lane']; pressure = self.pressure[lane]
        threats, gates = len(pressure['threats']), len(pressure['gate_threats'])
        ctx = context(self.f, plan)
        # Newly recruited ordinary units must first reach movement readiness.
        # Only a wave already able to reach our gate earns this recovery credit.
        recruits = ctx['recruits'] if ctx['recruit_lane'] == lane and gates else 0
        recruit_credit = 6*min(3, recruits)
        vulnerable = []
        if gates:
            vulnerable = [r['id'] for r in self.f.castles(self.f.pid) if targetable(r)
                and r['attributes']['integrity'] <= 8
                and (lane == 'Castle' or r['attributes']['castle_type'] == 'Keep')]
        recovery_credit = 12 if vulnerable else 0
        # Require real current pressure before crediting an unrelated race goal.
        finishes = self.future_finishes(plan) if threats >= 2 or gates else []
        finish_credit = 18 if finishes else 0
        # A terminal paid-choice scenario has no later volley/recruitment goal.
        if settlement['winner'] != -1:
            recruit_credit = recovery_credit = finish_credit = 0
            finishes = []
        score = pressure['score']-RESERVE_COST+recruit_credit+recovery_credit+finish_credit
        return dict(power='Rout', lane=lane, version=VERSION, score=score, reason='conditional_delay_goals',
            score_delta=score-pressure['score'], reserve_cost=RESERVE_COST,
            threat_ids=pressure['threats'], gate_threat_ids=pressure['gate_threats'],
            recovery_recruits=recruits, recruit_credit=recruit_credit,
            vulnerable_castles=vulnerable, recovery_credit=recovery_credit,
            next_volley_finish_targets=finishes, finish_credit=finish_credit,
            scope='conditional future gate-support reset, recruit recovery and next artillery volley; no current-attack prevention credit')
