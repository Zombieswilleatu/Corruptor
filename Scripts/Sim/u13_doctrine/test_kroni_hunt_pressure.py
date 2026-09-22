"""Hunger priority changes valuation, never the Hunt's physical outcome."""
import unittest
from .common import Weights
from .facts import Facts, kroni_hunt_bonus
from .observation import observe
from .test_common import planning
from .lords.deimos import attack_value

class KroniHuntPressureTests(unittest.TestCase):
    def facts(self, hunger=3, value=9):
        view=observe(planning('Kroni'),1)
        view['board']=[r for r in view['board'] if r['kind']=='lord']
        kroni=next(r for r in view['board'] if r['owner']==0)
        kroni['attributes'].update(hunger=hunger,alive=True)
        view['hand']=[dict(id='attack',kind='card',owner=1,attributes=dict(suit='Butcher',value=value))]
        return Facts(view)

    def test_high_defense_still_blocks_ineffective_hunt(self):
        f=self.facts(value=8);r=f.attack('Hunt',f.lord[0]['id'],['attack'])
        self.assertEqual(8,r['strength']);self.assertFalse(r['banished'])
        self.assertEqual(0,r['kroni_pressure_bonus'])

    def test_banishment_bonus_and_radius_tier_cap(self):
        for hunger,bonus in [(0,0),(1,8),(2,16),(3,24),(9,24)]:
            f=self.facts(hunger);r=f.attack('Hunt',f.lord[0]['id'],['attack'])
            self.assertTrue(r['banished']);self.assertEqual(9,r['strength'])
            self.assertEqual(bonus,r['kroni_pressure_bonus'])
            self.assertEqual(Weights().recruit*3+Weights().banishment+bonus,
                             f.attack_value('Hunt',f.lord[0]['id'],['attack'],Weights()))

    def test_guard_pressure_without_banishment(self):
        f=self.facts(value=9)
        f.rows.append(dict(id='guard',kind='card',owner=0,attributes=dict(role='guard',lane='Lord',slot=0,value=2,suit='Vulture')))
        r=f.attack('Hunt',f.lord[0]['id'],['attack'])
        self.assertEqual(1,r['guards']);self.assertFalse(r['banished'])
        self.assertEqual(9,r['kroni_pressure_bonus'])
        self.assertEqual(12+9,attack_value(r,Weights()))

    def test_siege_other_lords_dead_targets_and_empty_result(self):
        f=self.facts();r=f.attack('Siege','castle_zone:0',['attack'])
        self.assertEqual(0,r['kroni_pressure_bonus'])
        for attrs in [dict(lord_id='Orias',alive=True,hunger=3),dict(lord_id='Kroni',alive=False,hunger=3)]:
            self.assertEqual(0,kroni_hunt_bonus(attrs,dict(banished=True,guards=3)))
        self.assertEqual(0,kroni_hunt_bonus(dict(lord_id='Kroni',alive=True,hunger=3),dict(banished=False,guards=0)))

if __name__=='__main__':unittest.main()
