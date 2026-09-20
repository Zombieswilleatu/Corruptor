"""Own-plan interactions: conditional forecasts plus actual authority hooks."""
import unittest
from unittest.mock import patch

from u13_pysim import economy, full_match_inputs, power_components
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .common import CommonSmartCore
from .coordination import evaluate
from .facts import Facts, Proposal
from .observation import observe, Preview
from .planner_probe import PlannerObserver
from .selection import PlanSelector, SelectionSettings
from .test_common import planning
from .test_recipes_veil import hand


def guard(view, identity, value, slot=0, lane='Castle', suit='Vulture'):
    view['board'].append(dict(id=identity, kind='card', owner=1,
        attributes=dict(role='guard', lane=lane, slot=slot, value=value, suit=suit)))


def plan(f, power, target, ids=(), action='Siege', **parameters):
    castle = f.castles(1)[0]['id']
    order = dict(action=action, lane='Castle', target_id=castle, card_ids=list(ids)) if ids else {}
    return dict(powers=[declaration(0, f.v['round'], power, target, parameters=parameters)], order=order)


def prepared(lord):
    game = planning(lord)
    world = game._state['world']
    rows = world['entities']['entities']
    victim = next(r for r in rows if r['kind'] == 'card' and r['attributes']['value'] == 3
                  and r['id'] not in economy.zones(world)['hands'][0])
    attack = next(r for r in rows if r['kind'] == 'card' and r['attributes']['suit'] == 'Butcher'
                  and r['attributes']['value'] == 5)
    power_components.prepare(game, [
        dict(kind='fixture_guard', card_id=victim['id'], player_id=1, lane='Castle', slot=0),
        dict(kind='fixture_give', card_id=attack['id'], player_id=0),
        dict(kind='fixture_resources', player_id=0, resources=dict(life_essence=5))])
    return game, victim['id'], attack['id']


def attack_source(attack_id):
    def ordinary(f, category, _weights):
        if category == 'combat':
            yield Proposal('combat', 'Pass', {}, 0, 'directed_pass')
            yield Proposal('combat', 'Siege', dict(action='Siege', lane='Castle',
                target_id=f.castles(1)[0]['id'], card_ids=[attack_id]), 200, 'directed_attack', (attack_id,))
    return ordinary


class CoordinationTests(unittest.TestCase):
    def test_projection_checks_remaining_affordable_guards_and_equality(self):
        view = observe(planning('Valak'), 0)
        view['players'][0]['resources']['life_essence'] = 5
        hand(view, [('Butcher', 5)])
        guard(view, 'high', 5); guard(view, 'low', 2, 1)
        f = Facts(view)
        p = plan(f, 'Projection', dict(kind='guard_zone', zone='Castle', player_id=1), ['ingredient:0'], spend=5)
        # Strict attack equality cannot defeat the first Guard.
        row = evaluate(f, p)['powers'][0]
        self.assertEqual('high', row['victim_id'])
        self.assertEqual(0, row['follow_up_score'])  # The attack spends our only card.
        self.assertLessEqual(row['score_delta'], 0)
        view['hand'][0]['attributes']['value'] = 6
        row = evaluate(Facts(view), p)['powers'][0]
        self.assertEqual(['low'], row['eligible_after'])
        self.assertLessEqual(row['score_delta'], -12)
        view['hand'][0]['attributes']['value'] = 8
        row = evaluate(Facts(view), p)['powers'][0]
        self.assertLessEqual(row['score_delta'], -30)
        self.assertEqual('attack_removes_projection_targets', row['reason'])
        # A surviving Guard too expensive for this Projection is no target.
        p['powers'][0]['parameters']['spend'] = 2
        self.assertLessEqual(evaluate(Facts(view), p)['score_delta'], -18)

    def test_guard_identity_and_pair_screen_survive_registry_permutation(self):
        view = observe(planning('Kroni'), 0)
        hand(view, [('Butcher', 5)])
        guard(view, 'slot1', 2, 1, suit='Penitent'); guard(view, 'slot0', 2, 0, suit='Penitent')
        p = plan(Facts(view), 'Consume', dict(entity_id='slot1'), ['ingredient:0'])
        original = evaluate(Facts(view), p)
        self.assertEqual(['slot0', 'slot1'], original['context']['guard_losses'])
        view['board'].reverse()
        self.assertEqual(original, evaluate(Facts(view), p))
        view['data']['guard_work']['pairs'] = [dict(active=True, player_id=1, lane='Castle', suit='Penitent',
            ids=['slot0', 'slot1'], slots=[0, 1])]
        self.assertEqual(0, evaluate(Facts(view), p)['score_delta'])

    def test_consume_tracks_its_guard_even_when_another_guard_survives(self):
        view = observe(planning('Kroni'), 0)
        hand(view, [('Butcher', 5)])
        guard(view, 'meal', 3); guard(view, 'survivor', 2, 1)
        p = plan(Facts(view), 'Consume', dict(entity_id='meal'), ['ingredient:0'])
        self.assertLess(evaluate(Facts(view), p)['score_delta'], 0)
        p['powers'][0]['target']['entity_id'] = 'survivor'
        self.assertEqual(0, evaluate(Facts(view), p)['score_delta'])

    def test_supplicants_reserved_for_rites_cannot_also_clear_power_targets(self):
        view = observe(planning('Kroni'), 0)
        hand(view, [('Butcher', 1)]); guard(view, 'meal', 5)
        for i in range(5):
            view['board'].append(dict(id='waiter:'+str(i), kind='marcher', owner=0,
                attributes=dict(lane='Castle', waiting=True, hp=5)))
        p = plan(Facts(view), 'Consume', dict(entity_id='meal'), ['ingredient:0'])
        self.assertLess(evaluate(Facts(view), p)['score_delta'], 0)
        p['order']['rites'] = dict(waiter_spends=[dict(lane='Castle', marcher_ids=['waiter:'+str(i) for i in range(5)])])
        self.assertEqual(0, evaluate(Facts(view), p)['score_delta'])

    def test_ravenous_counts_recruits_monsters_and_departing_supplicants(self):
        view = observe(planning('Kroni'), 0)
        hand(view, [('Butcher', 4)])
        f = Facts(view)
        p = plan(f, 'Ravenous', dict(lane='Castle', field_position=dict(x_fp=0, y_fp=300)), ['ingredient:0'], 'Ward')
        p['order']['monster_choice'] = 'Varn'
        first = evaluate(f, p)
        self.assertEqual(-45, first['score_delta'])  # two ordinary plus at least three Varn
        self.assertTrue(first['context']['unknown_extra_varn_bodies'])
        view['board'].append(dict(id='waiter', kind='marcher', owner=0, attributes=dict(lane='Castle', waiting=True, hp=5)))
        p['order']['action'] = 'Siege'
        row = evaluate(Facts(view), p)['powers'][0]
        self.assertEqual(1, row['consumed_supplicants'])
        self.assertEqual(-27, row['score_delta'])
        p['order']['lane'] = 'Lord'; p['order']['action'] = 'Hunt'; p['order']['target_id'] = f.lord[1]['id']
        self.assertEqual(0, evaluate(Facts(view), p)['score_delta'])

    def test_no_power_alternative_keeps_attack_and_conserves_essence(self):
        game, victim, attack = prepared('Valak'); before = game.snapshot()
        with patch('u13_doctrine.common.ordinary', attack_source(attack)):
            decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertEqual([], decision['plan']['powers'])
        self.assertEqual([attack], decision['plan']['order']['card_ids'])
        self.assertIn('Projection', decision['coordination']['selected_omitted_powers'])
        self.assertEqual(before, game.snapshot())
        self.assertEqual('legal', Preview(game, 0)(decision['plan'])['action'])
        self.assertFalse(decision['coordination']['hard_veto'])
        self.assertLessEqual(decision['budget']['used']['complete_plans'], 32)
        self.assertLessEqual(decision['budget']['used']['previews'], 8)
        # Independent authority execution confirms the attack kills the Guard
        # before Projection and that omitting it preserves three Essence.
        outcomes = []
        for include in (False, True):
            run, _, _ = prepared('Valak')
            choice = copy_data(decision['plan'])
            if include:
                choice['powers'] = [declaration(0, 1, 'Projection', dict(kind='guard_zone', zone='Castle', player_id=1), parameters=dict(spend=3))]
            self.assertNotEqual('invalid', run.apply(dict(kind='submit', plans=[choice, dict(powers=[], order={})]))['action'])
            while run.clock.hook != 'post_resolution_special_actors':
                self.assertNotEqual('invalid', run.apply(full_match_inputs.next_operation(run))['action'])
            events = [r['event'] for r in run._state['events']['rows']]
            projections = [e['data'] for e in events if e['type'] == 'VALAK_PROJECTION_RESOLVED']
            self.assertEqual([True] if include else [], [e['whiff'] for e in projections])
            outcomes.append(run._state['world']['players'][0]['resources']['life_essence'])
        self.assertEqual(3, outcomes[0]-outcomes[1])

    def test_consume_omission_wins_equal_score_and_reindexes_remaining_power(self):
        game, _, attack = prepared('Kroni')
        changes = [dict(kind='fixture_marcher', player_id=1, lane='Lord', origin='ravenous-targets', ordinal=i,
                        attributes=dict(x_fp=900, y_fp=100+50*i)) for i in range(4)]
        power_components.prepare(game, changes)
        with patch('u13_doctrine.common.ordinary', attack_source(attack)), \
                patch('u13_doctrine.common.Recipes.proposals', return_value=iter(())):
            decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertEqual(['Ravenous'], [s['power_id'] for s in decision['plan']['powers']])
        self.assertEqual(0, decision['plan']['powers'][0]['queue_index'])
        self.assertIn('Consume', decision['coordination']['selected_omitted_powers'])
        self.assertEqual('legal', Preview(game, 0)(decision['plan'])['action'])

    def test_useful_projection_is_still_available(self):
        game, _, _ = prepared('Valak')
        # Ward leaves the visible Guard in place; Projection retains its credit.
        with patch('u13_doctrine.common.ordinary', lambda f, c, w: iter(
                [Proposal('combat', 'Pass', {}, 0, 'hold')] if c == 'combat' else [])):
            decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertEqual(['Projection'], [s['power_id'] for s in decision['plan']['powers']])
        self.assertGreaterEqual(decision['coordination']['selected']['score_delta'], 0)
        self.assertEqual(0, decision['coordination']['omission_plans'])

    def test_ravenous_can_outweigh_new_friendly_exposure_and_counts_breach_spawn(self):
        game, _, attack = prepared('Kroni')
        power_components.prepare(game, [dict(kind='fixture_marcher', player_id=1, lane='Castle', origin='ravenous-targets', ordinal=i,
                        attributes=dict(x_fp=900, y_fp=100+40*i)) for i in range(8)])
        with patch('u13_doctrine.common.ordinary', attack_source(attack)):
            decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertEqual(['Ravenous'], [s['power_id'] for s in decision['plan']['powers']])
        self.assertLess(decision['coordination']['selected']['score_delta'], 0)
        choice = copy_data(decision['plan'])
        choice['powers'].append(declaration(0, 1, 'BreachWishPower', dict(lane='Castle'), index=1))
        row = evaluate(Facts(observe(game, 0)), choice)['powers'][0]
        self.assertEqual(1, row['power_bodies_minimum'])

    def test_softmax_can_admit_risky_power_without_exceeding_preview_budget(self):
        game, _, attack = prepared('Valak')
        policy = CommonSmartCore(selector=PlanSelector(SelectionSettings(20, 100, 'coordination-test')))
        observed = []
        authority = Preview(game, 0)
        def preview(plan):
            observed.append(copy_data(plan))
            return authority(plan)
        with patch('u13_doctrine.common.ordinary', attack_source(attack)):
            first = policy.decide(observe(game, 0), preview)
            second = policy.decide(observe(game, 0), Preview(game, 0))
        self.assertEqual(first, second)
        self.assertTrue(any(s['power_id'] == 'Projection' for p in observed for s in p['powers']))
        self.assertLessEqual(len(observed), 8)
        self.assertEqual([], first['rejected_previews'])

    def test_observer_counts_evaluated_and_omitted_powers_separately(self):
        game, _, attack = prepared('Valak')
        with patch('u13_doctrine.common.ordinary', attack_source(attack)):
            decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        observer = PlannerObserver(dict(name='coordination', setup=dict(lords=['Valak', 'Gremory'])))
        observer.accepted(1, 0, decision)
        counts = observer.report()['power_coordination']
        self.assertEqual(1, counts['measured_decisions'])
        self.assertGreater(counts['adjusted_plans:Projection'], 0)
        self.assertEqual(1, counts['selected_omission:Projection'])


if __name__ == '__main__': unittest.main()
