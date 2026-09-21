"""Reserve slots constrain recipe plans and economy goals, not combat bodies."""
import unittest

from u13_pysim import game_staging, monsters
from u13_pysim.copying import copy_data
from .common import Weights
from .facts import Facts, Proposal
from .observation import observe
from .recipes import Recipes
from .test_common import planning
from .test_recipes_veil import hand


class ReservedRecipeTests(unittest.TestCase):
    def fixture(self, name, owner=0):
        view = observe(planning('Deimos'), 0)
        hand(view, [(suit, 1) for suit, count in monsters.ROSTER[name]['recipe'].items()
                    for _ in range(count)])
        view['data']['monsters']['unlocked'][0] = [name]
        game_staging.configure(dict(data=view['data']))
        unit = dict(id='reserved:'+name, kind='marcher', owner=owner,
                    attributes=dict(monsters.profile(name, 'Lord', owner, 1, 2), staged_round=1))
        view['data']['game_staging']['lanes']['Lord']['units'].append(unit)
        return view, unit

    def test_both_limited_reserves_block_goals_exact_recipes_and_attached_recipes(self):
        for name in ('Sooge', 'Sinodek'):
            with self.subTest(name=name):
                view, _ = self.fixture(name)
                before = copy_data(view)
                facts = Facts(view); book = Recipes(facts, Weights())
                self.assertEqual('living_copy_limit', book.status[name])
                self.assertEqual('', book.goal(view['hand'])['monster'])
                self.assertEqual([], list(book.proposals()))
                ids = tuple(r['id'] for r in view['hand'])
                proposal = Proposal('combat', 'Ward', dict(action='Ward', lane='Lord', card_ids=list(ids)), 1, 'fixture', ids)
                book.attach(proposal)
                self.assertNotIn('monster_choice', proposal.payload)
                self.assertEqual([], facts.units(0, 'Lord'))
                self.assertEqual(before, view)
                # Release preserves the slot; death/removal frees it.
                view['board'].extend(view['data']['game_staging']['lanes']['Lord']['units'])
                view['data']['game_staging']['lanes']['Lord']['units'].clear()
                self.assertEqual('living_copy_limit', Recipes(Facts(view), Weights()).status[name])
                view['board'] = [u for u in view['board'] if u['id'] != 'reserved:'+name]
                self.assertEqual('available', Recipes(Facts(view), Weights()).status[name])
                self.assertEqual(name, Recipes(Facts(view), Weights()).goal(view['hand'])['monster'])

    def test_enemy_reserve_does_not_consume_own_slot_but_original_charmed_owner_does(self):
        view, unit = self.fixture('Sooge', owner=1)
        self.assertEqual('available', Recipes(Facts(view), Weights()).status['Sooge'])
        unit['attributes']['charm_owner'] = 0
        self.assertEqual('living_copy_limit', Recipes(Facts(view), Weights()).status['Sooge'])

    def test_unlimited_reserves_and_legacy_views_keep_recipes_available(self):
        view, _ = self.fixture('Varn')
        self.assertEqual('available', Recipes(Facts(view), Weights()).status['Varn'])
        self.assertTrue(list(Recipes(Facts(view), Weights()).proposals()))
        view, _ = self.fixture('Sooge')
        del view['data']['game_staging']
        self.assertEqual('available', Recipes(Facts(view), Weights()).status['Sooge'])


if __name__ == '__main__': unittest.main()
