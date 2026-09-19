"""Own artillery timing, conditional target changes and natural round replays."""
import copy
import json
from pathlib import Path
import unittest

from u13_pysim import economy, full_match_inputs, power_components
from u13_pysim.battle import targetable
from u13_pysim.power_match import PowerMatch
from u13_pysim.power_rules import declaration
from .budget import Limits
from .common import CommonSmartCore, Weights
from .diagnostics import fingerprint
from .facts import Facts
from .lords.deimos import ArtilleryPlans, attack_after, proposals
from .observation import observe, Preview
from .planner_probe import PlannerObserver
from .test_common import planning


def prepared(hp=3, last=False):
    game = planning('Deimos'); f = Facts(observe(game, 0))
    engine = next(c for c in f.castles(0) if c['attributes']['castle_type'] == 'SiegeEngine')['id']
    victim = next(c for c in f.castles(1) if c['attributes']['castle_type'] == 'Stockpile')['id']
    spare = next(c for c in f.castles(1) if c['attributes']['castle_type'] == 'Keep')['id']
    changes = [dict(kind='fixture_patch', entity_id=engine,
        attributes=dict(construction_state='active', status='standing', integrity=17, artillery_target=victim))]
    for row in f.castles(1):
        integrity = hp if row['id'] == victim else 17 if row['id'] == spare and not last else 0
        changes.append(dict(kind='fixture_patch', entity_id=row['id'], attributes=dict(
            construction_state='active', integrity=integrity, status='standing' if integrity else 'ruined')))
    power_components.prepare(game, changes)
    return game, engine, victim, spare


def plan(game, engine, victim=None):
    f = Facts(observe(game, 0)); order = {}
    if victim:
        order = dict(action='Siege', lane='Castle', target_id=victim, card_ids=[r['id'] for r in f.hand])
    return dict(powers=[declaration(0, game.clock.round, 'WarMachine', dict(entity_id=engine))], order=order)


def resolve_combat(game, plans):
    game = copy.deepcopy(game); cursor = len(game._state['events']['rows'])
    result = game.apply(dict(kind='submit', plans=plans))
    if result['action'] == 'invalid': raise AssertionError(result)
    while game.clock.hook != 'post_resolution_spawns':
        result = game.apply(full_match_inputs.next_operation(game))
        if result['action'] == 'invalid': raise AssertionError(result)
    return game, [r['event'] for r in game._state['events']['rows'][cursor:]]


class DeimosTests(unittest.TestCase):
    def test_extra_shot_precedes_normal_and_prices_incremental_damage(self):
        game, engine, victim, _ = prepared(); choice = plan(game, engine)
        before = game.snapshot(); model = ArtilleryPlans(Facts(observe(game, 0)), Weights())
        predicted = model.evaluate(choice)
        self.assertEqual(before, game.snapshot())
        self.assertEqual(-9, predicted['war_machine_score_delta'])
        after, events = resolve_combat(game, [choice, dict(powers=[], order={})])
        shots = [e['data'] for e in events if e['type'] == 'ARTILLERY_FIRED' and e['data']['player_id'] == 0]
        self.assertEqual([2, 1], [s['damage'] for s in shots])
        self.assertEqual('normal', shots[1]['shot'])
        self.assertEqual([(h['target_id'], h['damage'], h['destroyed']) for h in predicted['hits']],
                         [(s['target_id'], s['damage'], s['destroyed']) for s in shots])
        self.assertFalse(targetable(economy.entity(after._state['world'], victim)))

    def test_doomed_siege_loses_attack_credit_but_keeps_recruitment(self):
        game, engine, victim, _ = prepared(); choice = plan(game, engine, victim)
        predicted = ArtilleryPlans(Facts(observe(game, 0)), Weights()).evaluate(choice)
        self.assertTrue(predicted['siege_target_lost']); self.assertLess(predicted['attack_score_delta'], 0)
        _, events = resolve_combat(game, [choice, dict(powers=[], order={})])
        self.assertTrue(any(e['type'] == 'COMBAT_ORDER_FIZZLED' and e['data']['player_id'] == 0 for e in events))
        self.assertTrue(any(e['type'] == 'COMBAT_ORDER_REVEALED' and e['data']['player_id'] == 0 for e in events))

    def test_last_castle_fall_becomes_pillage_and_extra_shot_is_redundant(self):
        game, engine, victim, _ = prepared(hp=2, last=True); choice = plan(game, engine, victim)
        model = ArtilleryPlans(Facts(observe(game, 0)), Weights()); predicted = model.evaluate(choice)
        self.assertFalse(predicted['siege_target_lost']); self.assertEqual(-18, predicted['war_machine_score_delta'])
        self.assertTrue(attack_after(model.project(choice)[0], choice['order'], [])['pillage'])
        _, events = resolve_combat(game, [choice, dict(powers=[], order={})])
        self.assertTrue(next(e['data']['pillage'] for e in events if e['type'] == 'SIEGE_RESOLVED'))

    def test_random_reacquisition_is_unknown_and_does_not_read_seed(self):
        game, engine, _, _ = prepared(); economy.entity(game._state['world'], engine)['attributes']['artillery_target'] = ''
        choice = plan(game, engine); view = observe(game, 0)
        first = ArtilleryPlans(Facts(view), Weights()).evaluate(choice)
        self.assertEqual([], first['hits']); self.assertEqual(2, first['unknown_shots'])
        self.assertEqual(0, first['war_machine_score_delta'])
        game._state['seed'] = 'different-private-seed'
        view['board'].reverse(); view['hand'].reverse()
        self.assertEqual(first, ArtilleryPlans(Facts(view), Weights()).evaluate(choice))
        self.assertEqual(Facts(view).v['board'][::-1], observe(game, 0)['board'])

    def test_singleton_reacquisition_is_known_and_empty_board_has_no_power_credit(self):
        game, engine, victim, _ = prepared(last=True)
        economy.entity(game._state['world'], engine)['attributes']['artillery_target'] = ''
        prediction = ArtilleryPlans(Facts(observe(game, 0)), Weights()).evaluate(plan(game, engine))
        self.assertEqual(0, prediction['unknown_shots']); self.assertEqual([victim, victim], [h['target_id'] for h in prediction['hits']])
        economy.entity(game._state['world'], victim)['attributes'].update(integrity=0, status='ruined')
        f = Facts(observe(game, 0)); power = next(p for p in proposals(f) if p.term == 'WarMachine')
        self.assertEqual(0, power.value)
        choice = CommonSmartCore().decide(f.v, Preview(game, 0))
        self.assertNotIn('WarMachine', [s['power_id'] for s in choice['plan']['powers']])

    def test_own_work_can_restore_normal_artillery_without_illegal_war_machine(self):
        game, engine, victim, _ = prepared(hp=10)
        cards = [r for r in game._state['world']['entities']['entities'] if r['kind'] == 'card' and r['attributes']['suit'] == 'Wright'][:2]
        power_components.prepare(game, [dict(kind='fixture_patch', entity_id=engine, attributes=dict(integrity=4))]+
            [dict(kind='fixture_give', player_id=0, card_id=r['id']) for r in cards])
        choice = dict(powers=[], order=dict(castle_action=dict(action='Work', target_id=engine, card_ids=[], use_repair_token=False),
            guard_moves=[dict(card_id=r['id'], lane='Castle', slot=i) for i,r in enumerate(cards)]))
        predicted = ArtilleryPlans(Facts(observe(game, 0)), Weights()).evaluate(choice)
        self.assertEqual([2], [h['damage'] for h in predicted['hits']])
        after, events = resolve_combat(game, [choice, dict(powers=[], order={})])
        self.assertEqual(8, economy.entity(after._state['world'], victim)['attributes']['integrity'])
        self.assertTrue(any(e['type'] == 'ARTILLERY_FIRED' for e in events))

    def test_enemy_repair_can_preserve_predicted_lost_target_and_no_hard_veto(self):
        game, engine, victim, _ = prepared(); choice = plan(game, engine, victim)
        cards = [r for r in game._state['world']['entities']['entities'] if r['kind'] == 'card'
                 and r['attributes']['suit'] == 'Wright' and r['id'] not in economy.zones(game._state['world'])['hands'][0]][:2]
        power_components.prepare(game, [dict(kind='fixture_give', player_id=1, card_id=r['id']) for r in cards])
        enemy = dict(powers=[], order=dict(castle_action=dict(action='Work', target_id=victim, card_ids=[], use_repair_token=False),
            guard_moves=[dict(card_id=r['id'], lane='Lord', slot=i) for i,r in enumerate(cards)]))
        self.assertTrue(ArtilleryPlans(Facts(observe(game, 0)), Weights()).evaluate(choice)['siege_target_lost'])
        self.assertEqual('legal', Preview(game, 0)(choice)['action'])
        _, events = resolve_combat(game, [choice, enemy])
        self.assertFalse(any(e['type'] == 'COMBAT_ORDER_FIZZLED' and e['data']['player_id'] == 0 for e in events))
        self.assertTrue(any(e['type'] == 'SIEGE_RESOLVED' for e in events))

    def test_natural_retargets_resolve_against_the_recorded_opponent(self):
        data = json.loads(Path(__file__).with_name('deimos_artillery_cases.json').read_text())
        for case in data['cases']:
            with self.subTest(case=case['name']):
                game = PowerMatch(case['setup'])
                for op in case['prior_operations']:
                    self.assertNotEqual('invalid', game.apply(op)['action'])
                seat = case['seat']; view = observe(game, seat); before = game.snapshot()
                self.assertEqual(case['view_sha256'], fingerprint(view))
                choice = CommonSmartCore().decide(view, Preview(game, seat))
                self.assertEqual([], choice['rejected_previews']); self.assertTrue(choice['artillery']['selected_retarget'])
                self.assertFalse(choice['artillery']['hard_veto'])
                self.assertNotEqual(case['original_target'], choice['plan']['order']['target_id'])
                original = case['original_plans'][seat]['order']
                self.assertEqual(original['card_ids'], choice['plan']['order']['card_ids'])
                # Balance changes can alter which recipe the policy selects.
                # The replay separately pins that choice and the preserved cards.
                expected_monster = case.get('expected_monster_choice', original.get('monster_choice'))
                self.assertEqual(expected_monster, choice['plan']['order'].get('monster_choice'))
                view['board'].reverse(); view['hand'].reverse()
                self.assertEqual(choice, CommonSmartCore().decide(view, Preview(game, seat)))
                self.assertEqual(before, game.snapshot())
                for name, count in choice['budget']['used'].items():
                    self.assertLessEqual(count, 16 if name.startswith('generated:') else 4 if name.startswith('retained:') else 32 if name == 'complete_plans' else 8)
                for candidate in (False, True):
                    plans = copy.deepcopy(case['original_plans'])
                    if candidate: plans[seat] = choice['plan']
                    _, events = resolve_combat(game, plans)
                    fizzled = any(e['type'] == 'COMBAT_ORDER_FIZZLED' and e['data']['player_id'] == seat for e in events)
                    self.assertEqual(not candidate, fizzled)
                    if candidate:
                        self.assertTrue(any(e['type'] == 'SIEGE_RESOLVED' and e['data']['player_id'] == seat and e['data']['damage'] > 0 for e in events))
                observer = PlannerObserver(dict(name=case['name'], setup=case['setup']))
                observer.accepted(case['round'], seat, choice)
                self.assertEqual(1, observer.report()['artillery_planning']['selected_retargets'])

    def test_small_budgets_and_non_deimos_scope(self):
        game, _, _, _ = prepared(); limits = Limits(4, 2, 8, 2)
        result = CommonSmartCore(limits=limits).decide(observe(game, 0), Preview(game, 0))
        for name, count in result['budget']['used'].items():
            self.assertLessEqual(count, 4 if name.startswith('generated:') else 2 if name.startswith('retained:') else 8 if name == 'complete_plans' else 2)
        self.assertFalse(ArtilleryPlans(Facts(observe(planning('Humbaba'), 0)), Weights()).enabled)


if __name__ == '__main__': unittest.main()
