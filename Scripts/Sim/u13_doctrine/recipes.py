"""Public recipe facts, bounded commitments and a soft hand-saving objective.

Recipes count physical subjects, never face values. Scores are untuned policy
preferences, not forecasts of random abilities or future draws. The one-card
horizon and one best retained recipe avoid double-counting overlapping goals.
"""
from u13_pysim import monsters
from .facts import LANES, Proposal


class Recipes:
    def __init__(self, facts, weights):
        self.f, self.weights = facts, weights
        state = facts.v['data'].get('monsters', {})
        self.enabled = state.get('version') == monsters.VERSION
        unlocked = state.get('unlocked', [[], []])[facts.pid]
        # Protected reserves still occupy living-copy slots. Keep them out of
        # battlefield facts: they cannot attack or be targeted before release.
        living_rows = facts.rows + monsters.reserves(facts.world)
        self.status = {}
        for name in monsters.NAMES:
            self.status[name] = ('rules_unavailable' if not self.enabled else
                'recipe_locked' if name not in unlocked else
                'living_copy_limit' if monsters.limited(name) and monsters.living(living_rows, facts.pid, name) else 'available')
        # Conservation cannot justify waiting for a future draw at a currently
        # projected settlement. Enemy orders still prevent a guaranteed result.
        from .veil_judgment import settlement_projection
        self.can_save = settlement_projection(facts, dict(powers=[], order={}))['winner'] == -1

    def ingredients(self, name, cards):
        chosen, missing = [], {}
        for suit, required in monsters.ROSTER[name]['recipe'].items():
            rows = sorted((r for r in cards if r['attributes']['suit'] == suit),
                          key=lambda r: (r['attributes']['value'], r['id']))
            chosen.extend(r['id'] for r in rows[:required])
            if len(rows) < required: missing[suit] = required-len(rows)
        return tuple(chosen), missing

    def value(self, name, lane):
        f, profile = self.f, monsters.ROSTER[name]
        own, enemy = f.units(f.pid, lane), f.units(f.enemy, lane)
        # Varn uses its guaranteed three bodies, not knowledge of the future
        # swarm roll. New bodies still have the ordinary movement hold.
        material = (2*profile['attack']+profile['armor']+profile['hp']+profile['speed']) * (3 if name == 'Varn' else 1)
        support = sum(r['attributes'].get('suit') == 'Vulture' or
                      r['attributes'].get('monster_id') in ('Kopita', 'Fyra', 'Sooge', 'Sinodek') for r in enemy)
        wounded = sum(r['attributes']['hp'] < r['attributes'].get('max_hp', r['attributes']['hp']) for r in own)
        bonus = dict(Lemek=0, Varn=0, Fyra=4, Kopita=2*min(4, wounded),
                     Tumler=3*min(3, support), Kurchin=2*min(4, len(own)),
                     Muno=6, Dotra=4, Sooge=10, Sinodek=8)[name]
        # Friendly-fire abilities compete with safer recipes on crowded lanes.
        if name in ('Sooge', 'Sinodek'):
            bonus += 2*min(4, len(enemy))-3*min(5, len(own))
        return self.weights.monster*max(0, material+bonus)

    def goal(self, cards, reserved_monster=''):
        if not self.can_save:
            return dict(monster='', score=0, card_ids=[], missing={}, reason='settlement_risk_no_saving_horizon')
        goals = []
        for name in monsters.NAMES:
            if self.status[name] != 'available': continue
            if name == reserved_monster and monsters.limited(name): continue
            ids, missing = self.ingredients(name, cards)
            gap = sum(missing.values())
            if gap > 1: continue
            value = max(self.value(name, lane) for lane in LANES)
            score = self.weights.recipe_save*value//(2 if gap == 0 else 3)
            if score:
                goals.append(dict(monster=name, score=score, card_ids=list(ids), missing=missing,
                                  reason='ready_recipe' if gap == 0 else 'save_one_missing_subject'))
        return min(goals, key=lambda g: (-g['score'], sum(g['missing'].values()), g['monster'])) if goals else dict(
            monster='', score=0, card_ids=[], missing={}, reason='no_near_recipe')

    def attach(self, proposal):
        """Choose a recipe before scoring/admission, within this combat candidate."""
        if proposal.term not in ('Hunt', 'Siege', 'Ward') or 'monster_choice' in proposal.payload: return
        names = [name for name in monsters.NAMES if self.status[name] == 'available'
                 and not self.ingredients(name, [self.f.by_id[k] for k in proposal.cards])[1]]
        if not names: return
        lane = proposal.payload['lane']
        name = min(names, key=lambda n: (-self.value(n, lane), n))
        value = self.value(name, lane)
        if value <= 0: return
        proposal.payload['monster_choice'] = name
        proposal.value += value
        proposal.reason += '_with_recipe'

    def proposals(self):
        """At most one minimal Ward commitment per recipe; no subset search.

        Ordinary Hunt/Siege/Ward proposals also choose their best eligible
        monster. This extra source exposes cheap exact ingredients that a
        strength-sorted attack prefix can miss. Each yielded plan consumes a
        monster-category reservation, and shares the combat/card ledger.
        """
        f, weights = self.f, self.weights
        for name in monsters.NAMES:
            if self.status[name] != 'available': continue
            ids, missing = self.ingredients(name, f.hand)
            if missing: continue
            lane = min(LANES, key=lambda lane: (-(self.value(name, lane)+4*f.lane_need(lane)), lane))
            value = weights.recruit*f.recruits(ids, 'Ward')+min(f.strength(ids, 'Ward'), 5+5*f.lane_need(lane))*2
            if f.kind == 'Kroni': value -= 12
            yield Proposal('combat', 'Ward', dict(action='Ward', lane=lane, card_ids=list(ids), monster_choice=name),
                           value+self.value(name, lane), 'commit_exact_recipe_with_normal_recruits', ids)

    def assessments(self, generated, retained, chosen, exhausted):
        selected = chosen['order'].get('monster_choice', '')
        for name in monsters.NAMES:
            count = sum(p.payload.get('monster_choice') == name for p in generated)
            kept = sum(p.payload.get('monster_choice') == name for p in retained)
            _, missing = self.ingredients(name, self.f.hand)
            ready = self.status[name] == 'available' and not missing
            reason = ('selected' if name == selected else self.status[name] if self.status[name] != 'available' else
                      'missing_subjects' if missing else 'scoring_or_shared_cards' if kept else
                      'retention_budget' if count else 'generation_budget_unmeasured' if not exhausted else 'no_positive_recipe_value')
            yield dict(category='monsters', term=name, opportunity=bool(ready),
                       legal=True if name == selected else None, affordable=True if name == selected else None,
                       generated=count if exhausted or count else None, retained=kept,
                       selected=name == selected, reason=reason)
