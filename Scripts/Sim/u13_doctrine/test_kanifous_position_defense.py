import unittest
from .facts import Facts
from .kanifous_tactics import wish_value,restoration_position_value,choices,matchup_profile
from .defensive_plans import development,kanifous_hunt_bonus
from .test_kanifous import fixture,unit,EMPTY
from .test_recipes_veil import hand

class PositionDefenseTests(unittest.TestCase):
    def test_default_routes_only_kanifous_orias_to_extra_defense(self):
        from .common import CommonSmartCore
        self.assertEqual('matchup',CommonSmartCore().wish_profile)
        f=Facts(fixture())
        for enemy in ('Deimos','Gremory','Humbaba','Kalligan','Kanifous','Kroni','Odradek','Orias','Valak'):
            f.lord[f.enemy]['attributes']['lord_id']=enemy
            self.assertEqual('wealth35_position_defense' if enemy=='Orias' else 'wealth35',matchup_profile(f))
        f.kind='Kroni'
        self.assertEqual('power',matchup_profile(f))

    def test_other_wishes_and_prices_unchanged(self):
        v=fixture();unit(v,'own',0,x=2200,hp=1);unit(v,'foe',1,x=2250)
        old=Facts(v);old.wish_profile='wealth35'
        for profile in ('wealth35_position','wealth35_position_defense'):
            f=Facts(v);f.wish_profile=profile
            for name,target in choices(f):
                a=wish_value(old,name,target,EMPTY);b=wish_value(f,name,target,EMPTY)
                self.assertEqual(a['price'],b['price'])
                if name!='WishResurrection':self.assertEqual(a,b)

    def test_saved_travel_is_seat_symmetric_and_not_free_casualty_credit(self):
        v=fixture();r=unit(v,'far',0,x=2200,hp=1);f=Facts(v);f.wish_profile='wealth35_position'
        value=restoration_position_value(f,r);self.assertGreater(value,0)
        f.pid=1;r['attributes']['x_fp']=200
        self.assertEqual(value,restoration_position_value(f,r))
        f.pid=0;r['attributes']['x_fp']=100
        self.assertEqual(0,restoration_position_value(f,r))
        r['attributes']['x_fp']=2200
        self.assertEqual(0,wish_value(f,'WishResurrection',dict(lane='Castle'),EMPTY)['position_credit'])
        unit(v,'foe',1,x=2250)
        f=Facts(v);f.wish_profile='wealth35_position'
        self.assertGreater(wish_value(f,'WishResurrection',dict(lane='Castle'),EMPTY)['position_credit'],0)

    def test_known_losses_get_credit_once_and_bonus_is_bounded(self):
        v=fixture();r=unit(v,'lost',0,x=2200);v['board'].remove(r);v['data']['kanifous_losses']=[r,r]
        f=Facts(v);f.wish_profile='wealth35_position'
        a=wish_value(f,'WishResurrection',dict(lane='Castle'),EMPTY)
        self.assertEqual(['lost'],a['known_losses']);self.assertEqual(restoration_position_value(f,r),a['position_credit'])
        r['attributes']['waiting']=True
        self.assertEqual(0,restoration_position_value(f,r))
        r['attributes']['waiting']=False;r['attributes']['sprite_form']='turret'
        self.assertEqual(0,restoration_position_value(f,r))

    def test_hunt_defense_only_rewards_survival_thresholds(self):
        v=fixture();hand(v,[('Penitent',5)]*2)
        for r in v['board']:
            if r['kind']=='lord' and r['owner']==1:r['attributes']['lord_id']='Orias'
        v['board']=[r for r in v['board'] if not(r['kind']=='castle' and r['owner']==0)]
        f=Facts(v);f.wish_profile='wealth35_position_defense'
        p=dict(powers=[],order=dict(guard_moves=[dict(card_id=r['id'],lane='Lord',slot=i) for i,r in enumerate(f.hand)]))
        w,_=development(f,p);bonus=kanifous_hunt_bonus(f,w,p)
        self.assertGreater(bonus,0);self.assertLessEqual(bonus,48)
        self.assertEqual(0,kanifous_hunt_bonus(f,f.world,EMPTY))
        # Repeated Hunts from another Lord must never enable this matchup rule.
        f.opponent['evidence']=[dict(action='Hunt',strength=15)]*3
        for enemy in ('Deimos','Gremory','Humbaba','Kalligan','Kanifous','Kroni','Odradek','Valak'):
            f.lord[f.enemy]['attributes']['lord_id']=enemy
            self.assertEqual(0,kanifous_hunt_bonus(f,w,p),enemy)
        f.lord[f.enemy]['attributes']['lord_id']='Orias'
        self.assertEqual(bonus,kanifous_hunt_bonus(f,w,p))
        f.lord[0]['attributes']['alive']=False
        self.assertEqual(0,kanifous_hunt_bonus(f,w,p))
        f.lord[0]['attributes']['alive']=True;f.wish_profile='wealth35_position'
        self.assertEqual(0,kanifous_hunt_bonus(f,w,p))
