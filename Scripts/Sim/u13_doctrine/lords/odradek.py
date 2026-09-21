"""Odradek: buy material swings with Reconfiguration, not empty spatial casts.

Passives: Interlock is not assumed to trigger. Redirect moves both sides;
Allegiance Shift takes enemies only. Guard changes are delayed one round.
"""
from u13_pysim.power_rules import RULES
from ..facts import LANES, power
from ..odradek_tactics import inside, field, redirect, capture, redirect_value, shift_value, targets

LORD = 'Odradek'
RECONFIGURATION = frozenset(('Redirect', 'FalseOrders', 'AllegianceShift', 'Inversion'))
SAVING_GOALS = frozenset(('AllegianceShift', 'Inversion'))


def proposals(f):
    # Every affordable cast retains its material value. Whole-plan opportunity
    # cost, below, compares it with saving; no cheap-power activation veto.
    for lane in LANES:
        for name in ('AllegianceShift','Redirect'):
            for target,value in targets(f,lane,name):
                if value['score']>0 or name=='Redirect': yield power(name,target,value['score'],value['reason'])
        other = 'Castle' if lane == 'Lord' else 'Lord'
        guards = sorted(f.guards(f.enemy, lane), key=lambda r: (-r['attributes']['value'], r['id']))
        if guards and f.free(f.pid, lane):
            count = min(len(guards), len(f.free(f.pid, lane)))
            yield power('Inversion', dict(owner_id=f.enemy, lane=lane), 20*count, 'delayed_guard_ownership_plus_neutral_tear')
        if guards and f.free(f.enemy, other) and len(guards) > len(f.guards(f.enemy, other)):
            yield power('FalseOrders', dict(entity_id=guards[0]['id'], owner_id=f.enemy, lane=other),
                        8+2*guards[0]['attributes']['value'], 'open_guarded_lane_next_round')


def guard_opportunity(f, plan, ctx, lane, future=False):
    """Conditional survivors and room after our attack and Guard deployments."""
    lost = set(ctx['guard_losses'])
    survivors = []
    moves = {s['target']['entity_id']: s['target']['lane'] for s in plan['powers']
             if future and s['power_id'] == 'FalseOrders'}
    for origin in LANES:
        for row in f.guards(f.enemy, origin):
            if row['id'] not in lost and moves.get(row['id'], origin) == lane:
                survivors.append(row)
    occupied = {r['attributes']['slot'] for r in f.guards(f.pid, lane)}
    occupied.update(m['slot'] for m in plan['order'].get('guard_moves', []) if m['lane'] == lane)
    return sorted(survivors, key=lambda r: r['id'])[:max(0, 3-len(occupied))]


def field_after_redirects(f, plan, ctx):
    units=field(f,ctx)
    for source in plan['powers']:
        if source['power_id']=='Redirect':redirect(units,source['target'])
    return units


def coordinate(f, plan, ctx):
    """Do not buy Guard changes destroyed by our own choices or empty Shifts."""
    units=field(f,ctx)
    # Position hooks precede allegiance hooks regardless of declaration order.
    for source in plan['powers']:
        if source['power_id']!='Redirect':continue
        target=source['target'];baseline=redirect_value(f,target);adjusted=redirect_value(f,target,units)
        yield dict(power='Redirect',score_delta=adjusted['score']-baseline['score'],**adjusted)
        redirect(units,target)
    for source in plan['powers']:
        name, target = source['power_id'], source['target']
        if name == 'Inversion':
            before = min(len(f.guards(f.enemy, target['lane'])), len(f.free(f.pid, target['lane'])))
            ids = [r['id'] for r in guard_opportunity(f, plan, ctx, target['lane'])]
            yield dict(power=name, score_delta=20*(len(ids)-before), eligible_after=ids,
                       reason='own_plan_changes_inversion_capacity' if len(ids) != before else 'inversion_room_retained')
        elif name == 'FalseOrders':
            victim = f.by_id[target['entity_id']]
            lost = victim['id'] in ctx['guard_losses']
            yield dict(power=name, score_delta=-(8+2*victim['attributes']['value']) if lost else 0,
                       reason='attack_removes_false_orders_target' if lost else 'false_orders_target_retained')
        elif name == 'AllegianceShift':
            baseline=shift_value(f,target);adjusted=shift_value(f,target,units)
            yield dict(power=name,score_delta=adjusted['score']-baseline['score'],**adjusted)
            capture(f,units,target)



class ResourceHorizon:
    """One best existing public opportunity within two further income ticks.

    Options came through the planner's existing proposal budget, including
    resource-shortfall options. Immediate and saved casts share target values; costs are unchanged.
    Discount net value by 3/4 once for uncertainty, then once per missing point.
    This is a bounded preference, not a probability or a promised future cast.
    """
    def __init__(self, f, options):
        self.f = f
        self.options = options if f.kind == LORD and f.lord[f.pid]['attributes']['alive'] else []

    def evaluate(self, plan, ctx, projected):
        f = self.f
        spend = sum(RULES[s['power_id']]['cost'].get('reconfiguration', 0) for s in plan['powers'])
        remaining = f.resources['reconfiguration']-spend
        result = dict(spent=spend, remaining=remaining, score=0, goal=None)
        if not self.options or projected['winner'] != -1: return result
        units = field_after_redirects(f, plan, ctx)
        # Already captured enemies cannot be credited again as a future goal.
        for source in plan['powers']:
            if source['power_id'] == 'AllegianceShift':
                capture(f,units,source['target'])
        for option in self.options:
            name, target = option['power'], option['target']
            ready, reason = f.available(name)
            if not ready and reason != 'resource_shortfall': continue
            cost = RULES[name]['cost']['reconfiguration']
            wait = max(0, cost-remaining)
            if wait > 2: continue
            if name == 'Inversion':
                ids = [r['id'] for r in guard_opportunity(f, plan, ctx, target['lane'], future=True)]
                value = 20*len(ids)
            else:
                shifted=shift_value(f,target,units)
                ids=shifted['eligible_after'];value=shifted['score']
            net = max(0, value-3*cost)
            score = net*3**(wait+1)//4**(wait+1)
            if score > result['score']:
                result.update(score=score, goal=dict(power=name, target=target, target_ids=ids,
                    income_ticks=wait, cost=cost, net_material_value=net))
        return result

    def report(self, candidates, chosen, omission_count):
        return dict(version='U13_ODRADEK_RESOURCE_HORIZON_V2_FIELD_VALUE', enabled=bool(self.options),
                    evaluated_plans=len(candidates) if self.options else 0,
                    saving_plans=sum(c['resource_horizon']['score'] > 0 and c['resource_horizon']['spent'] == 0 for c in candidates),
                    omission_plans=omission_count, selected=chosen['resource_horizon'],
                    scope='current targets after own choices; at most two further active-Lord incomes; future board and survival uncertain',
                    hard_veto=False)
