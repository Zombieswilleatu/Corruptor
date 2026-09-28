import unittest
from .facts import Facts
from .observation import observe
from .test_common import planning
from .test_recipes_veil import hand
from .defensive_plans import development, kalligan_orias_bonus

EMPTY = dict(powers=[],order={})

def fixture(enemy='Orias', pressure=None):
    v=observe(planning('Kalligan'),0)
    for r in v['board']:
        if r['kind']=='lord' and r['owner']==1:r['attributes']['lord_id']=enemy
    v['board']=[r for r in v['board'] if not (r['kind']=='castle' and r['owner']==0)]
    hand(v,[('Penitent',5)]*2)
    f=Facts(v)
    if pressure is not None:f.opponent['evidence']=[dict(action='Hunt',strength=pressure)]
    p=dict(powers=[],order=dict(guard_moves=[dict(card_id=r['id'],lane='Lord',slot=i) for i,r in enumerate(f.hand)]))
    w,_=development(f,p)
    return f,w,p

class SurvivalTests(unittest.TestCase):
    def test_useful_survival_gets_bounded_credit(self):
        f,w,p=fixture();score=kalligan_orias_bonus(f,w,p)
        self.assertGreater(score,0);self.assertLessEqual(score,90)
        self.assertEqual(0,kalligan_orias_bonus(f,f.world,EMPTY))

    def test_doomed_guard_spending_gets_no_credit(self):
        f,w,p=fixture(pressure=30)
        self.assertEqual(0,kalligan_orias_bonus(f,w,p))

    def test_other_matchups_unchanged(self):
        for enemy in ('Deimos','Gremory','Humbaba','Kanifous','Kroni','Odradek','Valak','Kalligan'):
            f,w,p=fixture(enemy);self.assertEqual(0,kalligan_orias_bonus(f,w,p))
        f,w,p=fixture();f.kind='Kanifous';self.assertEqual(0,kalligan_orias_bonus(f,w,p))

    def test_banishment_and_resummon_not_invented_as_survival(self):
        f,w,p=fixture();p['order']['summon']={}
        self.assertEqual(0,kalligan_orias_bonus(f,w,p))
        del p['order']['summon'];f.lord[f.pid]['attributes']['alive']=False
        self.assertEqual(0,kalligan_orias_bonus(f,w,p))

    def test_public_history_changes_thresholds(self):
        low,w,p=fixture(pressure=9);high,w2,p2=fixture(pressure=30)
        self.assertGreater(kalligan_orias_bonus(low,w,p),kalligan_orias_bonus(high,w2,p2))

if __name__=='__main__':unittest.main()
