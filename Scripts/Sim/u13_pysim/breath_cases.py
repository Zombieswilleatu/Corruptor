"""Directed Breath pulse inputs with independent gameplay assertions.

Fixtures are explicit operations. Neither engine receives expected states.
"""
from . import economy as e, full_match_inputs, paid_inputs, power_components
from .copying import copy_data
from .power_match import PowerMatch
from .power_rules import declaration
from .primitives import entity_id

SCHEMA = 'U13_BREATH_PULSE_CASES_V1'
NAMES = ('pulse_seat0', 'pulse_seat1', 'lane_reentry', 'armed_banishment')


def generate(names=NAMES):
    cases = []
    for name in names:
        pid = int(name == 'pulse_seat1')
        lords = ['Gremory', 'Gremory']; lords[pid] = 'Humbaba'
        setup = paid_inputs.setup('breath-pulse:'+name, lords)
        game = PowerMatch(setup); operations = []

        def record(op, rejected=False):
            before = game.snapshot() if rejected else None
            result = power_components.apply(game, op)
            assert (result['action'] == 'invalid') == rejected, (name, op, result)
            if rejected: assert game.snapshot() == before
            operations.append(dict(operation=copy_data(op), rejected=rejected))

        def until(hook, number):
            while (game.clock.hook, game.clock.round) != (hook, number):
                if game.clock.hook == 'submission_lock' and game._state['submissions'] == [None, None]:
                    op = dict(kind='submit', plans=[dict(powers=[], order={}) for _ in (0, 1)])
                else: op = full_match_inputs.next_operation(game)
                record(op)

        def patch(key, **attributes):
            record(dict(kind='fixture_prepare', refresh=game.clock.hook == 'submission_lock',
                        changes=[dict(kind='fixture_patch', entity_id=key, attributes=attributes)]))

        def hp(key): return e.entity(game._state['world'], key)['attributes']['hp']

        until('submission_lock', 1)
        origin = 'breath-pulse:'+name
        identities = [entity_id('marcher', origin, i) for i in range(7)]
        # Immobile fixtures isolate healing from encounters. Readiness and
        # hidden state do not exclude an otherwise eligible living ally.
        attrs = [dict(hp=1), dict(hp=4), dict(hp=5), dict(hp=1, waiting=True, waiting_since_round=1),
                 dict(hp=1), dict(hp=1), dict(hp=1, hidden=True, movement_ready_round=2)]
        changes = [dict(kind='fixture_marcher', player_id=1-pid if i == 5 else pid,
                        lane='Castle' if i == 4 else 'Lord', origin=origin, ordinal=i,
                        attributes=dict(step_fp=0, x_fp=120+2160*(1-pid if i == 5 else pid),
                                        y_fp=90+60*i, armor=3, **a)) for i, a in enumerate(attrs)]
        record(dict(kind='fixture_prepare', changes=changes))
        plans = [dict(powers=[], order={}) for _ in (0, 1)]
        plans[pid]['powers'] = [declaration(pid, 1, 'MusterTheFaithful', dict(lane='Lord')),
                               declaration(pid, 1, 'BreathOfLife', dict(lane='Lord'), index=1)]
        record(dict(kind='submit', plans=plans))
        until('post_resolution_movement_state', 1)
        if name == 'armed_banishment':
            patch(game._state['world']['players'][pid]['lord_entity_id'], alive=False)
        assert [hp(k) for k in identities] == [1,4,5,1,1,1,1]
        regen_round = game._state['world']['data']['marching_regen_round']
        record(dict(kind='step', hook='post_resolution_movement_state'))
        assert [hp(k) for k in identities] == [2,5,5,1,1,1,2]
        assert all(e.entity(game._state['world'], k)['attributes']['armor'] == 3 for k in identities)
        assert game._state['world']['data']['marching_regen_round'] == regen_round
        pulses = [r['event']['data'] for r in game._state['events']['rows'] if r['event']['type']=='BREATH_PULSED']
        assert len(pulses) == 1 and pulses[0]['healing'] == 3
        assert pulses[0]['healed_ids'] == [identities[i] for i in (0,1,6)]
        active = game._state['persistent']['active'][0]
        assert active['payload'] == dict(lane_aura=dict(regen_bonus=1, speed_percent=25))
        assert len(active['stages']) == 2 and active['activated_round'] == 1
        # A second attempt to execute the firing hook cannot pulse twice.
        record(dict(kind='step', hook='post_resolution_movement_state'), True)
        if name == 'lane_reentry':
            patch(identities[0], lane='Castle', hp=1)
            patch(identities[4], lane='Lord', hp=1)
        until('present_public_state', 2)
        assert hp(identities[0]) == (2 if name=='lane_reentry' else 4)
        assert hp(identities[4]) == (3 if name=='lane_reentry' else 2)
        assert hp(identities[3]) == 1  # Supplicants retain normal regeneration eligibility.
        assert hp(identities[5]) == 2
        assert sum(r['event']['type']=='BREATH_PULSED' for r in game._state['events']['rows']) == 1
        until('submission_lock', 3)
        assert not game._state['persistent']['active']
        clock = next(c for c in game._state['cooldowns']['locks'] if c['declaration']['power_id']=='BreathOfLife')
        assert (clock['first_blocked_round'], clock['ready_round']) == (3,5)
        blocked = [dict(powers=[],order={}) for _ in (0,1)]
        blocked[pid]['powers'] = [declaration(pid,3,'BreathOfLife',dict(lane='Lord'))]
        record(dict(kind='submit',plans=blocked),True)
        until('submission_lock', 5)
        assert not any(c['declaration']['power_id']=='BreathOfLife' for c in game._state['cooldowns']['locks'])
        if name != 'armed_banishment':
            # Damage after the original pulse receives no extra activation
            # healing until a genuinely new declaration fires.
            patch(identities[0], hp=1, lane='Lord')
            ready = [dict(powers=[],order={}) for _ in (0,1)]
            ready[pid]['powers'] = [declaration(pid,5,'BreathOfLife',dict(lane='Lord'))]
            record(dict(kind='submit',plans=ready))
            until('post_resolution_movement_state',5)
            record(dict(kind='step',hook='post_resolution_movement_state'))
            assert hp(identities[0]) == 2
            assert sum(r['event']['type']=='BREATH_PULSED' for r in game._state['events']['rows']) == 2
        cases.append(dict(name=name,setup=setup,operations=operations))
    return dict(schema=SCHEMA,cases=cases)
