import unittest
from .facts import Facts
from .kanifous_tactics import choices, wish_value
from .test_kanifous import fixture, EMPTY
from .test_recipes_veil import hand

class WealthScoreTests(unittest.TestCase):
    def test_only_wealth_changes_and_draw_space_still_limits_it(self):
        view = fixture()
        hand(view, [('Butcher', 1)] * 10)
        for spent in (0, 1, 2, 3, 10):
            plan = dict(powers=[], order=dict(action='Ward', lane='Castle', card_ids=[r['id'] for r in view['hand'][:spent]]))
            baseline = Facts(view)
            for profile, per_card in (('wealth25',25), ('wealth35',35)):
                candidate = Facts(view); candidate.wish_profile = profile
                for name, target in choices(baseline):
                    old = wish_value(baseline, name, target, plan)
                    new = wish_value(candidate, name, target, plan)
                    self.assertEqual(old['price'], new['price'])
                    if name != 'WishWealth':
                        self.assertEqual(old, new)
                    else:
                        self.assertEqual(per_card * old['expected_cards_hundredths'] // 100, new['benefit'])
                        self.assertEqual(old['expected_cards_hundredths'], new['expected_cards_hundredths'])
                        if spent == 0: self.assertEqual(0, new['benefit'])
