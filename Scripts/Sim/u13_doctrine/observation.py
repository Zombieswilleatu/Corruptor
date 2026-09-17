"""Trusted projection/legality boundary. Policies never receive a match or seed."""
from copy import copy

from u13_pysim import economy as e
from u13_pysim.copying import copy_data
from u13_pysim.power_match import PowerMatch


def observe(match, seat):
    s, w = match._state, match._state['world']
    d, z = w['data'], w['data']['card_zones']
    rows = w['entities']['entities']
    public = [r for r in rows if (r['kind'] != 'card' or r['attributes'].get('role') == 'guard') and (r['owner']==seat or not r['attributes'].get('hidden',False))]
    # Explicit allowlist: no deck/discard order, opponent hand, sealed orders,
    # simulation seed, event history, RNG or future random outcomes.
    data = {k: d[k] for k in ('neutral_tears', 'breach_lord', 'sigils', 'guard_public_limits',
                              'orias_marks', 'kanifous_prices', 'kanifous_losses')}
    data['veil_breaches'] = d.get('veil_breaches', {})
    data['monsters'] = d.get('monsters', {})
    data['guard_work'] = {k: d['guard_work'][k] for k in ('targets', 'pairs')}
    data['invocation_rounds'] = d['dominion_rites']['invocation_rounds']
    data['vacant_counts'] = d['vacant_throne']['counts']
    def visible(record):
        source = record['declaration']
        return source['player_id'] == seat or source['visibility'] == 'public'
    def project_effect(record):
        projected = {k: record[k] for k in ('effect_id', 'effect_key', 'target', 'stages', 'stage_index',
            'activated_round', 'phase', 'ready_round', 'cooldown_rounds', 'first_blocked_round',
            'persistent_effect_id', 'fire_round', 'fire_hook') if k in record}
        projected['declaration'] = {k: record['declaration'][k] for k in
            ('declaration_id', 'player_id', 'power_id', 'declared_round', 'visibility')}
        return projected
    # These registries contain admitted declarations from prior rounds at the
    # planning boundary. New simultaneous declarations are in submissions only.
    result = dict(player_id=seat, round=match.clock.round, hook=match.clock.hook,
        players=w['players'], board=public, data=data,
        hand=[e.entity(w, key) for key in z['hands'][seat]],
        market=[e.entity(w, key) for key in z['market']],
        cooldowns=[project_effect(r) for r in s['cooldowns']['locks'] if visible(r)],
        persistent=[project_effect(r) for r in s['persistent']['active'] if visible(r)],
        pending=[project_effect(r) for r in s['pending']['pending'] if visible(r)])
    pending = d['game_economy']['stockpile_pending']
    result['stockpile'] = ([e.entity(w, key) for key in pending['card_ids']]
                          if pending and pending['player_id'] == seat else [])
    return copy_data(result)


class Preview:
    """One reusable private admission session; only legality leaves this object.

    The planner gets __call__, not this object or its staged world. No hooks or
    future orders are simulated. PowerMatch's existing combined admission owns
    its temporary payment world, so rejected alternatives cannot reserve funds.
    """
    def __init__(self, match, seat):
        self.seat = seat
        self.shadow = object.__new__(PowerMatch)
        self.shadow.clock = copy(match.clock)
        self.shadow._state = copy_data({k: v for k, v in match._state.items() if k != 'events'})
        self.shadow._state['events'] = dict(rows=[])
        self.shadow._state['submissions'] = [None, None]
        self.shadow._state['combat_orders'] = [{}, {}]
        self.calls = 0

    def __call__(self, plan):
        self.calls += 1
        try:
            self.shadow._submit_one(self.seat, copy_data(plan))
            return dict(action='legal')
        except e.Rejected as error:
            return dict(action='invalid', reason=error.result['reason'],
                        detail=error.result.get('detail', ''))
        finally:
            self.shadow._state['submissions'][self.seat] = None
            self.shadow._state['combat_orders'][self.seat] = {}
