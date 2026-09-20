"""Focused Rout decisions and short combat probes; no balance matches."""
import unittest
from u13_pysim import marching, marching_fixtures, monsters, power_components, recruitment
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .budget import Limits
from .common import CommonSmartCore
from .coordination import context, evaluate
from .facts import Facts
from .observation import observe, Preview
from .rout_tactics import _window, rout_value
from .test_common import planning
from .test_lane_support import unit
from .test_recipes_veil import hand


def view():
    return observe(planning('Deimos'), 0)


def recruit_plan(f, suit='Vulture', lane='Castle'):
    ids = [r['id'] for r in f.hand if r['attributes']['suit'] == suit]
    return dict(powers=[declaration(f.pid, f.v['round'], 'Rout', dict(lane='Castle'))],
                order=dict(action='Ward', lane=lane, card_ids=ids))


class RoutTacticsTests(unittest.TestCase):
    def test_equal_speed_chase_is_not_a_punish_window(self):
        v = view(); ally = unit(v, 'own', x_fp=900)
        enemy = unit(v, 'enemy', 1, x_fp=1600)
        f = Facts(v)
        self.assertEqual(0, _window(ally, enemy, 1, f.world)['hits'])
        self.assertEqual(0, rout_value(f, 'Castle')['score'])
        enemy['attributes']['x_fp'] = 960
        self.assertEqual(1, _window(ally, enemy, 1, f.world)['hits'])
        self.assertEqual(0, rout_value(Facts(v), 'Castle')['offense_score'])

    def test_faster_pursuer_gets_one_intercept_not_six_free_swings(self):
        v = view(); ally = unit(v, 'own', x_fp=900, step_fp=8)
        enemy = unit(v, 'enemy', 1, x_fp=1200)
        window = _window(ally, enemy, 1, Facts(v).world)
        self.assertEqual(1, window['hits']); self.assertGreater(window['first_tick'], 0)
        ally['attributes']['movement_ready_round'] = 2
        self.assertEqual(0, _window(ally, enemy, 1, Facts(v).world)['hits'])

    def test_full_retreat_speed_and_cooldown_limit_ranged_coverage(self):
        v = view(); ally = unit(v, 'own', x_fp=900)
        ally['attributes'].update(recruitment.profile('Vulture', 'Castle', 0, 0, 1), x_fp=900)
        enemy = unit(v, 'enemy', 1, x_fp=1050)
        f = Facts(v)
        self.assertEqual(2, _window(ally, enemy, 1, f.world)['hits'])
        ally['attributes']['ranged_next_tick'] = 300
        self.assertEqual(0, _window(ally, enemy, 1, f.world)['hits'])
        ally['attributes']['ranged_next_tick'] = 400
        self.assertEqual(0, _window(ally, enemy, 1, f.world)['hits'])

    def test_enemy_fleeing_toward_a_flanking_unit_still_has_to_close_distance(self):
        v = view(); ally = unit(v, 'own', x_fp=1700, step_fp=8)
        enemy = unit(v, 'enemy', 1, x_fp=500)
        window = _window(ally, enemy, 1, Facts(v).world)
        self.assertEqual(1, window['hits']); self.assertGreater(window['first_tick'], 80)
        ally['attributes']['step_fp'] = 4
        window = _window(ally, enemy, 1, Facts(v).world)
        self.assertEqual(1, window['hits']); self.assertGreater(window['first_tick'], 130)

    def test_both_melee_and_ranged_recruits_attack_immediately(self):
        for suit, x in [('Butcher', 40), ('Vulture', 240)]:
            with self.subTest(suit=suit):
                v = view(); hand(v, [(suit, 4)])
                unit(v, 'enemy', 1, x_fp=x)
                f = Facts(v); plan = recruit_plan(f, suit)
                row = evaluate(f, plan)['powers'][0]
                self.assertEqual(2, row['planned_recruits'])
                self.assertGreater(row['hit_hundredths'], 0)
                self.assertTrue(all(a['planned'] and a['first_tick'] == 0 for a in row['attacks']))
                self.assertTrue(all(a['placement_samples'] == 9 for a in row['attacks']))
                plan['order']['lane'] = 'Lord'
                self.assertEqual(0, evaluate(f, plan)['powers'][0]['hit_hundredths'])

    def test_recruiting_does_not_credit_a_birth_round_chase(self):
        v = view(); hand(v, [('Butcher', 4), ('Vulture', 4)])
        unit(v, 'enemy', 1, x_fp=1400)
        f = Facts(v)
        for suit in ('Butcher', 'Vulture'):
            row = evaluate(f, recruit_plan(f, suit))['powers'][0]
            self.assertEqual(2, row['planned_recruits'])
            self.assertEqual(0, row['score'])

    def test_spent_supplicants_do_not_supply_phantom_hits(self):
        v = view()
        unit(v, 'spent', x_fp=2200, waiting=True)
        unit(v, 'enemy', 1, x_fp=2200, step_fp=0, hp=20, max_hp=20)
        f = Facts(v)
        self.assertGreater(rout_value(f, 'Castle')['offense_score'], 0)
        plan = dict(powers=[declaration(0, 1, 'Rout', dict(lane='Castle'))],
                    order=dict(rites=dict(waiter_spends=[dict(lane='Castle', marcher_ids=['spent'])])))
        row = evaluate(f, plan)['powers'][0]
        self.assertEqual(1, row['consumed_excluded']); self.assertEqual(0, row['hit_hundredths'])
        self.assertLess(row['score_delta'], 0)

    def test_near_gate_and_overrun_remain_delay_reasons(self):
        v = view(); unit(v, 'gate', 1, x_fp=100)
        value = rout_value(Facts(v), 'Castle')
        self.assertEqual((14, 0), (value['delay_score'], value['offense_score']))
        v = view(); unit(v, 'own', x_fp=700)
        for i in range(3): unit(v, 'enemy:'+str(i), 1, x_fp=1700, y_fp=180+120*i)
        value = rout_value(Facts(v), 'Castle')
        self.assertTrue(value['overwhelmed']); self.assertEqual(24, value['delay_score'])
        self.assertEqual(0, value['offense_score'])

    def test_towers_and_visible_walls_affect_coverage(self):
        v = view(); enemy = unit(v, 'enemy', 1, x_fp=700, hp=20, max_hp=20)
        tower = dict(id='tower', kind='fortification', owner=0, attributes=dict(structure='Tower', lane='Castle',
            x_fp=480, y_fp=300, hp=6, armor=4, attack=1, ranged_next_tick=0))
        v['data']['field_structures'] = [tower]
        value = rout_value(Facts(v), 'Castle')
        self.assertGreater(value['offense_score'], 0)
        self.assertEqual('tower', value['attacks'][0]['attacker_id'])
        v['data']['field_structures'] = [dict(id='wall', kind='fortification', owner=1,
            attributes=dict(structure='Wall', lane='Castle', x_fp=1200, y_fp=300, hp=10))]
        unit(v, 'own', x_fp=1160, step_fp=8)
        enemy['attributes']['x_fp'] = 1240
        self.assertEqual(0, rout_value(Facts(v), 'Castle')['hit_hundredths'])

    def test_evasion_discounts_hits_and_specials_get_no_suppression(self):
        v = view(); unit(v, 'own', x_fp=1200)
        enemy = unit(v, 'enemy', 1, x_fp=1220)
        enemy['attributes'] = monsters.profile('Kurchin', 'Castle', 1, 0, 1)
        enemy['attributes'].update(x_fp=1220, step_fp=0)
        value = rout_value(Facts(v), 'Castle')
        self.assertLessEqual(value['hit_hundredths'], 6*(100-monsters.TUNING['kurchin_deflection_chance']))
        enemy['attributes'] = monsters.profile('Sooge', 'Castle', 1, 0, 1, True)
        enemy['attributes']['x_fp'] = 1220
        value = rout_value(Facts(v), 'Castle')
        self.assertEqual(0, value['delay_score']); self.assertGreater(value['offense_score'], 0)
        v['board'] = [r for r in v['board'] if r['id'] != 'own']
        self.assertEqual(0, rout_value(Facts(v), 'Castle')['score'])

    def test_nearly_dead_enemy_has_one_shared_damage_budget(self):
        v = view()
        for i in range(8): unit(v, 'own:'+str(i), x_fp=1100, y_fp=300)
        unit(v, 'enemy', 1, x_fp=1150, step_fp=0, hp=1, armor=0)
        value = rout_value(Facts(v), 'Castle')
        self.assertLessEqual(value['hit_hundredths'], 100)
        self.assertEqual(0, value['offense_score'])

    def test_seats_registry_order_and_inputs_are_stable(self):
        v = view(); hand(v, [('Vulture', 4)])
        unit(v, 'own', x_fp=2200)
        unit(v, 'enemy', 1, x_fp=2220, hp=20, max_hp=20)
        f = Facts(v); plan = recruit_plan(f); before = copy_data(v)
        value = rout_value(f, 'Castle', context(f, plan))
        self.assertEqual(before, v)
        v['board'].reverse(); v['hand'].reverse()
        f = Facts(v); self.assertEqual(value, rout_value(f, 'Castle', context(f, plan)))
        other = copy_data(v); other['player_id'] = 1
        for r in other['board']+other['hand']:
            if r['owner'] in (0, 1): r['owner'] = 1-r['owner']
            if r['kind'] == 'marcher': r['attributes']['x_fp'] = 2400-r['attributes']['x_fp']
        f = Facts(other); mirrored = recruit_plan(f)
        self.assertEqual(value, rout_value(f, 'Castle', context(f, mirrored)))

    def test_decision_is_legal_bounded_and_ignores_private_information(self):
        game = planning('Deimos')
        power_components.prepare(game, [dict(kind='fixture_marcher', player_id=1, lane='Castle', origin='retreat-target', ordinal=0,
                                            attributes=dict(x_fp=240, hp=15, max_hp=15))])
        before = game.snapshot(); observed = observe(game, 0)
        policy = CommonSmartCore(); first = policy.decide(observed, Preview(game, 0))
        self.assertEqual(before, game.snapshot())
        self.assertTrue(first['rout']['selected'])
        self.assertGreater(first['rout']['selected'][0]['hit_hundredths'], 0)
        self.assertEqual('legal', Preview(game, 0)(first['plan'])['action'])
        for key, count in first['budget']['used'].items():
            self.assertLessEqual(count, 16 if key.startswith('generated:') else 4 if key.startswith('retained:') else 32 if key == 'complete_plans' else 8)
        game._state['seed'] = 'hidden-other-seed'
        game._state['submissions'][1] = [dict(secret='unseen')]
        game._state['world']['data']['card_zones']['deck'].reverse()
        self.assertEqual(observed, observe(game, 0))
        self.assertEqual(first, policy.decide(observe(game, 0), Preview(game, 0)))
        small = CommonSmartCore(limits=Limits(complete_plans=4, previews=2)).decide(observed, Preview(game, 0))
        self.assertLessEqual(small['budget']['used']['complete_plans'], 4)
        self.assertLessEqual(small['budget']['used']['previews'], 2)

    def test_policy_prefers_firing_coverage_over_a_balanced_distant_approach(self):
        game = planning('Deimos')
        changes = [dict(kind='fixture_marcher', player_id=0, lane='Lord', origin='shooter', ordinal=i,
                        attributes=dict(recruitment.profile('Vulture', 'Lord', 0, 0, 1), x_fp=1000, y_fp=280+40*i,
                                        hp=30, max_hp=30)) for i in range(2)]
        changes += [dict(kind='fixture_marcher', player_id=1, lane='Lord', origin='covered', ordinal=0,
                         attributes=dict(x_fp=1120, hp=25, max_hp=25)),
                    dict(kind='fixture_marcher', player_id=0, lane='Castle', origin='chaser', ordinal=0,
                         attributes=dict(x_fp=900)),
                    dict(kind='fixture_marcher', player_id=1, lane='Castle', origin='distant', ordinal=0,
                         attributes=dict(x_fp=1700))]
        power_components.prepare(game, changes)
        decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        source = next(s for s in decision['plan']['powers'] if s['power_id'] == 'Rout')
        self.assertEqual('Lord', source['target']['lane'])
        value = decision['rout']['selected'][0]
        self.assertGreater(value['offense_score'], 0); self.assertEqual(0, value['delay_score'])

    def test_observation_includes_only_public_lane_objects_as_detached_data(self):
        game = planning('Deimos')
        game._state['world']['data']['field_structures'] = [dict(id='public-tower', kind='fortification', owner=0,
            attributes=dict(structure='Tower', lane='Lord', x_fp=480, y_fp=300, hp=6, armor=4, attack=1, ranged_next_tick=0))]
        projected = observe(game, 0)
        self.assertEqual('public-tower', projected['data']['field_structures'][0]['id'])
        projected['data']['field_structures'][0]['attributes']['hp'] = 0
        self.assertEqual(6, game._state['world']['data']['field_structures'][0]['attributes']['hp'])

    def test_resolved_combat_allows_both_recruit_attacks_before_movement_ready(self):
        # Two isolated Marching phases, not games. Full-resolution placement is
        # explicit so this verifies attack readiness rather than sampling RNG.
        for suit, target_x, event_type in [('Butcher', 100, 'MARCHER_MELEE_ATTACK'), ('Vulture', 250, 'MARCHER_RANGED_ATTACK')]:
            with self.subTest(suit=suit):
                spec = copy_data(marching_fixtures.load()['cases'][0])
                spec['ranged'] = True
                spec['units'] = [dict(suit=suit, lane='Castle', owner=0, birth=1, ready=2, origin='fresh', ordinal=0,
                                     attributes=dict(x_fp=60, y_fp=300)),
                                 dict(suit='Butcher', lane='Castle', owner=1, birth=0, ready=1, origin='fleeing', ordinal=0,
                                     attributes=dict(x_fp=target_x, y_fp=300, hp=30, max_hp=30, armor=0,
                                                     rout_round=1, rout_effect_id='focused-rout'))]
                w = marching_fixtures.initial(spec); w['data']['rout_profile'] = marching.ROUT
                result = marching.resolve(marching_fixtures.context(spec, w, 1), capture_ticks=False)
                self.assertEqual('resolved', result['action'])
                attacks = [r['event']['data'] for r in result['events'] if r['event']['type'] == event_type]
                self.assertTrue(attacks); self.assertEqual(0, attacks[0]['tick'])
                self.assertEqual(2, attacks[0]['attacker']['attributes']['movement_ready_round'])
                self.assertGreater(attacks[0]['damage_dealt'], 0)


if __name__ == '__main__':
    unittest.main()
