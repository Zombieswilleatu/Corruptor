"""Ward defense/recruitment, attack recipes, and existing monster contracts."""
from collections import Counter
import unittest

from u13_pysim import economy, full_match_inputs, game_staging, monsters, power_components, recruitment
from u13_pysim.copying import copy_data
from .common import Weights
from .facts import Facts, Proposal
from .observation import observe, Preview
from .recipes import Recipes
from .test_common import planning


class WardRecipeTests(unittest.TestCase):
    def fixture(self, name='Lemek'):
        game = planning('Deimos')
        world = game._state['world']
        ids = []
        for suit, count in monsters.ROSTER[name]['recipe'].items():
            cards = sorted((r for r in world['entities']['entities']
                            if r['kind'] == 'card' and r['attributes']['suit'] == suit),
                           key=lambda r: (r['attributes']['value'], r['id']))
            ids.extend(r['id'] for r in cards[:count])
        power_components.prepare(game, [dict(kind='fixture_give', player_id=0, card_id=k) for k in ids])
        game._state['presentation_world'] = copy_data(game._state['world'])
        return game, ids

    def reveal(self, game, order):
        result = game.apply(dict(kind='submit', plans=[dict(powers=[], order=order), dict(powers=[], order={})]))
        self.assertNotEqual('invalid', result['action'], result)
        start = len(game._state['events']['rows'])
        while game.clock.hook != 'combat_resolution':
            result = game.apply(full_match_inputs.next_operation(game))
            self.assertNotEqual('invalid', result['action'], result)
        return [r['event'] for r in game._state['events']['rows'][start:]]

    def test_every_recipe_is_rejected_atomically_on_both_ward_lanes(self):
        for name in monsters.NAMES:
            game, ids = self.fixture(name)
            for lane in ('Lord', 'Castle'):
                with self.subTest(name=name, lane=lane):
                    order = dict(action='Ward', lane=lane, card_ids=ids, monster_choice=name)
                    before = game.snapshot()
                    self.assertEqual('invalid', game.apply(dict(kind='submit', plans=[
                        dict(powers=[], order=order), dict(powers=[], order={})]))['action'])
                    self.assertEqual(before, game.snapshot())
                    self.assertEqual('invalid', Preview(game, 0)(dict(powers=[], order=order))['action'])

    def test_ward_still_creates_sigils_and_two_to_one_normal_recruits(self):
        for lane in ('Lord', 'Castle'):
            game, ids = self.fixture()
            world = game._state['world']
            totals = Counter()
            for k in ids:
                a = economy.entity(world, k)['attributes']
                totals[a['suit']] += a['value']
            events = self.reveal(game, dict(action='Ward', lane=lane, card_ids=ids))
            spawns = [e['data'] for e in events if e['type'] == 'MARCHER_SPAWNED' and e['data']['owner'] == 0]
            self.assertEqual(sum(v//2 for v in totals.values()), len(spawns))
            self.assertFalse(any('monster_id' in r['attributes'] for r in spawns))
            self.assertFalse(any(e['type'] == 'MONSTER_SUMMONED' for e in events))
            self.assertEqual('fresh', game._state['world']['data']['sigils'][0][lane])

    def test_both_attacks_keep_all_recipes_and_three_to_one_recruits(self):
        for name in monsters.NAMES:
            for action in ('Hunt', 'Siege'):
                with self.subTest(name=name, action=action):
                    game, ids = self.fixture(name)
                    f = Facts(observe(game, 0))
                    _, lane, target = next(t for t in f.attack_targets() if t[0] == action)
                    order = dict(action=action, lane=lane, target_id=target, card_ids=ids, monster_choice=name)
                    self.assertEqual('legal', Preview(game, 0)(dict(powers=[], order=order))['action'])
                    events = self.reveal(game, order)
                    normal = [e['data'] for e in events if e['type'] == 'MARCHER_SPAWNED'
                              and e['data']['owner'] == 0 and 'monster_id' not in e['data']['attributes']]
                    self.assertEqual(f.recruits(ids, action), len(normal))
                    summons = [e for e in events if e['type'] == 'MONSTER_SUMMONED']
                    self.assertEqual([name], [e['data']['monster_id'] for e in summons])

    def test_exact_recipe_uses_attack_scores_and_never_attaches_to_ward(self):
        game, ids = self.fixture()
        view = observe(game, 0)
        f, weights = Facts(view), Weights()
        book = Recipes(f, weights)
        for proposal in book.proposals():
            self.assertIn(proposal.term, ('Hunt', 'Siege'))
            self.assertEqual('legal', Preview(game, 0)(dict(powers=[], order=proposal.payload))['action'])
            self.assertEqual(f.attack_value(proposal.term, proposal.payload['target_id'], proposal.cards, weights)
                             +book.value(proposal.payload['monster_choice'], proposal.payload['lane']), proposal.value)
        ward = Proposal('combat', 'Ward', dict(action='Ward', lane='Lord', card_ids=ids), 10, 'fixture', tuple(ids))
        book.attach(ward)
        self.assertNotIn('monster_choice', ward.payload)
        self.assertEqual(10, ward.value)
        # With no living enemy Lord, exact recipes still have legal Siege targets.
        enemy = next(r for r in view['board'] if r['kind'] == 'lord' and r['owner'] == 1)
        enemy['attributes']['alive'] = False
        proposals = list(Recipes(Facts(view), weights).proposals())
        self.assertTrue(proposals)
        self.assertTrue(all(p.term == 'Siege' for p in proposals))

    def test_existing_field_monsters_survive_ward_and_staged_monsters_can_march(self):
        game, ids = self.fixture()
        w = game._state['world']
        unit = recruitment.create(w, 'ward-existing', 0, 0, monsters.profile('Lemek', 'Lord', 0, 0, 1))
        identity = unit['id']
        self.reveal(game, dict(action='Ward', lane='Lord', card_ids=ids))
        w = game._state['world']
        self.assertEqual('Lemek', economy.entity(w, identity)['attributes']['monster_id'])
        # The staging command remains independent of whether combat is Ward.
        game_staging.configure(w)
        reserve = recruitment.create(w, 'ward-reserve', 0, 0, monsters.profile('Kopita', 'Castle', 0, 0, 1))
        reserve['attributes']['staged_round'] = 0
        w['entities']['entities'].remove(reserve)
        w['data']['game_staging']['lanes']['Castle']['units'].append(reserve)
        orders = [dict(action='Ward', lane='Castle', card_ids=[], staging={'Castle': 'March'}), {}]
        game_staging.prepare(w, 1, orders)
        # A prior-round reserve launches in the phase commanded, not next round.
        self.assertNotIn(reserve, game_staging.rows(w))
        self.assertEqual('Kopita', economy.entity(w, reserve['id'])['attributes']['monster_id'])


if __name__ == '__main__':
    unittest.main()
