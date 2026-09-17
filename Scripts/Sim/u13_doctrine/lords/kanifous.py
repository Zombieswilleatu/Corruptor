"""Kanifous: one useful Wish with an explicit outstanding-Price penalty.

Timing: resurrection sees losses so far; future combat losses are uncertain.
Resources: delayed random Prices are liabilities, never free upside. No seed
or future Price result enters this policy. Common assembly enforces one Wish.
"""
from u13_pysim.battle import targetable
from u13_pysim.power_rules import LONGEVITY_INTEGRITY
from ..facts import LANES, power

LORD = 'Kanifous'


def proposals(f):
    debt = sum(r['owner'] == f.pid for r in f.v['data']['kanifous_prices'])
    price = 14+10*debt
    for row in sorted(f.castles(f.pid), key=lambda r: (r['attributes']['integrity'], r['id'])):
        missing = min(LONGEVITY_INTEGRITY,row['attributes']['max_integrity'])-row['attributes']['integrity']
        if targetable(row) and missing > 0:
            yield power('WishLongevity', dict(entity_id=row['id']), 5*missing-price, 'repair_benefit_less_delayed_price')
    for lane in LANES:
        target, net = f.cluster(lane, 100)
        if target and net > 0:
            yield power('WishDeath', target, 22*net-price, 'death_net_victims_less_delayed_price')
        losses = [r for r in f.v['data']['kanifous_losses'] if r['kind'] == 'marcher' and r['owner'] == f.pid and r['attributes']['lane'] == lane]
        if losses:
            yield power('WishResurrection', dict(lane=lane),
                        18*len(losses)-price, 'restore_recorded_losses_less_price')
        elif f.units(f.pid, lane) and f.units(f.enemy, lane):
            # Public health estimates exposure; future combat is still unknown.
            exposed = [r for r in f.units(f.pid, lane) if r['attributes']['hp'] <= 3]
            if exposed:
                yield power('WishResurrection', dict(lane=lane),
                            18*len(exposed)-price, 'insure_exposed_marchers_future_losses_uncertain')
        yield power('WishPower', dict(lane=lane), 18+8*f.lane_need(lane)-price, 'recruitment_need_less_delayed_price')
    if len(f.hand) <= 5:
        yield power('WishWealth', {}, 25+3*(5-len(f.hand))-price, 'refill_available_hand_space_less_price')
