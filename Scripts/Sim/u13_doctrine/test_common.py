import json
from pathlib import Path
import unittest
from unittest.mock import patch

from u13_pysim import economy, full_match_inputs, power_components, power_inputs
from u13_pysim.copying import copy_data
from u13_pysim.power_match import PowerMatch
from u13_pysim.power_rules import RULES, declaration
from . import lords
from .budget import Limits
from .common import CommonSmartCore, Weights, settlement_projection
from .facts import Facts, power
from .observation import observe, Preview
from .planner_probe import PlannerObserver, compare_reports
from .diagnostics import fingerprint


def planning(lord='Gremory'):
    setup = dict(full_match_inputs.load()['cases'][0]['setup'], lords=[lord, 'Gremory'])
    game = PowerMatch(setup)
    while game.clock.hook != 'submission_lock':
        result = game.apply(full_match_inputs.next_operation(game))
        if result['action'] == 'invalid': raise AssertionError(result)
    return game


class CommonTests(unittest.TestCase):
    def test_every_lord_has_separate_module_and_legal_deterministic_opening(self):
        self.assertEqual(9, len(lords.MODULES))
        for lord, module in lords.MODULES.items():
            with self.subTest(lord=lord):
                self.assertTrue(module.__file__.endswith(lord.lower()+'.py'))
                game = planning(lord); before = game.snapshot(); view = observe(game, 0)
                first = CommonSmartCore().decide(view, Preview(game, 0))
                self.assertEqual(first, CommonSmartCore().decide(view, Preview(game, 0)))
                self.assertEqual(before, game.snapshot())
                self.assertEqual('legal', Preview(game, 0)(first['plan'])['action'])
                for name, count in first['budget']['used'].items():
                    limit = 16 if name.startswith('generated:') else 4 if name.startswith('retained:') else 32 if name == 'complete_plans' else 8
                    self.assertLessEqual(count, limit)

    def test_observation_hides_seeds_enemy_cards_orders_and_future_randomness(self):
        game = planning(); original = observe(game, 0)
        choice = CommonSmartCore().decide(original, Preview(game, 0))
        game._state['seed'] = 'private changed seed'
        game._state['world']['data']['card_zones']['deck'].reverse()
        game._state['submissions'][1] = [dict(secret='different hidden plan')]
        game._state['combat_orders'][1] = dict(secret='different hidden attack')
        keys = game._state['world']['data']['card_zones']['hands'][1]
        for row in game._state['world']['entities']['entities']:
            if row['id'] in keys: row['attributes']['value'] = 1
        self.assertEqual(original, observe(game, 0))
        self.assertEqual(choice, CommonSmartCore().decide(observe(game, 0), Preview(game, 0)))
        text = json.dumps(original)
        for key in ('private changed seed', 'different hidden', 'card_zones', 'used_ids'):
            self.assertNotIn(key, text)
        altered = observe(game, 0); altered['players'][0]['resources']['souls'] = 500
        self.assertNotEqual(altered, observe(game, 0))

    def test_preview_rejection_cannot_reserve_payment_or_mutate_authority(self):
        game = planning(); before = game.snapshot(); session = Preview(game, 0)
        self.assertEqual('invalid', session(dict(powers=[], order=dict(guard_moves=[dict(card_id='missing', lane='Lord', slot=0)])))['action'])
        self.assertEqual('legal', session(dict(powers=[], order={} ))['action'])
        self.assertEqual(before, game.snapshot())

    def test_generation_reserves_before_next_candidate_and_never_enumerates_product(self):
        built = []
        def source(f):
            while True:
                built.append(1)
                yield power('PredatorOfRuin', dict(lane='Lord'), len(built), 'instrumented')
        game = planning()
        with patch('u13_doctrine.common.lords.proposals', source):
            result = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertEqual(16, len(built))
        self.assertLessEqual(result['budget']['used']['complete_plans'], 32)
        self.assertEqual(16, next(a for a in result['assessments'] if a['term'] == 'PredatorOfRuin')['generated'])

    def test_all_invalid_previews_fail_visibly_without_silent_pass(self):
        calls = []
        def invalid(plan):
            calls.append(plan); return dict(action='invalid', reason='deliberate')
        with self.assertRaisesRegex(ValueError, 'No admitted plan'):
            CommonSmartCore().decide(observe(planning(), 0), invalid)
        self.assertTrue(0 < len(calls) <= 8)

    def test_all_powers_have_bounded_legal_proposals_in_favorable_components(self):
        seen = set()
        # Favorable fixtures follow current tuning; historical replay inputs
        # can contain healing targets above a subsequently lowered ceiling.
        for case in power_components.generate():
            if not case['name'].startswith('power_'): continue
            name = case['name'][6:]; game = PowerMatch(case['setup'])
            for entry in case['operations']:
                op = entry['operation']
                found = op['kind'] == 'submit' and any(s['power_id'] == name for plan in op['plans'] for s in plan['powers'])
                if found and not entry['rejected']:
                    # Favorable field preparation is explicit and separate from
                    # complete games. Remove allied exposure to area attacks.
                    own = [r['id'] for r in game._state['world']['entities']['entities'] if r['kind'] == 'marcher' and r['owner'] == 0]
                    if own and name.removeprefix('Breach') in ('Inferno', 'Pyroclasm', 'Redirect', 'GravityOrb', 'Ravenous', 'WishDeath'):
                        power_components.prepare(game, [dict(kind='fixture_retire', entity_id=k) for k in own])
                    if name.removeprefix('Breach') == 'WishWealth':
                        # A draw wish is useful with actual hand space.
                        w = game._state['world']
                        economy.discard(w, 0, w['data']['card_zones']['hands'][0][3:])
                        game._state['presentation_world'] = copy_data(w)
                    if name.removeprefix('Breach') == 'WishLongevity':
                        # One missing HP is legal but not worth a Wish's Price.
                        source = next(s for plan in op['plans'] for s in plan['powers'] if s['power_id'] == name)
                        power_components.prepare(game, [dict(kind='fixture_patch', entity_id=source['target']['entity_id'], attributes=dict(integrity=3))])
                    view = observe(game, 0)
                    proposals = [p for p in lords.proposals(Facts(view)) if p.term == name]
                    self.assertTrue(proposals, name)
                    legal = False
                    for p in proposals:
                        source = declaration(0, game.clock.round, name, p.payload['target'], discard_ids=list(p.cards) if p.cards else None,
                                             parameters=p.payload['parameters'])
                        legal |= Preview(game, 0)(dict(powers=[source], order={}))['action'] == 'legal'
                    self.assertTrue(legal, name); seen.add(name); break
                result = power_components.apply(game, op)
                self.assertEqual(entry['rejected'], result['action'] == 'invalid', case['name'])
        self.assertEqual(set(RULES), seen)

    def test_projection_spends_minimum_and_cannot_target_unaffordable_guard(self):
        game = planning('Valak'); w = game._state['world']
        card = next(r for r in w['entities']['entities'] if r['kind'] == 'card' and r['attributes']['value'] == 2)
        power_components.prepare(game, [dict(kind='fixture_guard', card_id=card['id'], player_id=1, lane='Lord', slot=0),
                                       dict(kind='fixture_resources', player_id=0, resources=dict(life_essence=5))])
        choices = list(lords.proposals(Facts(observe(game, 0))))
        self.assertEqual([2], [p.payload['parameters']['spend'] for p in choices if p.term == 'Projection'])
        w['players'][0]['resources']['life_essence'] = 1
        # Preparation can replace world storage; use the owned world explicitly.
        game._state['world']['players'][0]['resources']['life_essence'] = 1
        self.assertFalse(any(p.term == 'Projection' for p in lords.proposals(Facts(observe(game, 0)))))

    def test_empty_area_powers_are_not_generated_and_debt_reduces_wish_value(self):
        for lord in ('Valak', 'Kroni', 'Odradek', 'Kalligan'):
            game = planning(lord)
            view = observe(game,0)
            if lord == 'Kalligan':
                # Empty lanes still leave exposed Castles as useful targets.
                view['board'] = [r for r in view['board'] if r['kind'] != 'castle' or r['owner'] == 0]
            self.assertFalse(list(lords.proposals(Facts(view))), lord)
        view = observe(planning('Kanifous'), 0)
        initial = {fingerprint(p.payload): p.value for p in lords.proposals(Facts(view)) if p.term == 'WishPower'}
        view['data']['kanifous_prices'].append(dict(owner=0))
        later = {fingerprint(p.payload): p.value for p in lords.proposals(Facts(view)) if p.term == 'WishPower'}
        self.assertTrue(all(later[k] == v-10 for k, v in initial.items()))

    def test_odradek_saves_for_visible_cluster_instead_of_spending_each_single_point(self):
        game = planning('Odradek')
        changes = [dict(kind='fixture_resources', player_id=0, resources=dict(reconfiguration=1))]
        for i in range(3):
            changes.append(dict(kind='fixture_marcher', player_id=1, lane='Lord', origin='saving', ordinal=i,
                                attributes=dict(x_fp=1200, y_fp=200+i*30)))
        power_components.prepare(game, changes)
        candidates = list(lords.proposals(Facts(observe(game, 0))))
        redirect = next(p for p in candidates if p.term == 'Redirect')
        self.assertEqual(0,redirect.value)
        self.assertEqual('redirect_only_relocates_pressure',redirect.reason)
        result = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertEqual([], result['plan']['powers'])
        self.assertEqual('AllegianceShift', result['resource_horizon']['selected']['goal']['power'])
        game._state['world']['players'][0]['resources']['reconfiguration'] = 3
        game._state['presentation_world'] = copy_data(game._state['world'])
        result = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertIn('AllegianceShift', [p['power_id'] for p in result['plan']['powers']])

    def test_shared_veil_never_creates_a_blanket_hunt_veto(self):
        view = observe(planning('Orias'), 0)
        view['players'][1]['resources']['personal_tears'] = 5
        view['data']['neutral_tears'] = 7
        result = CommonSmartCore().decide(view, lambda plan: dict(action='legal'))
        self.assertFalse(result['veil']['hard_veto'])
        self.assertGreater(next(a for a in result['assessments'] if a['term'] == 'Hunt')['generated'], 0)

    def test_static_settlement_respects_ritual_collapse_and_round_pressure(self):
        view = observe(planning(), 0)
        view['players'][1]['resources']['personal_tears'] = 5
        view['data']['neutral_tears'] = 6
        plan = dict(powers=[], order=dict(rites=dict(invocation=dict(card_ids=[]))))
        self.assertEqual(dict(winner=1, win_by='Dominion'), settlement_projection(Facts(view), plan))
        view['players'][0]['resources']['souls'] = 12
        self.assertEqual(dict(winner=0, win_by='Ritual'), settlement_projection(Facts(view), plan))
        view['players'][0]['resources']['souls'] = 3
        view['data']['neutral_tears'] = 19; view['round'] = 13
        self.assertEqual(dict(winner=0, win_by='FinalCollapse'), settlement_projection(Facts(view), plan))

    def test_public_guard_equality_blocks_and_broken_pair_does_not_screen(self):
        view = observe(planning(), 0)
        enemy = dict(id='visible_guard', kind='card', owner=1,
                     attributes=dict(role='guard', suit='Penitent', lane='Castle', slot=0, value=3))
        view['board'].append(enemy)
        for row in view['board']:
            if row['kind'] == 'castle' and row['owner'] == 1: row['attributes']['status'] = 'ruined'
        view['hand'] = [dict(id='attack',kind='card',owner=0,attributes=dict(suit='Butcher',value=3))]
        self.assertFalse(Facts(view).attack('Siege', 'castle_zone:1', ['attack'])['pillage'])
        view['hand'][0]['attributes']['value'] = 4
        self.assertTrue(Facts(view).attack('Siege', 'castle_zone:1', ['attack'])['pillage'])
        view['data']['guard_work']['pairs'] = [dict(active=True, player_id=1, lane='Castle', suit='Penitent',
                                                  ids=['visible_guard', 'gone'], slots=[0, 1])]
        self.assertTrue(Facts(view).attack('Siege', 'castle_zone:1', ['attack'])['pillage'])

    def test_weights_and_lord_ablation_are_external_and_reproducible(self):
        game = planning(); view = observe(game, 0)
        off = CommonSmartCore(lord_modules=False).decide(view, Preview(game, 0))
        self.assertEqual([], off['plan']['powers'])
        self.assertTrue(all(a['opportunity'] is None for a in off['assessments'] if a['category'] == 'powers'))
        with self.assertRaises(ValueError): Weights(card_cost=1.5)
        costly = CommonSmartCore(Weights(card_cost=10000)).decide(view, Preview(game, 0))
        self.assertEqual([], costly['plan']['order'].get('card_ids', []))

    def test_slaver_does_not_count_the_given_card_as_a_new_pair(self):
        view = observe(planning(), 0)
        view['hand'] = [dict(id='owned', attributes=dict(suit='Butcher', value=3))]
        view['market'] = [dict(id='offered', attributes=dict(suit='Butcher', value=2))]
        choice = CommonSmartCore().choose_card(view, 'slaver')
        self.assertEqual('Pass', choice['operation']['choice']['market'])
        view['market'][0]['attributes']['value'] = 5
        self.assertEqual('Swap', CommonSmartCore().choose_card(view, 'slaver')['operation']['choice']['market'])

    def test_delayed_power_outcome_attaches_to_original_choice(self):
        game = planning(); decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        observer = PlannerObserver(dict(name='delayed', setup=dict(lords=['Gremory', 'Gremory'])))
        observer.accepted(1, 0, decision)
        source = decision['plan']['powers'][0]
        event = dict(type='POWER_RESOLVED', data=dict(declaration_id=source['declaration_id'], round=2))
        observer.event(90, event, 2); observer.event(90, event, 2)
        group = next(g for g in observer.report()['groups'] if g['category'] == 'powers' and g['term'] == source['power_id'])
        self.assertEqual(1, group['outcomes']['resolved'])
        self.assertEqual(0, group['effect_records'])

    def breach_planning(self):
        game = planning('Deimos')
        world = game._state['world']
        world['data']['neutral_tears'] = 5
        world['data']['veil_breaches'].update(checked_round=1, arrivals=[
            dict(lord_id='Kanifous', threshold=5, protection=1, round=1, veil=5)])
        castle = next(r for r in world['entities']['entities']
                      if r['kind'] == 'castle' and r['owner'] == 0
                      and r['attributes']['castle_type'] == 'Keep')
        castle['attributes']['integrity'] = 1
        game._state['presentation_world'] = copy_data(world)
        return game, castle['id']

    def test_breach_wish_records_selection_resolution_and_heavier_price(self):
        game, _ = self.breach_planning()
        decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertEqual(['BreachWishLongevity'], [p['power_id'] for p in decision['plan']['powers']])
        result = game.apply(dict(kind='submit', plans=[decision['plan'], dict(powers=[], order={})]))
        self.assertNotEqual('invalid', result['action'])
        observer = PlannerObserver(dict(name='breach-diagnostics', setup=dict(lords=['Deimos', 'Gremory'])))
        observer.accepted(1, 0, decision)
        cursor = len(game._state['events']['rows'])
        while game.clock.hook != 'post_resolution_direct':
            self.assertNotEqual('invalid', game.apply(dict(kind='step', hook=game.clock.hook))['action'])
        self.assertNotEqual('invalid', game.apply(dict(kind='step', hook=game.clock.hook))['action'])
        for i, row in enumerate(game._state['events']['rows'][cursor:], cursor):
            observer.event(i, row['event'], 1)
        source = decision['plan']['powers'][0]
        price = next(p for p in game._state['world']['data']['kanifous_prices'] if p['owner'] == 0)
        self.assertTrue(price['breach'])
        self.assertEqual(observer.declarations[source['declaration_id']], observer.prices[price['id']])
        # Collection can occur later; it must retain the original Breach selection.
        observer.event(100000, dict(type='KANIFOUS_PRICE_RESOLVED',
            data=dict(id=price['id'], outcome='Cards', round=price['due_round'])), price['due_round'])
        group = next(g for g in observer.report()['groups'] if g['term'] == 'BreachWishLongevity')
        self.assertEqual(1, group['flags']['selected']['true'])
        self.assertEqual(1, group['outcomes']['resolved'])
        self.assertEqual(1, group['metrics']['wish_success'])
        self.assertEqual(1, group['metrics']['price_cards'])

    def test_breach_wish_limit_is_enforced_before_authoritative_preview(self):
        game, castle = self.breach_planning()
        previews = []
        authority = Preview(game, 0)
        def preview(plan):
            previews.append(copy_data(plan))
            return authority(plan)
        def proposals(_facts):
            yield power('BreachWishLongevity', dict(entity_id=castle), 100, 'directed_healing')
            yield power('BreachWishPower', dict(lane='Lord'), 90, 'directed_recruitment')
        with patch('u13_doctrine.common.lords.proposals', proposals):
            decision = CommonSmartCore().decide(observe(game, 0), preview)
        self.assertTrue(previews)
        self.assertTrue(all(len(p['powers']) <= 1 for p in previews))
        self.assertEqual([], decision['rejected_previews'])

    def test_breach_assessments_cover_all_lords_and_protection(self):
        for lord in lords.MODULES:
            with self.subTest(lord=lord):
                game = planning(lord)
                decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
                terms = {a['term'] for a in decision['assessments'] if a['category'] == 'powers'}
                self.assertEqual({p for p, rules in RULES.items() if rules.get('breach_wish')},
                                 {p for p in terms if p.startswith('BreachWish')})
        game, _ = self.breach_planning()
        game._state['world']['players'][1]['resources']['personal_tears'] = 1
        game._state['presentation_world'] = copy_data(game._state['world'])
        decision = CommonSmartCore().decide(observe(game, 0), Preview(game, 0))
        self.assertFalse(any(p['power_id'].startswith('BreachWish') for p in decision['plan']['powers']))

    def test_cross_runtime_comparison_rejects_rehashed_changed_decisions(self):
        semantic = dict(failures=0, choices=['Hunt'])
        a = dict(source_revision='r', engine_source_sha256='e', harness_source_sha256='h', runner_source_sha256='s',
                 semantic=semantic, semantic_sha256=fingerprint(semantic), tests_passed=1)
        b = copy_data(a); b['semantic']['choices'] = ['Ward']; b['semantic_sha256'] = fingerprint(b['semantic'])
        with self.assertRaises(ValueError): compare_reports(a, b)


if __name__ == '__main__': unittest.main()
