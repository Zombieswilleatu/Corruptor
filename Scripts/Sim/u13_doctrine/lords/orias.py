"""Orias: useful two-phase Web control and Snare before a supported follow-up.

Shared Hunt estimates include Pursuit. Snare never removes deployed Guards or
improves this round's attack; its cost is paid before its next-round cap.
"""
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from ..diagnostics import fingerprint
from ..facts import LANES, power
from ..orias_tactics import snare_value, web_targets, web_value

LORD = 'Orias'
CONTROL = ('Web', 'Snare')


def proposals(f):
    from ..coordination import context
    plan = dict(powers=[], order={})
    value = snare_value(f, plan, context(f, plan))
    yield power('Snare', dict(player_id=f.enemy), value['score'], value['reason'])
    for lane in LANES:
        for target in web_targets(f, lane):
            value = web_value(f, target)
            yield power('Web', target, value['score'], 'two_phase_damage_and_useful_delay')


def coordinate(f, plan, ctx):
    from ..coordination import context
    empty = dict(powers=[], order={})
    for source in plan['powers']:
        name = source['power_id']
        if name == 'Web':
            baseline = web_value(f, source['target'])
            adjusted = web_value(f, source['target'], ctx)
            yield dict(power=name, lane=source['target']['lane'], reason='two_phase_damage_and_useful_delay',
                       score_delta=adjusted['score']-baseline['score'], **adjusted)
        elif name == 'Snare':
            baseline = snare_value(f, empty, context(f, empty))
            adjusted = snare_value(f, plan, ctx)
            yield dict(power=name, score_delta=adjusted['score']-baseline['score'], **adjusted)


class OriasPlans:
    """Reconsider retained powers with own recruitment and card commitments."""
    def __init__(self, f, enabled=True):
        self.f = f
        self.enabled = enabled and f.kind == LORD and any(f.available(p)[0] for p in CONTROL)

    def alternatives(self, candidates, retained, budget):
        from ..coordination import context
        if not self.enabled: return
        options = [p for p in retained['powers'] if p.term in CONTROL]
        seen = {fingerprint(c['plan']) for c in candidates}; choices = []
        for candidate in sorted(candidates, key=lambda c: (-c['score'], fingerprint(c['plan']))):
            plan = copy_data(candidate['plan']); ctx = context(self.f, plan)
            best = {}
            for p in options:
                if not budget.take('generated', 'orias'): break
                value = (web_value(self.f, p.payload['target'], ctx) if p.term == 'Web'
                         else snare_value(self.f, plan, ctx))['score']
                if value > 0 and (p.term not in best or value > best[p.term][0]):
                    best[p.term] = value, p
            else:
                powers = [p for p in candidate['selected'] if p.category == 'powers' and p.term not in CONTROL]
                powers += [best[name][1] for name in CONTROL if name in best]
                plan['powers'] = [declaration(self.f.pid, self.f.v['round'], p.term, p.payload['target'],
                    index=i, parameters=p.payload['parameters']) for i, p in enumerate(powers)]
                identity = fingerprint(plan)
                if identity in seen: continue
                seen.add(identity)
                old = sum(p.value for p in candidate['selected'] if p.category == 'powers' and p.term in CONTROL)
                old += sum(r['score_delta'] for r in candidate['coordination']['powers'] if r['power'] in CONTROL)
                anchors = [p for p in candidate['selected'] if p.category != 'powers']+powers
                choices.append((candidate['score']-old+sum(v[0] for v in best.values()), identity, anchors))
                continue
            break
        for _, _, anchors in sorted(choices, key=lambda row: (-row[0], row[1])):
            if not budget.take('retained', 'orias'): break
            yield anchors

    def report(self, chosen, alternatives):
        return dict(enabled=self.enabled, alternatives=alternatives,
            selected=[copy_data(r) for r in chosen['coordination']['powers'] if r['power'] in CONTROL],
            scope='two-phase nominal Web travel; next-round Snare attack from retained cards and public arrivals; enemy orders and survival unknown')
