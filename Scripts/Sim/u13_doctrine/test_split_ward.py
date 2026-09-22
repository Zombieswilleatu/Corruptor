"""Contracts for the opt-in dual commitment experiment."""
from collections import Counter
import unittest

from u13_pysim import economy as e, full_match_inputs, split_ward, recruitment, monsters
from u13_pysim.copying import copy_data
from u13_pysim.lord_hooks import LordRoundRules
from u13_pysim.power_match import PowerMatch
from .common import CommonSmartCore
from .facts import Facts
from .observation import observe, Preview
from .test_common import planning
from . import test_ward_recipes as ward_tests


class SplitWardTests(unittest.TestCase):
    def fixture(self):
        game, recipe = ward_tests.WardRecipeTests().fixture()
        split_ward.configure(game._state['world'])
        f = Facts(observe(game, 0))
        _, lane, target = next(f.attack_targets())
        spare = [r['id'] for r in f.hand if r['id'] not in recipe]
        self.assertTrue(spare)
        order = dict(action='Hunt', lane=lane, target_id=target, card_ids=recipe,
                     monster_choice='Lemek', ward=dict(action='Ward', lane='Castle', card_ids=spare[:1]))
        return game, order

    def test_roster_screen_is_fresh_balanced_and_tempo_only(self):
        from run_u13_split_ward_experiment import specs, NAMESPACE
        rows = list(specs(roster_screen=True))
        self.assertEqual(len(rows), 162)
        self.assertEqual(len({r['name'] for r in rows}), 162)
        lookup = {(tuple(r['setup']['lords']), r['repeat']): r for r in rows}
        for row in rows:
            setup = row['setup']
            self.assertEqual(row['arm'], 'tempo')
            self.assertEqual(setup['tempo_experiment'], 'U13_VEIL_ATTACK_ROUND25_V1')
            self.assertEqual(setup['ward_experiment'], 'U13_SPLIT_WARD_V1')
            self.assertNotIn('decisive_soul_bonus', setup)
            self.assertFalse(setup['seed'].startswith(NAMESPACE))
            reverse = lookup[(tuple(reversed(setup['lords'])), row['repeat'])]
            self.assertEqual(setup['seed'], reverse['setup']['seed'])

    def test_admission_and_rollback_cover_every_shared_card_budget(self):
        game, order = self.fixture()
        self.assertEqual('legal', Preview(game, 0)(dict(powers=[], order=order))['action'])
        bad = []
        duplicate = copy_data(order); duplicate['ward']['card_ids'] = order['card_ids'][:1]; bad.append(duplicate)
        monster = copy_data(order); monster['ward']['monster_choice'] = 'Lemek'; bad.append(monster)
        empty = copy_data(order); empty['ward']['card_ids'] = []; bad.append(empty)
        twice = copy_data(order); twice['ward']['ward'] = copy_data(order['ward']); bad.append(twice)
        for key, payload in (
            ('guard_moves', [dict(card_id=order['ward']['card_ids'][0], lane='Lord', slot=0)]),
            ('summon', dict(card_ids=order['ward']['card_ids'])),
            ('rites', dict(invocation=dict(card_ids=order['ward']['card_ids']))),
            ('castle_action', dict(action='Work', target_id='', card_ids=order['ward']['card_ids'], use_repair_token=False))):
            altered = copy_data(order); altered[key] = payload; bad.append(altered)
        for altered in bad:
            before = game.snapshot()
            self.assertEqual('invalid', game.apply(dict(kind='submit_one', player_id=0,
                plan=dict(powers=[], order=altered)))['action'], altered)
            self.assertEqual(before, game.snapshot())

    def test_split_recruitment_unique_ids_no_sigils_and_only_attack_monster(self):
        game, order = self.fixture()
        f = Facts(observe(game, 0))
        expected = f.recruits(order['card_ids'], 'Hunt')+f.recruits(order['ward']['card_ids'], 'Ward')
        events = ward_tests.WardRecipeTests().reveal(game, order)
        normals = [r['data'] for r in events if r['type'] == 'MARCHER_SPAWNED'
                   and r['data']['owner'] == 0 and 'monster_id' not in r['data']['attributes']]
        self.assertEqual(expected, len(normals))
        self.assertEqual(len(normals), len({r['id'] for r in normals}))
        self.assertEqual(['Lemek'], [r['data']['monster_id'] for r in events if r['type'] == 'MONSTER_SUMMONED'])
        self.assertFalse(any(r['type'].startswith('SIGIL_') for r in events))
        self.assertEqual([dict(Lord='', Castle='')]*2, game._state['world']['data']['sigils'])
        committed = e.zones(game._state['world'])['committed'][0]
        self.assertEqual(set(order['card_ids']+order['ward']['card_ids']), set(committed))

    def battle(self, attack_strength=6, lane='Lord', guard=False, split=False):
        game, order = self.fixture()
        w = game._state['world']
        # A small deterministic board: no castles, guards or waiters.
        w['entities']['entities'] = [r for r in w['entities']['entities'] if r['kind'] in ('lord', 'card')]
        for r in w['entities']['entities']:
            if r['kind'] == 'lord': r['attributes']['threat'] = 0
        ids = order['card_ids']
        attacker = e.entity(w, ids[0]); attacker['attributes'].update(suit='Butcher', value=attack_strength)
        defender = e.entity(w, ids[1]); defender['attributes'].update(suit='Penitent', value=4)
        attack = dict(action='Hunt', lane='Lord', card_ids=[attacker['id']], target_id=w['players'][1]['lord_entity_id'])
        ward = dict(action='Ward', lane=lane, card_ids=[defender['id']])
        if guard:
            row = copy_data(defender); row['id'] = 'fixture-guard'; row['owner'] = 1
            row['attributes'].update(role='guard', lane='Lord', slot=0, value=9)
            w['entities']['entities'].append(row)
        rules = LordRoundRules(w, 1, 'split-ward-test', [0, 1], 'combat_resolution', [])
        rules.orders = [attack, dict(action='Siege', lane='Castle', target_id='castle_zone:0',
                                    card_ids=[], ward=ward) if split else ward]
        w['data']['plunder'].update(resolved_round=1, results=[None, None])
        return rules, attack

    def test_soul_only_when_lane_ward_changes_success_and_never_twice(self):
        for split in (False, True):
            for strength, lane, guard, reward, banished in (
                (6, 'Lord', False, 1, False), (3, 'Lord', False, 0, False),
                (6, 'Lord', True, 0, False), (12, 'Lord', False, 0, True),
                (6, 'Castle', False, 0, True)):
                rules, attack = self.battle(strength, lane, guard, split)
                events = split_ward.resolve_attack(rules, 0, attack)
                self.assertEqual(reward, sum(r['event']['type'] == 'WARD_SOUL_GAINED' for r in events))
                self.assertEqual(banished, split_ward.succeeded(events))
        rules, attack = self.battle()
        rules.w['data']['ward_reward_rounds'] = [0, 1]
        events = split_ward.resolve_attack(rules, 0, attack)
        self.assertFalse(any(r['event']['type'] == 'WARD_SOUL_GAINED' for r in events))

    def test_pillage_reward_and_no_sigils_even_if_old_fields_are_present(self):
        rules, attack = self.battle(3, 'Castle')
        attack.update(action='Siege', lane='Castle', target_id='castle_zone:1')
        rules.w['data']['sigils'][1]['Castle'] = 'fresh'
        self.assertEqual((3, '', False), rules.sigil(1, 'Castle', 3))
        events = split_ward.resolve_attack(rules, 0, attack)
        self.assertEqual(1, sum(r['event']['type'] == 'WARD_SOUL_GAINED' for r in events))
        self.assertFalse(split_ward.succeeded(events))

    def test_siege_reward_requires_target_save_not_just_reduced_damage(self):
        for integrity, reward in ((5, 1), (9, 0), (1, 0)):
            rules, attack = self.battle(6, 'Castle')
            original = planning()._state['world']
            castle = copy_data(next(r for r in original['entities']['entities']
                if r['kind'] == 'castle' and r['owner'] == 1
                and r['attributes']['castle_type'] == 'Stockpile'))
            castle['attributes'].update(integrity=integrity, status='standing', construction_state='active')
            rules.w['entities']['entities'].append(castle)
            attack.update(action='Siege', lane='Castle', target_id=castle['id'])
            events = split_ward.resolve_attack(rules, 0, attack)
            self.assertEqual(reward, sum(r['event']['type'] == 'WARD_SOUL_GAINED' for r in events))

    def test_existing_field_and_staged_monsters_remain_usable(self):
        from u13_pysim import game_staging
        game, order = self.fixture()
        w = game._state['world']
        existing = recruitment.create(w, 'split-existing', 0, 0,
            monsters.profile('Kopita', 'Lord', 0, 0, 1))
        existing_id = existing['id']
        game_staging.configure(w)
        staged = recruitment.create(w, 'split-staged', 0, 0,
            monsters.profile('Fyra', 'Castle', 0, 0, 1))
        staged['attributes']['staged_round'] = 0
        w['entities']['entities'].remove(staged)
        w['data']['game_staging']['lanes']['Castle']['units'].append(staged)
        order['staging'] = {'Castle': 'March'}
        ward_tests.WardRecipeTests().reveal(game, order)
        w = game._state['world']
        self.assertEqual('Kopita', e.entity(w, existing_id)['attributes']['monster_id'])
        # Release uses the ordinary staging authority, independent of commitments.
        game_staging.prepare(w, 1, [order, {}])
        game_staging.prepare(w, 2, [{}, {}])
        self.assertEqual('Fyra', e.entity(w, staged['id'])['attributes']['monster_id'])

    def test_all_lords_offer_legal_bounded_split_plans_without_mutating_preview(self):
        from u13_pysim.power_match import LORDS
        for lord in LORDS:
            game = planning(lord); split_ward.configure(game._state['world'])
            before = game.snapshot(); view = observe(game, 0)
            seen = []
            def preview(plan):
                seen.append(copy_data(plan))
                return Preview(game, 0)(plan)
            decision = CommonSmartCore().decide(view, preview)
            self.assertEqual(before, game.snapshot())
            self.assertEqual([], decision['rejected_previews'], lord)
            self.assertGreater(decision['split_ward']['candidates'], 0, lord)
            self.assertLessEqual(decision['budget']['used']['complete_plans'], 32)
            self.assertEqual(decision, CommonSmartCore().decide(view, Preview(game, 0)))
            self.assertEqual('legal', Preview(game, 0)(decision['plan'])['action'])

    def test_setup_opt_in_preserves_optimized_match_and_unknown_profile_fails(self):
        setup = dict(full_match_inputs.load()['cases'][0]['setup'], ward_experiment=split_ward.VERSION)
        game = PowerMatch(setup)
        self.assertTrue(split_ward.enabled(game._state['world']))
        self.assertTrue(game._rollback_snapshot().shared)
        before = game.snapshot()
        game.apply(dict(kind='step', hook=game.clock.hook))
        self.assertNotEqual(before, game.snapshot())
        with self.assertRaises(ValueError): PowerMatch(dict(setup, ward_experiment='typo'))

    def test_decisive_hunt_bonus_real_success_only_and_capped(self):
        for strength, expected in ((6, 0), (12, 1)):
            rules, attack = self.battle(strength)
            rules.w['data']['decisive_soul_bonus'] = True
            before = rules.w['players'][0]['resources']['souls']
            events = split_ward.resolve_attack(rules, 0, attack)
            self.assertEqual(expected, sum(r['event']['type'] == 'DECISIVE_SOUL_GAINED' for r in events))
            self.assertEqual(before+3*expected, rules.w['players'][0]['resources']['souls'])
            after = copy_data(rules.w)
            split_ward.reward_breakthrough(rules, 0, events)
            self.assertEqual(after, rules.w)

    def test_bonus_excludes_pillage_and_siege_damage_but_pays_target_destruction(self):
        for pillage, integrity, expected in ((True, 0, 0), (False, 9, 0), (False, 1, 1)):
            rules, attack = self.battle(6, 'Castle')
            rules.w['data']['decisive_soul_bonus'] = True
            attack.update(action='Siege', lane='Castle', target_id='castle_zone:1')
            if not pillage:
                castle = copy_data(next(r for r in planning()._state['world']['entities']['entities']
                    if r['kind'] == 'castle' and r['owner'] == 1 and r['attributes']['castle_type'] == 'Stockpile'))
                castle['attributes'].update(integrity=integrity, status='standing', construction_state='active')
                rules.w['entities']['entities'].append(castle)
                attack['target_id'] = castle['id']
            events = split_ward.resolve_attack(rules, 0, attack)
            self.assertEqual(expected, sum(r['event']['type'] == 'DECISIVE_SOUL_GAINED' for r in events))

    def test_bonus_profile_validation_and_three_arm_pairing(self):
        setup = dict(full_match_inputs.load()['cases'][0]['setup'])
        with self.assertRaises(ValueError): PowerMatch(dict(setup, decisive_soul_bonus=True))
        with self.assertRaises(ValueError):
            PowerMatch(dict(setup, ward_experiment=split_ward.VERSION, decisive_soul_bonus=1))
        game = PowerMatch(dict(setup, ward_experiment=split_ward.VERSION, decisive_soul_bonus=True))
        self.assertTrue(game._rollback_snapshot().shared)
        from run_u13_split_ward_experiment import specs
        for full, total in ((False, 18), (True, 243)):
            cases = list(specs(full))
            self.assertEqual(total, len(cases))
            for i in range(0, total, 3):
                group = cases[i:i+3]
                self.assertEqual(['current', 'split', 'bonus'], [s['arm'] for s in group])
                self.assertEqual(1, len({s['setup']['seed'] for s in group}))
                self.assertEqual(group[0]['setup']['lords'], group[2]['setup']['lords'])

    def test_tempo_thresholds_flat_attack_bonus_and_round25_priority(self):
        from u13_pysim.lifecycle import evaluate
        rules, attack = self.battle(6)
        w = rules.w; w['data']['tempo_experiment'] = split_ward.TEMPO
        for player in w['players']:
            player['resources'].update(souls=0, personal_tears=0)
        for value, expected in ((12, 0), (13, 1), (16, 1), (17, 2), (20, 2), (21, 3), (40, 3)):
            w['data']['neutral_tears'] = value
            self.assertEqual(expected, split_ward.attack_bonus(w))
            # No waiters/pursuit: one flat increase, regardless of printed strength.
            strength, _, _, _, _ = rules.attack_layers(0, attack, attack['target_id'])
            self.assertEqual(6+expected, strength)
        self.assertEqual(-1, evaluate(w, 24)['winner'])
        self.assertEqual('RoundLimit', evaluate(w, 25)['win_by'])
        w['players'][1]['resources']['souls'] = 7
        self.assertEqual(1, evaluate(w, 25)['winner'])
        w['players'][0]['resources']['personal_tears'] = 5
        self.assertEqual('Dominion', evaluate(w, 25)['win_by'])
        w['players'][1]['resources']['souls'] = 12
        self.assertEqual('Ritual', evaluate(w, 25)['win_by'])

    def test_tempo_bonus_starts_round20_and_planner_knows_new_settlement(self):
        from .veil_judgment import settlement_projection
        rules, attack = self.battle()
        rules.w['data']['tempo_experiment'] = split_ward.TEMPO
        for number, expected in ((19, 0), (20, 1)):
            rules.number = number
            events = [e.event('HUNT_RESOLVED', dict(banished=True, target_id=attack['target_id']))]
            split_ward.reward_breakthrough(rules, 0, events)
            self.assertEqual(expected, sum(r['event']['type'] == 'DECISIVE_SOUL_GAINED' for r in events))
        game, _ = self.fixture()
        game._state['world']['data']['tempo_experiment'] = split_ward.TEMPO
        view = observe(game, 0); view['data']['neutral_tears'] = 40
        for p in view['players']: p['resources'].update(souls=0, personal_tears=0)
        for number, ending in ((24, ''), (25, 'RoundLimit')):
            view['round'] = number
            self.assertEqual(ending, settlement_projection(Facts(view), dict(powers=[], order={}))['win_by'])
        from run_u13_split_ward_experiment import specs
        cases = list(specs(tempo=True))
        self.assertEqual(18, len(cases))
        self.assertEqual({'split', 'bonus', 'tempo'}, {s['arm'] for s in cases})


if __name__ == '__main__': unittest.main()


class TempoClosingTests(unittest.TestCase):
    def test_banished_ritual_projection_before_and_at_deadline(self):
        from .closing import judgment
        from .veil_judgment import settlement_projection
        game = planning()
        game._state['world']['data']['tempo_experiment'] = split_ward.TEMPO
        view = observe(game, 0)
        for player in view['players']: player['resources'].update(souls=0, personal_tears=0)
        view['players'][0]['resources']['souls'] = 12
        view['data']['neutral_tears'] = 30
        plan = dict(powers=[], order={})
        for number in (19, 25):
            view['round'] = number
            f = Facts(view)
            result = judgment(f, plan, settlement_projection(f, plan))
            hunts = [r for r in result['checks'] if r['name'] == 'hunt_reward']
            self.assertEqual('' if number == 19 else 'RoundLimit', hunts[0]['win_by'])
