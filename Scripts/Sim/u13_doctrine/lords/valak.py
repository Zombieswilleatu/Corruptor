"""Valak uses a two-round gravity well and paid post-combat Projection."""
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from ..diagnostics import fingerprint
from ..facts import LANES, power
from ..valak_tactics import orb_targets, orb_value, projection_value

LORD = 'Valak'
CONTROL = ('GravityOrb', 'Projection')


def proposals(f):
    essence = f.resources['life_essence']
    # Four Projection choices and at most twelve Orb positions fit the shared
    # sixteen-proposal limit. Different friendly spend is not a free sacrifice.
    for lane in LANES:
        for owner in (f.enemy, f.pid):
            values = [r['attributes']['value'] for r in f.guards(owner, lane) if r['attributes']['value'] <= essence]
            if not values: continue
            spend = min(values) if owner == f.pid else max(values)
            target = dict(kind='guard_zone', zone=lane, player_id=owner)
            value = projection_value(f, target, spend)
            yield power('Projection', target, value['score'], value['reason'], spend=spend)
    for lane in LANES:
        for target in orb_targets(f, lane):
            value = orb_value(f, target)
            yield power('GravityOrb', target, value['score'], value['reason'])


def coordinate(f, plan, ctx):
    for source in plan['powers']:
        name, target = source['power_id'], source['target']
        if name == 'GravityOrb':
            baseline, adjusted = orb_value(f, target), orb_value(f, target, ctx)
        elif name == 'Projection':
            spend = source['parameters']['spend']
            baseline = projection_value(f, target, spend)
            adjusted = projection_value(f, target, spend, plan, ctx)
        else: continue
        yield dict(power=name, score_delta=adjusted['score']-baseline['score'], **adjusted)


class ValakPlans:
    """Compare retained placements with own recruits and retained attack cards."""
    def __init__(self, f, enabled=True):
        self.f = f
        self.enabled = enabled and f.kind == LORD and any(f.available(p)[0] for p in CONTROL)

    def alternatives(self, candidates, retained, budget):
        from ..coordination import context
        if not self.enabled: return
        options = [p for p in retained['powers'] if p.term in CONTROL]
        seen = {fingerprint(c['plan']) for c in candidates}; choices = []
        for candidate in sorted(candidates, key=lambda c: (-c['score'], fingerprint(c['plan']))):
            plan = copy_data(candidate['plan']); ctx = context(self.f, plan); best = {}
            for p in options:
                if not budget.take('generated', 'valak'): break
                value = (orb_value(self.f, p.payload['target'], ctx) if p.term == 'GravityOrb' else
                    projection_value(self.f, p.payload['target'], p.payload['parameters']['spend'], plan, ctx))['score']
                if value > 0 and (p.term not in best or value > best[p.term][0]): best[p.term] = value, p
            else:
                powers = [p for p in candidate['selected'] if p.category == 'powers' and p.term not in CONTROL]
                powers += [best[name][1] for name in CONTROL if name in best]
                plan['powers'] = [declaration(self.f.pid, self.f.v['round'], p.term, p.payload['target'], index=i,
                                             parameters=p.payload['parameters']) for i, p in enumerate(powers)]
                identity = fingerprint(plan)
                if identity in seen: continue
                seen.add(identity)
                old = sum(p.value for p in candidate['selected'] if p.category == 'powers' and p.term in CONTROL)
                old += sum(r['score_delta'] for r in candidate['coordination']['powers'] if r['power'] in CONTROL)
                anchors = [p for p in candidate['selected'] if p.category != 'powers']+powers
                choices.append((candidate['score']-old+sum(v[0] for v in best.values()), identity, anchors))
                continue
            break
        for _, _, anchors in sorted(choices, key=lambda r: (-r[0], r[1])):
            if not budget.take('retained', 'valak'): break
            yield anchors

    def report(self, chosen, alternatives):
        return dict(enabled=self.enabled, alternatives=alternatives,
            selected=[copy_data(r) for r in chosen['coordination']['powers'] if r['power'] in CONTROL],
            scope='two-round nominal pull and exposure; post-combat Projection with retained-card follow-up; enemy orders, survival and future draws unknown')
