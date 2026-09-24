"""Retreat speed changes must not change normal movement or recovery."""
import unittest
from . import marching, marching_fixtures as fixtures
from .copying import copy_data

class RoutSpeedTests(unittest.TestCase):
    def test_displacement_and_following_round_recovery(self):
        spec=copy_data(fixtures.load()['cases'][0])
        spec.update(ranged=True,data={'rout_profile':marching.ROUT},effects=[])
        proto=copy_data(spec['units'][0])
        proto.update(suit='Butcher',lane='Castle',owner=1,birth=0,ready=1,
            origin='rout-speed:enemy',ordinal=0,attributes=dict(x_fp=1000,y_fp=300,
            hp=100,max_hp=100,armor=0,step_fp=4,rout_round=1,rout_effect_id='rout-speed'))
        spec['units']=[proto]
        for number,expected in ((1,1680),(2,600),(3,200)):
            with self.subTest(round=number):
                world=fixtures.initial(spec)
                result=marching.resolve(fixtures.context(spec,world,number),capture_ticks=False)
                self.assertEqual('resolved',result['action'])
                self.assertEqual(expected,result['world']['entities']['entities'][0]['attributes']['x_fp'])

    def test_fractional_steps_preserved_over_phase(self):
        for step in range(1,21):
            self.assertEqual(step*170,sum(marching.rout_flee_step(step,t) for t in range(200,400)))

if __name__=='__main__':unittest.main()
