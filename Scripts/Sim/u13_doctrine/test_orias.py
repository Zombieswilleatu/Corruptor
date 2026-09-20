"""Focused Orias decisions and two controlled Marching phases, not balance games."""
import unittest

from u13_pysim import economy, full_match_inputs, power_components, recruitment
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .budget import Limits
from .common import CommonSmartCore
from .coordination import context, evaluate
from .facts import Facts
from .lords.orias import proposals
from .observation import observe, Preview
from .orias_tactics import snare_value, web_targets, web_value
from .test_common import planning
from .test_lane_support import unit
from .test_recipes_veil import hand


def view():
    return observe(planning('Orias'), 0)


def web(x, y=300, lane='Castle'):
    return dict(lane=lane, field_position=dict(x_fp=x, y_fp=y))


def plan(f, order=None, name='Snare', target=None):
    return dict(powers=[declaration(f.pid, f.v['round'], name, target or dict(player_id=f.enemy))],
                order=order or {})


def guard(v, identity, lane='Lord', slot=0, value=2):
    v['board'].append(dict(id=identity, kind='card', owner=1,
        attributes=dict(role='guard', lane=lane, slot=slot, value=value, suit='Butcher')))


def snare(v, order=None):
    f = Facts(v); p = plan(f, order)
    return snare_value(f, p, context(f, p))


class OriasTests(unittest.TestCase):
    def test_web_counts_hits_beyond_six_without_a_flat_tail(self):
        v = view()
        for i in range(6): unit(v, 'dense:'+str(i), 1, x_fp=1600, waiting=True, hp=10, armor=0)
        first = web_value(Facts(v), web(1600))
        unit(v, 'seventh', 1, x_fp=1600, waiting=True, hp=10, armor=0)
        second = web_value(Facts(v), web(1600))
        self.assertGreater(second['score'], first['score'])
        for i in range(13): unit(v, 'extra:'+str(i), 1, x_fp=1600, waiting=True, hp=10, armor=0)
        dense = web_value(Facts(v), web(1600))
        self.assertEqual(20, len(dense['initial_hits']))
        self.assertGreater(dense['score'], second['score'])

    def test_web_dense_group_beats_six_with_maximum_control_credit(self):
        v = view()
        for i in range(20): unit(v, 'dense:'+str(i), 1, x_fp=1800, waiting=True, hp=10, armor=0)
        for i in range(6): unit(v, 'urgent:'+str(i), 1, lane='Lord', x_fp=650, hp=10, armor=0)
        f = Facts(v)
        dense, urgent = web_value(f, web(1800)), web_value(f, web(650, lane='Lord'))
        self.assertGreater(urgent['control_score'], 0)
        self.assertLessEqual(urgent['control_score'], 12)
        self.assertGreater(dense['score'], urgent['score'])

    def test_web_densest_cluster_survives_anchor_search_and_retention(self):
        v = view()
        for lane in ('Lord', 'Castle'):
            for i, x in enumerate((400, 800, 1200)):
                unit(v, lane+'front:'+str(i), 1, lane=lane, x_fp=x, hp=10, armor=0)
            for i in range(20):
                unit(v, lane+'dense:'+str(i), 1, lane=lane, x_fp=2200, waiting=True, hp=10, armor=0)
            f = Facts(v)
            target, count = f.cluster(lane, 270, friendly_penalty=0)
            self.assertEqual(20, count)
            self.assertEqual(target, next(web_targets(f, lane)))
        d = CommonSmartCore().decide(v, lambda p: {'action': 'legal'})
        retained = [p for p in d['retained_candidates'] if p['category'] == 'powers']
        self.assertEqual(2, sum(p['reason'] == 'web_dense_cluster_and_control' for p in retained))
        self.assertLessEqual(len(retained), 4)

    def test_web_prefers_gate_delay_to_a_larger_stationary_group(self):
        v = view(); unit(v, 'approach', 1, lane='Lord', x_fp=650)
        for i in range(4): unit(v, 'idle:'+str(i), 1, x_fp=1000, waiting=True)
        f = Facts(v)
        urgent = web_value(f, web(650, lane='Lord'))
        idle = web_value(f, web(1000))
        self.assertGreater(urgent['score'], idle['score'])
        self.assertGreater(urgent['control_score'], 0)
        self.assertEqual(0, idle['control_score'])

    def test_web_does_not_slow_attacks_or_hurt_friendly_units(self):
        v = view(); unit(v, 'own', x_fp=900)
        unit(v, 'engaged', 1, x_fp=920)
        value = web_value(Facts(v), web(920))
        self.assertEqual(['engaged'], value['initial_hits'])
        self.assertEqual(0, value['control_score'])
        self.assertEqual(0, value['score'])
        v['board'][-1]['attributes'].update(hp=1, armor=0)
        value = web_value(Facts(v), web(920))
        self.assertGreater(value['score'], 0)
        self.assertEqual(['engaged'], value['potential_kills'])

    def test_web_accounts_for_visible_second_round_arrivals(self):
        v = view(); own = unit(v, 'shooter', x_fp=480)
        own['attributes'].update(recruitment.profile('Vulture', 'Castle', 0, 0, 1), x_fp=480)
        for i in range(2): unit(v, 'later:'+str(i), 1, x_fp=1900+30*i, y_fp=280+40*i)
        value = web_value(Facts(v), web(600))
        self.assertEqual([], value['initial_hits'])
        self.assertEqual(2, value['phases'])
        self.assertTrue(all(r['entry_next_round'] for r in value['slowed']))
        self.assertGreater(value['score'], 0)
        candidates = [web_value(Facts(v), t) for t in web_targets(Facts(v), 'Castle')]
        self.assertTrue(any(r['score'] > 0 and not r['initial_hits'] for r in candidates))
        for row in v['board']:
            if row['kind'] == 'marcher' and row['owner'] == 1: row['attributes']['movement_ready_round'] = 2
        self.assertEqual(0, web_value(Facts(v), web(600))['score'])

    def test_web_does_not_promise_free_shots_against_equal_range_vultures(self):
        v = view(); own = unit(v, 'shooter', x_fp=1800)
        own['attributes'].update(suit='Vulture')
        foe = unit(v, 'ranged_enemy', 1, x_fp=2250, suit='Vulture')
        value = web_value(Facts(v), web(2150))
        self.assertEqual(0, value['control_score'])
        foe['attributes']['suit'] = 'Butcher'
        self.assertGreater(web_value(Facts(v), web(2150))['control_score'], 0)

    def test_web_values_ranged_support_and_excludes_spent_supplicants(self):
        v = view(); own = unit(v, 'shooter', x_fp=1800, waiting=True)
        own['attributes'].update(suit='Vulture')
        unit(v, 'closing', 1, x_fp=2000)
        f = Facts(v); target = web(2000)
        self.assertGreater(web_value(f, target)['score'], 0)
        p = plan(f, dict(rites=dict(waiter_spends=[dict(lane='Castle', marcher_ids=['shooter'])])), 'Web', target)
        changed = evaluate(f, p)['powers'][0]
        self.assertEqual(0, changed['score'])
        self.assertLess(changed['score_delta'], 0)

    def test_web_support_includes_recruits_with_birth_movement_hold(self):
        v = view(); hand(v, [('Vulture', 4)])
        unit(v, 'closing', 1, x_fp=600)
        f = Facts(v); p = plan(f, dict(action='Ward', lane='Castle', card_ids=[r['id'] for r in f.hand]), 'Web', web(600))
        value = evaluate(f, p)['powers'][0]
        self.assertEqual(2, value['planned_recruits'])
        self.assertGreater(value['slowed'][0]['ranged_score'], 0)
        p['order']['lane'] = 'Lord'
        value = evaluate(f, p)['powers'][0]
        self.assertEqual(0, value['planned_recruits'])
        self.assertEqual(0, value['slowed'][0]['ranged_score'])

    def test_web_does_not_credit_a_wall_blocked_route_or_a_turret(self):
        v = view(); unit(v, 'enemy', 1, x_fp=650)
        v['data']['field_structures'] = [dict(id='wall', kind='fortification', owner=0,
            attributes=dict(structure='Wall', lane='Castle', x_fp=400, y_fp=300, hp=10))]
        self.assertEqual(0, web_value(Facts(v), web(650))['control_score'])
        v['data']['field_structures'] = []
        v['board'][-1]['attributes'].update(sprite_form='turret', step_fp=0)
        self.assertEqual(0, web_value(Facts(v), web(650))['control_score'])

    def test_web_candidates_include_forward_placement_and_are_bounded(self):
        v = view()
        for i in range(60): unit(v, 'wave:'+str(i), 1, x_fp=1000+20*i, y_fp=50+8*i)
        f = Facts(v); targets = list(web_targets(f, 'Castle'))
        self.assertLessEqual(len(targets), 6)
        self.assertTrue(any(t['field_position']['x_fp'] < 1000 for t in targets))
        self.assertLessEqual(len(list(proposals(f))), 13)

    def test_snare_requires_known_follow_up_cards(self):
        v = view(); hand(v, [])
        value = snare(v)
        self.assertEqual(0, value['benefit'])
        self.assertLess(value['score'], 0)
        hand(v, [('Butcher', 4)]*3)
        self.assertGreater(snare(v)['score'], 0)
        ids = [r['id'] for r in v['hand']]
        value = snare(v, dict(action='Ward', lane='Castle', card_ids=ids))
        self.assertEqual(0, value['benefit'])
        self.assertIsNone(value['follow_up'])

    def test_snare_accounts_for_guard_work_and_combat_card_spending(self):
        v = view(); hand(v, [('Butcher', 4)]*3); ids = [r['id'] for r in v['hand']]
        f = Facts(v)
        order = dict(action='Hunt', lane='Lord', target_id=f.lord[1]['id'], card_ids=[ids[0]],
            guard_moves=[dict(card_id=ids[1], lane='Lord', slot=0)],
            castle_action=dict(action='Repair', card_ids=[ids[2]], target_id=f.castles(0)[0]['id']))
        self.assertEqual(0, snare(v, order)['benefit'])

    def test_snare_does_not_remove_standing_guards_or_add_lanes_together(self):
        v = view(); hand(v, [('Butcher', 4)]*4)
        for lane in ('Lord', 'Castle'):
            for slot in range(2): guard(v, lane+str(slot), lane, slot)
        self.assertEqual(0, snare(v)['benefit'])
        for lane in ('Lord', 'Castle'): guard(v, lane+'2', lane, 2)
        self.assertEqual(0, snare(v)['benefit'])

    def test_snare_can_prepare_either_hunt_or_siege(self):
        for lane, action in [('Lord', 'Hunt'), ('Castle', 'Siege')]:
            with self.subTest(action=action):
                v = view(); hand(v, [('Butcher', 4)]*3)
                other = 'Castle' if lane == 'Lord' else 'Lord'
                for slot in range(2): guard(v, 'other:'+str(slot), other, slot)
                value = snare(v)
                self.assertGreater(value['score'], 0)
                self.assertEqual(action, value['follow_up']['action'])
                self.assertEqual(2, value['effective_round'])
                self.assertEqual([2, 4], [r['new_guard_value'] for r in value['follow_up']['scenarios']])

    def test_snare_uses_own_conditional_guard_clear_only_for_next_round(self):
        v = view(); hand(v, [('Butcher', 4)]*5)
        for lane in ('Lord', 'Castle'):
            for slot in range(3): guard(v, lane+str(slot), lane, slot)
        f = Facts(v); ids = [r['id'] for r in f.hand[:2]]
        order = dict(action='Siege', lane='Castle', card_ids=ids, target_id=f.castles(1)[0]['id'])
        p = plan(f, order); before = copy_data(v)
        without = context(f, dict(powers=[], order=order)); with_snare = context(f, p)
        self.assertEqual(without, with_snare)
        value = snare_value(f, p, with_snare)
        self.assertGreater(value['score'], 0)
        self.assertEqual('Castle', value['follow_up']['lane'])
        self.assertEqual(3, len(value['follow_up']['conditional_guard_losses']))
        self.assertEqual([], value['follow_up']['existing_guards'])
        self.assertFalse(set(ids).intersection(value['follow_up']['card_ids']))
        self.assertEqual(before, v)

    def test_snare_uses_arrivals_before_next_attack_not_next_round_movement(self):
        v = view(); hand(v, [('Butcher', 2)])
        for i in range(5): unit(v, 'arrival:'+str(i), lane='Lord', x_fp=1700, y_fp=180+50*i)
        value = snare(v)
        self.assertGreater(value['score'], 0)
        self.assertEqual(5, len(value['follow_up']['arrivals']))
        for r in v['board']:
            if r['kind'] == 'marcher': r['attributes']['movement_ready_round'] = 2
        self.assertEqual(0, snare(v)['benefit'])
        for r in v['board']:
            if r['kind'] == 'marcher': r['attributes']['movement_ready_round'] = 1
        unit(v, 'interceptor', 1, lane='Lord', x_fp=2000)
        self.assertEqual(0, snare(v)['benefit'])

    def test_snare_prices_immediate_threat_and_conduit_cost(self):
        v = view(); hand(v, [('Butcher', 4)]*4)
        first = snare(v)
        actor = next(r for r in v['board'] if r['kind'] == 'lord' and r['owner'] == 0)
        actor['attributes']['threat'] = 1
        circle = next((r for r in v['board'] if r['owner'] == 0 and r['attributes'].get('castle_type') == 'SummoningCircle'), None)
        if circle:
            circle['attributes'].update(status='standing', integrity=10, construction_state='active')
        else:
            template = copy_data(Facts(v).castles(0)[0]); template['id'] = 'test_circle'
            template['attributes'].update(castle_type='SummoningCircle', integrity=10, status='standing', construction_state='active')
            v['board'].append(template)
        cost = snare(v)['cost']
        self.assertEqual(3, cost['circle_integrity_cost'])
        self.assertEqual(1, cost['threat_after'])
        self.assertGreater(cost['score'], first['cost']['score'])
        v['board'] = [r for r in v['board'] if r['attributes'].get('castle_type') != 'SummoningCircle']
        cost = snare(v)['cost']
        self.assertEqual(1, cost['defense_loss'])
        self.assertEqual(2, cost['threat_after'])

    def test_snare_does_not_extend_current_cap_or_duplicate_pending_cap(self):
        v = view(); hand(v, [('Butcher', 4)]*3)
        v['data']['guard_public_limits'][1] = 1
        value = snare(v)
        self.assertGreater(value['score'], 0)
        self.assertEqual(3, value['follow_up']['scenarios'][0]['normal_new_guards'])
        source = declaration(0, 1, 'Snare', dict(player_id=1))
        v['pending'].append(dict(declaration=source, fire_round=2))
        self.assertEqual('next_round_already_snared', snare(v)['reason'])

    def test_decision_is_legal_bounded_and_ignores_private_information(self):
        game = planning('Orias')
        power_components.prepare(game, [dict(kind='fixture_marcher', player_id=1, lane='Lord', origin='web-threat', ordinal=0,
                                            attributes=dict(x_fp=650, hp=20, max_hp=20))])
        before = game.snapshot(); observed = observe(game, 0)
        policy = CommonSmartCore(); first = policy.decide(observed, Preview(game, 0))
        self.assertEqual(before, game.snapshot())
        self.assertTrue(any(s['power_id'] == 'Web' for s in first['plan']['powers']))
        self.assertEqual('legal', Preview(game, 0)(first['plan'])['action'])
        for key, count in first['budget']['used'].items():
            self.assertLessEqual(count, 16 if key.startswith('generated:') else 4 if key.startswith('retained:') else 32 if key == 'complete_plans' else 8)
        game._state['seed'] = 'private-other-seed'
        game._state['submissions'][1] = [dict(secret='unknown')]
        game._state['world']['data']['card_zones']['deck'].reverse()
        self.assertEqual(observed, observe(game, 0))
        self.assertEqual(first, policy.decide(observe(game, 0), Preview(game, 0)))
        small = CommonSmartCore(limits=Limits(complete_plans=4, previews=2)).decide(observed, Preview(game, 0))
        self.assertLessEqual(small['budget']['used']['complete_plans'], 4)
        self.assertLessEqual(small['budget']['used']['previews'], 2)

    def test_policy_arms_snare_for_an_arriving_hunt_and_holds_without_it(self):
        game = planning('Orias'); w = game._state['world']
        economy.discard(w, 0, list(w['data']['card_zones']['hands'][0]))
        cards, changes = [], []
        for value in (3, 4, 4):
            row = next(r for r in w['entities']['entities'] if r['kind'] == 'card'
                       and r['attributes']['suit'] == 'Butcher' and r['attributes']['value'] == value and r['id'] not in cards)
            cards.append(row['id']); changes.append(dict(kind='fixture_give', player_id=0, card_id=row['id']))
        guards = [r for r in w['entities']['entities'] if r['kind'] == 'card'
                  and r['attributes']['suit'] == 'Wright' and r['attributes']['value'] == 2][:2]
        changes += [dict(kind='fixture_guard', player_id=1, card_id=r['id'], lane='Castle', slot=i) for i, r in enumerate(guards)]
        changes += [dict(kind='fixture_marcher', player_id=0, lane='Lord', origin='arrivals', ordinal=i,
                         attributes=dict(x_fp=1700, y_fp=180+50*i)) for i in range(5)]
        power_components.prepare(game, changes)
        v = observe(game, 0); decision = CommonSmartCore().decide(v, Preview(game, 0))
        self.assertEqual('legal', Preview(game, 0)(decision['plan'])['action'])
        value = next(r for r in decision['orias']['selected'] if r['power'] == 'Snare')
        self.assertEqual('Hunt', value['follow_up']['action'])
        self.assertEqual(1, len(value['follow_up']['card_ids']))
        self.assertEqual(5, len(value['follow_up']['arrivals']))
        power_components.prepare(game, [dict(kind='fixture_retire', entity_id=r['id']) for r in v['board'] if r['kind'] == 'marcher'])
        held = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertNotIn('Snare', [s['power_id'] for s in held['plan']['powers']])

    def test_policy_places_web_for_the_later_wave(self):
        game = planning('Orias')
        # A durable shooter isolates the firing-arc reason. An outmatched
        # shooter can reasonably prefer immediate relief plus activation hits.
        changes = [dict(kind='fixture_marcher', player_id=0, lane='Castle', origin='shooter', ordinal=0,
            attributes=dict(recruitment.profile('Vulture', 'Castle', 0, 0, 1), x_fp=480, hp=100, max_hp=100))]
        changes += [dict(kind='fixture_marcher', player_id=1, lane='Castle', origin='later', ordinal=i,
            attributes=dict(x_fp=1900+30*i, y_fp=280+40*i, hp=30, max_hp=30)) for i in range(2)]
        power_components.prepare(game, changes)
        decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        value = next(r for r in decision['orias']['selected'] if r['power'] == 'Web')
        self.assertEqual([], value['initial_hits'])
        self.assertGreater(value['control_score'], 0)
        self.assertTrue(all(r['entry_next_round'] for r in value['slowed']))
        self.assertEqual('legal', Preview(game, 0)(decision['plan'])['action'])

    def test_authority_web_two_phases_and_snare_next_round_only(self):
        game = planning('Orias')
        power_components.prepare(game, [dict(kind='fixture_marcher', player_id=1, lane='Castle', origin='late-web', ordinal=0,
            attributes=dict(x_fp=1900, y_fp=300, hp=30, max_hp=30, armor=0))])
        sources = [declaration(0, 1, 'Web', web(600)), declaration(0, 1, 'Snare', dict(player_id=1), index=1)]
        def apply(op):
            result = game.apply(op)
            self.assertNotEqual('invalid', result['action'], result)
        apply(dict(kind='submit', plans=[dict(powers=sources, order={}), dict(powers=[], order={})]))
        positions = []
        for number in (1, 2):
            while game.clock.hook != 'marching': apply(full_match_inputs.next_operation(game))
            self.assertEqual(6 if number == 1 else 1, game._state['world']['data']['guard_public_limits'][1])
            self.assertEqual(1, Facts(observe(game, 0)).lord[0]['attributes']['threat'])
            active = next(r for r in game._state['persistent']['active'] if r['declaration']['power_id'] == 'Web')
            self.assertEqual(number-1, active['stage_index'])
            apply(dict(kind='step', hook='marching'))
            enemy = next(r for r in game._state['world']['entities']['entities'] if r['kind'] == 'marcher' and r['owner'] == 1)
            positions.append(enemy['attributes']['x_fp'])
            if number == 1:
                while not game.clock.completed: apply(full_match_inputs.next_operation(game))
                apply(dict(kind='next_round'))
                while game.clock.hook != 'submission_lock': apply(full_match_inputs.next_operation(game))
                apply(dict(kind='submit', plans=[dict(powers=[], order={})]*2))
        self.assertEqual(1100, positions[0])
        self.assertGreater(positions[1], 300)
        hits = [r for r in game._state['events']['rows'] if r['event']['type'] == 'WEB_HIT']
        self.assertEqual([], hits)  # No repeated damage when the late unit enters.
        while not game.clock.completed: apply(full_match_inputs.next_operation(game))
        apply(dict(kind='next_round'))
        while game.clock.hook != 'submission_lock': apply(full_match_inputs.next_operation(game))
        f = Facts(observe(game, 0))
        self.assertIsNone(f.active('Web'))
        self.assertFalse(f.available('Web')[0])  # One cooldown round after expiry.
        self.assertEqual(6, f.v['data']['guard_public_limits'][1])

    def test_inputs_registry_order_and_both_player_seats_are_stable(self):
        v = view(); hand(v, [('Butcher', 4)]*3)
        unit(v, 'enemy', 1, x_fp=650)
        before = copy_data(v); first = snare(v); field = web_value(Facts(v), web(650))
        self.assertEqual(before, v)
        v['board'].reverse(); v['hand'].reverse()
        self.assertEqual(first, snare(v)); self.assertEqual(field, web_value(Facts(v), web(650)))
        other = copy_data(v); other['player_id'] = 1
        other['players'].reverse()
        for r in other['board']+other['hand']:
            if r['owner'] in (0, 1): r['owner'] = 1-r['owner']
            if r['kind'] == 'marcher': r['attributes']['x_fp'] = 2400-r['attributes']['x_fp']
        mirrored = snare(other)
        self.assertEqual(first, mirrored)
        self.assertEqual(field, web_value(Facts(other), web(1750)))


if __name__ == '__main__':
    unittest.main()
