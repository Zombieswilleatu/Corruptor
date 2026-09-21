"""Directed decision contracts, separate from unmodified complete-game probes."""
import unittest
from unittest.mock import patch

from u13_pysim import economy, full_match_inputs, monsters, power_components, veil
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .common import CommonSmartCore, Weights
from .facts import Facts
from .observation import observe, Preview
from .planner_probe import PlannerObserver
from .recipes import Recipes
from .test_common import planning
from .veil_judgment import paid_scenario, protection_projection, settlement_projection


def hand(view, suits):
    view['hand'] = [dict(id='ingredient:'+str(i), kind='card', owner=view['player_id'],
        attributes=dict(suit=suit, value=value)) for i, (suit, value) in enumerate(suits)]


class RecipeVeilTests(unittest.TestCase):
    def test_all_ten_exact_recipe_plans_use_real_cards_and_pass_authority(self):
        for name in monsters.NAMES:
            with self.subTest(monster=name):
                game = planning('Deimos'); world = game._state['world']
                selected = []
                for suit, count in monsters.ROSTER[name]['recipe'].items():
                    cards = sorted((r for r in world['entities']['entities'] if r['kind'] == 'card' and r['attributes']['suit'] == suit),
                                   key=lambda r: (r['attributes']['value'], r['id']))
                    selected.extend(r['id'] for r in cards[:count])
                power_components.prepare(game, [dict(kind='fixture_give', player_id=0, card_id=k) for k in selected])
                view = observe(game, 0); book = Recipes(Facts(view), Weights())
                candidate = next(p for p in book.proposals() if p.payload['monster_choice'] == name)
                self.assertEqual(sum(monsters.ROSTER[name]['recipe'].values()), len(candidate.cards))
                self.assertEqual('legal', Preview(game, 0)(dict(powers=[], order=candidate.payload))['action'])
                # A high face value cannot replace a missing physical subject.
                view['hand'] = [r for r in view['hand'] if r['id'] in candidate.cards[1:]]
                for r in view['hand']: r['attributes']['value'] = 20
                self.assertNotIn(name, [p.payload['monster_choice'] for p in Recipes(Facts(view), Weights()).proposals()])

    def test_unlocks_living_limits_and_charmed_owner_control_recipe_goals(self):
        view = observe(planning(), 0)
        hand(view, [('Butcher', 1)]*3+[('Wright', 1)]*2)
        view['data']['monsters']['unlocked'][0] = ['Sooge']
        self.assertEqual('Sooge', Recipes(Facts(view), Weights()).goal(view['hand'])['monster'])
        self.assertEqual('', Recipes(Facts(view), Weights()).goal(view['hand'], 'Sooge')['monster'])
        view['board'].append(dict(id='living-sooge', kind='marcher', owner=1,
            attributes=dict(monsters.profile('Sooge', 'Castle', 1, 1, 2), charm_owner=0)))
        book = Recipes(Facts(view), Weights())
        self.assertEqual('living_copy_limit', book.status['Sooge'])
        self.assertEqual('', book.goal(view['hand'])['monster'])
        self.assertEqual([], list(book.proposals()))
        view['board'].pop(); view['data']['monsters']['unlocked'][0] = []
        self.assertEqual('recipe_locked', Recipes(Facts(view), Weights()).status['Sooge'])

    def test_stockpile_and_market_can_prefer_missing_subject_over_face_value(self):
        view = observe(planning(), 0)
        view['data']['monsters']['unlocked'][0] = ['Sooge']
        hand(view, [('Butcher', 1)]*3+[('Wright', 1)])
        offered = [dict(id='wright', kind='card', owner=0, attributes=dict(suit='Wright', value=1)),
                   dict(id='extra-butcher', kind='card', owner=0, attributes=dict(suit='Butcher', value=2))]
        view['stockpile'] = offered
        view['hand'] += copy_data(offered)
        choice = CommonSmartCore().choose_card(view, 'stockpile')
        self.assertEqual('wright', choice['operation']['keep_id'])
        hand(view, [('Butcher', 1)]*3+[('Wright', 1), ('Penitent', 2)])
        view['market'] = offered
        choice = CommonSmartCore().choose_card(view, 'slaver')
        self.assertEqual('wright', choice['operation']['choice']['take_id'])
        self.assertEqual('ingredient:4', choice['operation']['choice']['give_id'])

    def test_one_missing_recipe_can_be_saved_and_emergency_defense_can_override(self):
        view = observe(planning('Deimos'), 0)
        view['data']['monsters']['unlocked'][0] = ['Sooge']
        hand(view, [('Butcher', 1)]*3+[('Wright', 1)])
        # No Guard slots: wasting ingredients on a weak commitment has no urgency.
        for lane in ('Lord', 'Castle'):
            for slot in range(3):
                view['board'].append(dict(id=f'guard:{lane}:{slot}', kind='card', owner=0,
                    attributes=dict(role='guard', suit='Penitent', value=3, lane=lane, slot=slot)))
        policy = CommonSmartCore(lord_modules=False)
        held = policy.decide(view, lambda plan: dict(action='legal'))
        self.assertEqual('Sooge', held['recipes']['retained_goal']['monster'])
        self.assertEqual({'Wright': 1}, held['recipes']['retained_goal']['missing'])
        self.assertEqual([], held['plan']['order'].get('card_ids', []))
        view['board'] = [r for r in view['board'] if not r['id'].startswith('guard:')]
        for i in range(6):
            view['board'].append(dict(id='enemy:'+str(i), kind='marcher', owner=1,
                attributes=dict(lane='Lord', hp=3, max_hp=3, waiting=False, x_fp=100, y_fp=100+i*20)))
        defended = policy.decide(view, lambda plan: dict(action='legal'))
        self.assertTrue(defended['plan']['order'].get('guard_moves') or defended['plan']['order'].get('card_ids'))
        self.assertLess(defended['recipes']['saving_score_delta'], 0)

    def test_saving_is_one_best_goal_without_unknown_draws_or_late_game_hoarding(self):
        view = observe(planning(), 0)
        hand(view, [('Wright', 1)]*3+[('Vulture', 1)]*2+[('Penitent', 1)]*2)
        book = Recipes(Facts(view), Weights()); goal = book.goal(view['hand'])
        self.assertIn(goal['monster'], monsters.NAMES)
        self.assertLessEqual(goal['score'], max(book.value(n, lane)//2 for n in monsters.NAMES for lane in ('Lord', 'Castle')))
        view['round'] = 21; view['data']['neutral_tears'] = 24
        self.assertEqual(0, Recipes(Facts(view), Weights()).goal(view['hand'])['score'])
        hand(view, [('Butcher', 1), ('Wright', 1)])
        view['round'] = 1; view['data']['neutral_tears'] = 0
        view['data']['monsters']['unlocked'][0] = ['Sooge']
        self.assertEqual('', Recipes(Facts(view), Weights()).goal(view['hand'])['monster'])

    def test_complete_monster_plan_is_previewed_unchanged_and_spawn_is_measured(self):
        game = planning('Deimos'); world = game._state['world']
        cards = sorted((r for r in world['entities']['entities'] if r['kind'] == 'card' and r['attributes']['suit'] == 'Vulture'),
                       key=lambda r: (r['attributes']['value'], r['id']))[:2]
        power_components.prepare(game, [dict(kind='fixture_give', player_id=0, card_id=r['id']) for r in cards])
        economy.discard(game._state['world'], 0, [k for k in game._state['world']['data']['card_zones']['hands'][0] if k not in {r['id'] for r in cards}])
        game._state['presentation_world'] = copy_data(game._state['world'])
        authority, previews = Preview(game, 0), []
        def preview(plan):
            previews.append(copy_data(plan)); return authority(plan)
        decision = CommonSmartCore(lord_modules=False).decide(observe(game, 0), preview)
        self.assertEqual('Varn', decision['plan']['order']['monster_choice'])
        self.assertEqual(previews[-1], decision['plan'])
        self.assertEqual([], decision['rejected_previews'])
        before = game.snapshot()
        self.assertNotEqual('invalid', game.apply(dict(kind='submit', plans=[decision['plan'], dict(powers=[], order={})]))['action'])
        observer = PlannerObserver(dict(name='recipe', setup=dict(lords=['Deimos', 'Gremory'])))
        observer.accepted(1, 0, decision)
        cursor = len(game._state['events']['rows'])
        while game.clock.hook != 'combat_resolution':
            self.assertNotEqual('invalid', game.apply(full_match_inputs.next_operation(game))['action'])
        for i, row in enumerate(game._state['events']['rows'][cursor:], cursor): observer.event(i, row['event'], 1)
        group = next(g for g in observer.report()['groups'] if g['category'] == 'monsters' and g['term'] == 'Varn')
        self.assertEqual(1, group['outcomes']['resolved'])
        self.assertEqual(1, group['metrics']['summons'])
        self.assertIn(group['metrics']['bodies_spawned'], (3, 4, 5))
        self.assertNotEqual(before, game.snapshot())

    def test_recipe_proposals_stop_at_work_reservations_and_keep_unknown_counts(self):
        from .facts import Proposal
        built = []
        def proposals(book):
            while True:
                built.append(1)
                yield Proposal('combat', 'Ward', dict(action='Ward', lane='Lord', card_ids=[], monster_choice='Lemek'), 0, 'budget_probe')
        with patch.object(Recipes, 'proposals', proposals):
            decision = CommonSmartCore().decide(observe(planning(), 0), lambda plan: dict(action='legal'))
        self.assertEqual(16, len(built))
        self.assertLessEqual(decision['budget']['used']['complete_plans'], 32)
        self.assertIsNone(next(a for a in decision['assessments'] if a['category'] == 'monsters' and a['term'] == 'Sooge')['generated'])

    def test_current_revealed_protection_uses_correct_direction_for_every_lord(self):
        for lord in veil.LORDS:
            with self.subTest(lord=lord):
                view = observe(planning(), 0)
                view['data']['veil_breaches']['arrivals'] = [dict(lord_id=lord, protection=1, threshold=5, round=1, veil=5)]
                result = protection_projection(Facts(view), dict(powers=[], order=dict(rites=dict(invocation={}))), 8)
                self.assertEqual([lord], [r['lord'] for r in result['changes']])
                change = result['changes'][0]
                self.assertEqual(1 if lord in veil.BENEFICIAL else 0, change['affected_player'])
                self.assertEqual('deny_enemy_benefit' if lord in veil.BENEFICIAL else 'protect_own_side', change['direction'])

    def test_no_value_for_unrevealed_unprotectable_already_protected_or_ordinary_breach(self):
        view = observe(planning(), 0)
        plan = dict(powers=[], order=dict(rites=dict(invocation={})))
        view['data']['neutral_tears'] = 8
        result = protection_projection(Facts(view), plan, 8)
        self.assertEqual([], result['changes']); self.assertEqual(0, result['score'])
        self.assertEqual('unknown', result['future_arrival_identity']); self.assertIn(9, result['pending_thresholds'])
        view['data']['veil_breaches']['arrivals'] = [dict(lord_id='Kanifous', protection=0, threshold=21, round=21, veil=21)]
        self.assertEqual([], protection_projection(Facts(view), plan, 8)['changes'])
        view['data']['veil_breaches']['arrivals'][0]['protection'] = 1
        view['data']['breach_lord'] = 'Kanifous'
        self.assertEqual([], protection_projection(Facts(view), plan, 8)['changes'])
        view['data']['breach_lord'] = ''; view['players'][0]['resources']['personal_tears'] = 1
        self.assertEqual([], protection_projection(Facts(view), plan, 8)['changes'])

    def test_projection_charges_known_costs_and_keeps_victory_precedence(self):
        view = observe(planning('Odradek'), 0)
        view['players'][0]['resources']['souls'] = 12
        view['players'][0]['resources']['reconfiguration'] = 4
        plan = dict(powers=[declaration(0, 1, 'Inversion')], order=dict(rites=dict(profane_ruins=dict(castle_id='fixture'))))
        scenario = paid_scenario(Facts(view), plan)
        self.assertEqual(0, scenario['players'][0]['resources']['reconfiguration'])
        self.assertEqual(10, scenario['players'][0]['resources']['souls'])
        self.assertEqual(-1, settlement_projection(Facts(view), plan)['winner'])
        self.assertEqual(12, view['players'][0]['resources']['souls'])

    def test_recipe_scores_are_registry_order_independent_and_use_no_future_rolls(self):
        view = observe(planning('Valak'), 0)
        hand(view, [('Wright', 2)]*3+[('Vulture', 1)]*2+[('Butcher', 3)]*3+[('Penitent', 2)]*2)
        policy = CommonSmartCore(); first = policy.decide(view, lambda plan: dict(action='legal'))
        view['hand'].reverse(); view['board'].reverse()
        self.assertEqual(first, policy.decide(view, lambda plan: dict(action='legal')))

    def test_inferno_relocation_respects_fire_round_and_flying_monsters(self):
        from .kalligan_tactics import forecast
        view = observe(planning('Kalligan'), 0)
        source = dict(player_id=0, power_id='Inferno')
        view['persistent'] = [dict(declaration=source, activated_round=2, stages=[{}, {}, {}])]
        view['cooldowns'] = [dict(declaration=source, phase='awaiting_expiration')]
        view['round'] = 3
        self.assertEqual((True, 'relocation_available'), Facts(view).available('Inferno'))
        view['round'] = 4
        self.assertEqual((False, 'relocation_would_fire_after_expiration'), Facts(view).available('Inferno'))
        view['board'].append(dict(id='flying-enemy', kind='marcher', owner=1,
                                 attributes=monsters.profile('Fyra', 'Lord', 1, 1, 2)))
        self.assertEqual(0, forecast(Facts(view), dict(kind='lane', lane='Lord'), [(0,2)])['score'])


if __name__ == '__main__': unittest.main()
