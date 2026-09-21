"""Pair-first, opposite-lane Consume and uncertain Ravenous meal timing."""
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from ..diagnostics import fingerprint
from ..facts import power
from ..kroni_tactics import consume_targets, consume_value, compatible, ravenous_targets, ravenous_value

LORD = 'Kroni'
CONTROL = ('Consume', 'Ravenous')


def proposals(f):
    for row in consume_targets(f):
        target = dict(entity_id=row['id']); value = consume_value(f, target)
        yield power('Consume', target, value['score'], value['reason'])
    for target in ravenous_targets(f):
        value = ravenous_value(f, target)
        yield power('Ravenous', target, value['score'], value['reason'])


def coordinate(f, plan, ctx):
    for source in plan['powers']:
        name, target = source['power_id'], source['target']
        if name == 'Consume':
            baseline, adjusted = consume_value(f, target), consume_value(f, target, plan)
        elif name == 'Ravenous':
            baseline, adjusted = ravenous_value(f, target), ravenous_value(f, target, ctx, plan)
        else: continue
        yield dict(power=name, score_delta=adjusted['score']-baseline['score'], **adjusted)


def normalize(f, plan, selected, retained):
    """Hard doctrine requirement, including softmax candidates; no rules change.

    Retarget an assembled attack's Consume to the best retained opposite-lane
    Guard, or omit it when that lane is empty. Rebuild declaration IDs afterward.
    """
    shots = [p for p in selected if p.category == 'powers' and p.term == 'Consume']
    if not shots or compatible(f, shots[0].payload['target'], plan): return selected, []
    options = [p for p in retained if p.term == 'Consume' and compatible(f, p.payload['target'], plan)]
    selected = [p for p in selected if p not in shots]
    if options: selected.append(min(options, key=lambda p: (-p.value, fingerprint(p.payload))))
    sources = [p for p in selected if p.category == 'powers']
    plan['powers'] = [declaration(f.pid, f.v['round'], p.term, p.payload['target'], index=i,
                         parameters=p.payload['parameters'], discard_ids=list(p.cards) if p.cards else None) for i,p in enumerate(sources)]
    return selected, ['Consume'] if not options else []


class KroniPlans:
    def __init__(self, f, enabled=True):
        self.f = f
        self.enabled = enabled and f.kind == LORD and f.available('Ravenous')[0]

    def alternatives(self, candidates, retained, budget):
        from ..coordination import context
        if not self.enabled: return
        options = [p for p in retained['powers'] if p.term == 'Ravenous']
        seen = {fingerprint([(p.category, p.term, p.payload) for p in c['selected']]) for c in candidates}; choices = []
        for c in sorted(candidates, key=lambda c: (-c['score'], fingerprint(c['plan']))):
            for ravenous in options:
                if not budget.take('generated', 'kroni'): break
                value = ravenous_value(self.f, ravenous.payload['target'], context(self.f, c['plan']), c['plan'])
                if value['score'] <= 0: continue
                anchors = [p for p in c['selected'] if not(p.category == 'powers' and p.term == 'Ravenous')]+[ravenous]
                identity = fingerprint([(p.category, p.term, p.payload) for p in anchors])
                if identity in seen: continue
                seen.add(identity)
                old = sum(p.value for p in c['selected'] if p.term == 'Ravenous')
                old += sum(r['score_delta'] for r in c['coordination']['powers'] if r['power'] == 'Ravenous')
                choices.append((c['score']-old+value['score'], identity, anchors))
            else: continue
            break
        for _, _, anchors in sorted(choices, key=lambda r: (-r[0], r[1])):
            if not budget.take('retained', 'kroni'): break
            yield anchors

    def report(self, chosen, alternatives):
        return dict(enabled=self.enabled, alternatives=alternatives,
            selected=[copy_data(r) for r in chosen['coordination']['powers'] if r['power'] in CONTROL],
            scope='opposite attack lane required for Consume; pair then value; representative Ravenous angles over both lanes, no seed or promised meals')
