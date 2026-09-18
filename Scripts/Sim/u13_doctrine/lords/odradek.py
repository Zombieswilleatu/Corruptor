"""Odradek: buy material swings with Reconfiguration, not empty spatial casts.

Passives: Interlock is not assumed to trigger. Redirect moves both sides;
Allegiance Shift takes enemies only. Guard changes are delayed one round.
"""
from u13_pysim.power_rules import RULES
from ..facts import LANES, power

LORD = 'Odradek'
RECONFIGURATION = frozenset(('Redirect', 'FalseOrders', 'AllegianceShift', 'Inversion'))
SAVING_GOALS = frozenset(('AllegianceShift', 'Inversion'))


def proposals(f):
    # Every affordable cast retains its material value. Whole-plan opportunity
    # cost, below, compares it with saving; no cheap-power activation veto.
    for lane in LANES:
        target, count = f.cluster(lane, 180, friendly_penalty=0)
        if target:
            yield power('AllegianceShift', target, 25*count, 'take_visible_enemy_cluster')
        target, count = f.cluster(lane, 300)
        other = 'Castle' if lane == 'Lord' else 'Lord'
        if target and count > 0 and f.lane_need(lane) > f.lane_need(other):
            yield power('Redirect', target, 10*count, 'move_pressure_to_stronger_defended_lane')
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


def inside(row, target, radius):
    a, p = row['attributes'], target['field_position']
    return (a['lane'] == target['lane'] and
            (a['x_fp']-p['x_fp'])**2+(a['y_fp']-p['y_fp'])**2 <= radius**2)


def field_after_redirects(f, plan, ctx):
    # Tiny public position projection, not a cloned game or Marching rollout.
    units = [dict(r, attributes=dict(r['attributes'])) for lane in LANES
             for seat in (f.pid, f.enemy) for r in f.units(seat, lane)
             if r['id'] not in ctx['consumed_supplicants']]
    for source in plan['powers']:
        if source['power_id'] != 'Redirect': continue
        for row in units:
            if inside(row, source['target'], 300):
                row['attributes']['lane'] = 'Castle' if row['attributes']['lane'] == 'Lord' else 'Lord'
    return units


def coordinate(f, plan, ctx):
    """Do not buy Guard changes destroyed by our own choices or empty Shifts."""
    units = None
    def pressure(rows):
        return max(0, *(sum(1 if r['owner'] == f.enemy else -1 for r in rows
                            if r['attributes']['lane'] == lane) for lane in LANES))
    # All Redirects precede Shifts. Credit only a reduction in the worst visible
    # lane deficit; moving an intact crowd back and forth is not material gain.
    for source in plan['powers']:
        if source['power_id'] != 'Redirect': continue
        if units is None: units = field_after_redirects(f, dict(powers=[]), ctx)
        target = source['target']
        standalone = sum(1 if r['owner'] == f.enemy else -1 for seat in (f.pid, f.enemy)
                         for r in f.units(seat, target['lane']) if inside(r, target, 300))
        before = pressure(units)
        for row in units:
            if inside(row, target, 300):
                row['attributes']['lane'] = 'Castle' if row['attributes']['lane'] == 'Lord' else 'Lord'
        after = pressure(units)
        benefit = max(0, before-after)
        yield dict(power='Redirect', score_delta=10*(benefit-standalone),
                   pressure_before=before, pressure_after=after,
                   reason='redirect_reduces_peak_lane_pressure' if benefit else 'redirect_only_relocates_pressure')
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
            if units is None: units = field_after_redirects(f, plan, ctx)
            before = sum(inside(r, target, 180) for r in f.units(f.enemy, target['lane']))
            captured = [r for r in units if r['owner'] == f.enemy and inside(r, target, 180)]
            yield dict(power=name, score_delta=25*(len(captured)-before),
                       eligible_after=[r['id'] for r in captured],
                       reason='own_redirect_changes_shift_targets' if len(captured) != before else 'shift_targets_retained')
            for row in captured: row['owner'] = f.pid


class ResourceHorizon:
    """One best existing public opportunity within two further income ticks.

    Options came through the planner's existing proposal budget, including
    resource-shortfall options. Existing power values/costs are unchanged.
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
                for row in units:
                    if row['owner'] == f.enemy and inside(row, source['target'], 180): row['owner'] = f.pid
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
                ids = [r['id'] for r in units if r['owner'] == f.enemy and inside(r, target, 180)]
                value = 25*len(ids)
            net = max(0, value-3*cost)
            score = net*3**(wait+1)//4**(wait+1)
            if score > result['score']:
                result.update(score=score, goal=dict(power=name, target=target, target_ids=ids,
                    income_ticks=wait, cost=cost, net_material_value=net))
        return result

    def report(self, candidates, chosen, omission_count):
        return dict(version='U13_ODRADEK_RESOURCE_HORIZON_V1', enabled=bool(self.options),
                    evaluated_plans=len(candidates) if self.options else 0,
                    saving_plans=sum(c['resource_horizon']['score'] > 0 and c['resource_horizon']['spent'] == 0 for c in candidates),
                    omission_plans=omission_count, selected=chosen['resource_horizon'],
                    scope='current targets after own choices; at most two further active-Lord incomes; future board and survival uncertain',
                    hard_veto=False)
