"""Independent Wish valuation changes; no engine rules or future-roll access."""
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from u13_pysim import wishmaster
from u13_pysim.copying import copy_data
from u13_pysim.power_rules import declaration
from .common import CommonSmartCore
from .facts import Facts
from .kanifous_tactics import wish_value, ordinary_material_sum
from .test_common import planning
from .test_kanifous import fixture, unit, EMPTY
from .test_recipes_veil import hand


class CalibrationTests(unittest.TestCase):
    def test_only_selected_factor_changes_and_prices_stay_identical(self):
        v=fixture();hand(v,[('Butcher',1)])
        for i in range(10):unit(v,'own'+str(i),0,x=500,hp=1)
        unit(v,'enemy',1,x=550)
        names={'power':('WishPower',dict(lane='Castle')),'wealth':('WishWealth',{}),
               'resurrection':('WishResurrection',dict(lane='Castle'))}
        values={}
        for profile in ('v20','power','wealth','resurrection','combined'):
            f=Facts(v);f.wish_profile=profile
            values[profile]={k:wish_value(f,n,t,EMPTY) for k,(n,t) in names.items()}
        for profile in names:
            for term in names:
                self.assertEqual(values['v20'][term]['price'],values[profile][term]['price'])
                if profile!=term:self.assertEqual(values['v20'][term],values[profile][term])
                else:
                    self.assertNotEqual(values['v20'][term]['benefit'],values[profile][term]['benefit'])
                    self.assertEqual(values['combined'][term],values[profile][term])

    def test_speculative_cap_does_not_cap_known_casualties(self):
        v=fixture()
        for i in range(20):unit(v,'own'+str(i),0,x=500,hp=1)
        unit(v,'enemy',1,x=550)
        lost=unit(v,'lost',0,monster='Lemek');v['board'].remove(lost)
        v['data']['kanifous_losses']=[lost]
        f=Facts(v);f.wish_profile='resurrection'
        value=wish_value(f,'WishResurrection',dict(lane='Castle'),EMPTY)
        self.assertEqual(240,value['raw_exposure_value'])
        self.assertEqual(39,value['speculative_credit'])
        # Current Lemek profile restores material value 54, not the old 44.
        self.assertEqual(54,value['known_loss_value'])
        self.assertEqual(93,value['benefit'])
        self.assertEqual(['lost'],value['known_losses'])

    def test_wealth_shortage_bonus_is_bounded_after_commitments(self):
        v=fixture();hand(v,[('Butcher',1)]*10);f=Facts(v);f.wish_profile='wealth'
        for spent,expected in ((0,0),(1,0),(5,0),(6,3),(10,15)):
            p=dict(powers=[],order=dict(action='Ward',lane='Castle',card_ids=[r['id'] for r in f.hand[:spent]]))
            value=wish_value(f,'WishWealth',{},p)
            self.assertEqual(expected,value['short_hand_bonus'])
            self.assertLessEqual(value['benefit'],36)
        v['data']['kanifous_prices']=[dict(owner=0,due_round=v['round']+1)]*4
        self.assertLess(wish_value(Facts(v),'WishWealth',{},p)['score'],0)

    def test_power_distribution_matches_authority_thresholds(self):
        original=planning('Kanifous')._state['world']
        for name in ('WishPower','BreachWishPower'):
            counts=[]
            for roll in range(100):
                with self.subTest(power=name,roll=roll):
                    b=SimpleNamespace(w=copy_data(original),number=1,seed='fixed')
                    def draw(seed,key,channel,index,bound):return roll if channel=='WISH_COUNT' else 0
                    with patch('u13_pysim.wishmaster.draw',draw):
                        events=wishmaster.wish(b,declaration(0,1,name,dict(lane='Castle')))
                    counts.append(events[-1]['event']['data']['count'])
            self.assertEqual([1]*25+[2]*50+[3]*25,counts)
            self.assertEqual(200,sum(counts))
        self.assertEqual(78,ordinary_material_sum())

    def test_profile_validation_and_identification(self):
        with self.assertRaises(ValueError):CommonSmartCore(wish_profile='guess')
        self.assertEqual('power',CommonSmartCore().wish_profile)
        self.assertEqual(CommonSmartCore(wish_profile='power').policy_id,CommonSmartCore().policy_id)
        self.assertIn(':WISH_combined',CommonSmartCore(wish_profile='combined').policy_id)
        self.assertNotIn(':WISH_',CommonSmartCore().policy_id)

    def test_comparison_has_all_five_profiles_on_identical_setups(self):
        from collections import defaultdict
        from .kanifous_calibration import cases
        groups=defaultdict(list)
        for row in cases():groups[row['pair_id']].append(row)
        self.assertEqual(36,len(groups))
        for rows in groups.values():
            self.assertEqual({'v20','power','wealth','resurrection','combined'},{r['variant'] for r in rows})
            self.assertTrue(all(r['setup']==rows[0]['setup'] for r in rows))

    def test_comparison_pairs_each_factor_with_v20_and_excludes_failures(self):
        from .kanifous_calibration import aggregate
        from .test_kanifous_comparison import record
        value=aggregate([record('v20',1),record('power',0),record('wealth',1),
                         record('resurrection',0,status='failed'),record('combined',0)])
        self.assertEqual(1,value['paired_vs_v20']['power']['gained'])
        self.assertEqual(1,value['paired_vs_v20']['wealth']['both_lose'])
        self.assertEqual(0,value['paired_vs_v20']['resurrection']['complete_pairs'])
        self.assertEqual(1,value['totals']['resurrection']['failed'])


if __name__=='__main__':unittest.main()
